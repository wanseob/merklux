pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "solidity-rlp/contracts/RLPReader.sol";
import "./MerkluxStore.sol";
import "./MerkluxReducer.sol";
import {Block, Transition} from "./Types.sol";


/**
 * @title Merklux
 * @dev Merklux is a state management smart contract to control the state with a
 * unidirectional data flow. It can be used for state verifications accross evm
 * based block chains.
 */
contract Merklux is Secondary {

    using Block for Block.Object;
    using Transition for Transition.Object;
    using SafeMath for uint256;
    using ECDSA for bytes32;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    // Every action dispatches increment the height
    uint256 public height;
    bytes32[] storeList;
    bytes32[] reducerList;

    mapping(bytes32 => bytes32[]) references;

    Transition.Object[] transitionsOfCurrentBlock;

    mapping(bytes32 => MerkluxReducer) private reducers;
    mapping(bytes32 => MerkluxStore) private stores;

    bytes32[] blocks;

    struct BlockData {
        address sealer;
        uint height;
        bytes32 previousBlock;
        bytes32[] reducerList;
        bytes32[] storeList;
        mapping(bytes32 => bytes32[]) references;
        Transition.Object[] transitions;
    }

    BlockData lastBlockData;

    event Dispatched(uint _height, bytes32 _transactionDataHash);

    constructor () public Secondary() {
    }

    function newStore(bytes32 _store) public onlyPrimary {// TODO committee
        // key cannot be empty
        require(_store != bytes32(0));

        MerkluxStore store = stores[_store];
        // stores can not be overwritten
        require(address(store) == 0);

        // Deploy and assign a new merklux tree
        store = new MerkluxStore();

        // add store name to the list to use as a key
        storeList.push(_store);

        // Assign deployed store to the map
        stores[_store] = store;

        // record transition
        _newStoreTransition(_store);
    }

    /**
     * @dev It allows to update reducer by overwriting
     *
     * @param _store The store which contains state tree for the reducer to refer
     * @param _action Name of the action for the reducer to handle
     * @param _code Compiled reducer code to deploy
     */
    function setReducer(bytes32 _store, string _action, bytes _code) public onlyPrimary {// TODO committee
        require(bytes(_action).length != 0);
        require(_store != bytes32(0));

        MerkluxStore store = stores[_store];
        // stores should be initialized
        require(address(store) != 0);

        // only create a new reducer when it does not exist
        bytes32 reducerKey = keccak256(_code);
        if (reducers[reducerKey] == address(0)) {
            address reducerAddress;
            assembly {
                reducerAddress := create(0, add(_code, 0x20), mload(_code))
            }
            reducers[reducerKey] = MerkluxReducer(reducerAddress);
            reducerList.push(reducerKey);

        }
        // Add the action into the actions list
        if (store.getReducer(_action) == bytes32(0)) {
            store.setReducer(_action, reducerKey);
        }

        // Record transition
        _setReducerTransition(
            _store,
            _action,
            _code
        );
    }

    /**
    * @dev This is the only way to updates the merkle trees
    *
    * @param _store The name of the store to update
    * @param _action The name of the action
    * @param _data RLP encoded data set
    */
    function dispatch(bytes32 _store, string _action, bytes _data) external returns (bytes32) {
        MerkluxStore store = stores[_store];
        // stores should be initialized
        require(address(store) != address(0));

        // It should have a reducer to handle the _action
        bytes32 reducerKey = store.getReducer(_action);
        require(reducerKey != bytes32(0));

        // The reducer also should exist
        require(reducers[reducerKey] != address(0));

        bytes memory rlpEncodedKeys;
        bytes memory rlpEncodedValues;
        bytes32[] memory referredKeys;
        (rlpEncodedKeys, rlpEncodedValues, referredKeys) = reducers[reducerKey].reduce(store, msg.sender, _data);

        RLPReader.RLPItem[] memory keys = rlpEncodedKeys.toRlpItem().toList();
        RLPReader.RLPItem[] memory values = rlpEncodedValues.toRlpItem().toList();
        require(keys.length == values.length);
        for (uint i = 0; i < keys.length; i ++) {
            store.insert(keys[i].toBytes(), values[i].toBytes());
        }

        // set references
        _addReferences(_store, referredKeys);

        // record transition
        _dispatchTransition(
            _store,
            _action,
            _data
        );
    }

    function get(bytes32 _store, bytes _key) public view returns (bytes) {
        MerkluxStore store = stores[_store];
        return store.get(_key);
    }

    // TODO set modifier to allow only the pseudo-randomly selected snapshot submitter
    function seal() external {
        // TODO setup requirements

        Block.Object memory newBlock;
        newBlock.sealer = msg.sender;
        newBlock.height = height;
        newBlock.previousBlockHash = blocks[blocks.length - 1];
        newBlock.reducers = reducerList;

        newBlock.stores = new bytes32[](storeList.length);
        for (uint i = 0; i < storeList.length; i++) {
            MerkluxStore store = stores[storeList[i]];
            newBlock.stores[i] = store.getRootHash();
            lastBlockData.references[storeList[i]] = references[storeList[i]];
        }

        newBlock.transitions = new bytes32[](transitionsOfCurrentBlock.length);
        for (uint j = 0; j < transitionsOfCurrentBlock.length; j++) {
            newBlock.transitions[j] = transitionsOfCurrentBlock[j].getTransitionHash();
        }

        // save last block data for convenient use.
        // It is unnecessary when we have a client to get the previous block data easily
        lastBlockData.sealer = newBlock.sealer;
        lastBlockData.height = newBlock.height;
        lastBlockData.previousBlock = newBlock.previousBlockHash;
        lastBlockData.reducerList = reducerList;
        lastBlockData.storeList = storeList;
        lastBlockData.transitions = transitionsOfCurrentBlock;

        // clean transitions
        _clearTransitionList();

        // clear references
        _clearReferences();

        blocks.push(newBlock.getBlockHash());
    }

    function getLastBlockData() public view returns (
        address _sealer,
        bytes32 _hash,
        uint256 _height,
        bytes32 _previousHash,
        bytes32[] memory _reducers,
        bytes32[] memory _stores,
        bytes32[] memory _transitions
    ) {
        _sealer = lastBlockData.sealer;
        _hash = blocks[blocks.length - 1];
        _height = lastBlockData.height;
        _previousHash = lastBlockData.previousBlock;
        _reducers = lastBlockData.reducerList;
        _stores = lastBlockData.storeList;
        _transitions = new bytes32[](lastBlockData.transitions.length);
        for (uint i = 0; i < lastBlockData.transitions.length; i ++) {
            _transitions[i] = lastBlockData.transitions[i].getTransitionHash();
        }
    }

    function _addReferences(bytes32 _store, bytes32[] memory _keys) private {
        bytes32[] storage keys = references[_store];
        for (uint i = 0; i < _keys.length; i ++) {
            for (uint j = 0; j < keys.length; j++) {
                if (keys[j] == _keys[i]) {
                    return;
                }
            }
            keys.push(_keys[i]);
        }
    }

    function _setReducerTransition(
        bytes32 _store,
        string _action,
        bytes _code
    ) private {
        Transition.Object memory transition;
        transition.sort = Transition.Type.SET_REDUCER;
        transition.store = _store;
        transition.action = _action;
        transition.data = _code;
        _pushTransition(transition);
    }

    function _newStoreTransition(
        bytes32 _store
    ) private {
        Transition.Object memory transition;
        transition.sort = Transition.Type.NEW_STORE;
        transition.store = _store;
        _pushTransition(transition);
    }

    function _dispatchTransition(
        bytes32 _store,
        string _action,
        bytes _data
    ) private {
        Transition.Object memory transition;
        transition.sort = Transition.Type.DISPATCH;
        transition.store = _store;
        transition.action = _action;
        transition.data = _data;
        _pushTransition(transition);
    }

    function _pushTransition(Transition.Object transition) private {
        // TODO require(stake > estimated defence cost);
        transitionsOfCurrentBlock.push(transition);
        height.add(1);
    }

    function _clearTransitionList() private {
        for (uint i = 0; i < transitionsOfCurrentBlock.length; i++) {
            delete transitionsOfCurrentBlock[i];
        }
        transitionsOfCurrentBlock.length = 0;
    }

    function _clearReferences() private {
        for (uint i = 0; i < storeList.length; i++) {
            delete references[storeList[i]];
        }
    }
}
