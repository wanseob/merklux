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
    using Block for Block.Data;
    using Transition for Transition.Object;
    using SafeMath for uint256;
    using ECDSA for bytes32;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    // Every action dispatches increment the height
    uint256 public height;
    bytes32[] storeList;
    mapping(bytes32 => MerkluxReducer) private reducers;
    mapping(bytes32 => MerkluxStore) private stores;


    //    mapping(bytes32 => bytes32[]) references;
    //
    //    Transition.Object[] transitionsOfCurrentBlock;


    bytes32[] chain;
    mapping(bytes32 => Block.Object) blocks;
    mapping(uint256 => Block.Data) blockData;

    event Dispatched(uint _height, bytes32 _transactionDataHash);
    event Sealed(bytes32 _blockHash, bytes _signature);

    constructor () public Secondary() {
        // Set null value as the genesis block
        chain.push(bytes32(0));
    }


    /**
    * @dev This is the only way to updates the merkle trees
    *
    * @param _storeKey The hashed key of a store to update
    * @param _action The name of the action
    * @param _data RLP encoded data set
    */
    function dispatch(bytes32 _storeKey, string _action, bytes _data) external {
        MerkluxStore store = stores[_storeKey];
        // stores should be initialized
        require(address(store) != address(0));

        MerkluxReducer reducer = getReducer(store.getReducerKey(_action));

        bytes memory rlpEncodedKeys;
        bytes memory rlpEncodedValues;
        bytes32[] memory referredKeys;
        (rlpEncodedKeys, rlpEncodedValues, referredKeys) = reducer.reduce(store, msg.sender, _data);

        // record referred keys during dispatching
        _recordReferredNodes(_storeKey, referredKeys);

        RLPReader.RLPItem[] memory keys = rlpEncodedKeys.toRlpItem().toList();
        RLPReader.RLPItem[] memory values = rlpEncodedValues.toRlpItem().toList();
        require(keys.length == values.length);

        referredKeys = new bytes32[](keys.length);

        for (uint i = 0; i < keys.length; i++) {
            store.insert(keys[i].toBytes(), values[i].toBytes());
            referredKeys[i] = keccak256(keys[i].toBytes());
        }

        // record inserted keys
        _recordReferredNodes(_storeKey, referredKeys);

        // update candidate
        _recordStore(_storeKey, store.getRootHash());

        // record transition
        _recordTransition(
            Transition.Type.DISPATCH,
            height,
            _storeKey,
            _action,
            _data
        );
    }

    // TODO set modifier to allow only the pseudo-randomly selected snapshot submitter
    function seal(bytes _signature) external {
        Block.Object memory candidate = _getBlockCandidate(msg.sender);
        candidate.signature = _signature;
        // Check signature
        require(candidate.isSealed());
        bytes32 blockHash = candidate.getBlockHash();
        chain.push(blockHash);
        blocks[blockHash] = candidate;
    }

    function newStore(bytes32 _storeKey) public onlyPrimary {// TODO committee
        // key cannot be empty
        require(_storeKey != bytes32(0));

        MerkluxStore store = stores[_storeKey];
        // stores can not be overwritten
        require(address(store) == 0);

        // Deploy and assign a new merklux tree
        store = new MerkluxStore();

        // add store name to the list to use as a key
        storeList.push(_storeKey);

        // add the store key to the block data's store list
        _recordNewStore(_storeKey);

        // Assign deployed store to the map
        stores[_storeKey] = store;

        // record transition
        _recordTransition(
            Transition.Type.NEW_STORE,
            height,
            _storeKey,
            "NEW",
            new bytes(0)
        );
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
        }
        // Add the action into the actions list
        if (store.getReducerKey(_action) == bytes32(0)) {
            store.setReducer(_action, reducerKey);
        }

        // Record transition
        _recordTransition(
            Transition.Type.SET_REDUCER,
            height,
            _store,
            _action,
            _code
        );
    }

    function get(bytes32 _store, bytes _key) public view returns (bytes) {
        MerkluxStore store = stores[_store];
        return store.get(_key);
    }

    function getBlockHashToSeal() public view returns (bytes32) {
        return _getBlockCandidate(msg.sender).getBlockHash();
    }

    function getReducer(bytes32 _reducerKey) public view returns (MerkluxReducer) {
        require(_reducerKey != bytes32(0));
        // The reducer also should exist
        require(reducers[_reducerKey] != address(0));
        return reducers[_reducerKey];
    }

    function _getBlockCandidate(address _sealer) private view returns (Block.Object memory candidate) {
        Block.Data storage data = _getCurrentBlockData();
        candidate.height = height;
        candidate.previousBlock = chain[chain.length - 1];
        candidate.stores = data.getStoreRoot();
        candidate.references = data.getReferenceRoot();
        candidate.transitions = data.getTransitionRoot();
        candidate.sealer = _sealer;
        return candidate;
    }

    function _getCurrentBlockData() private view returns (Block.Data storage) {
        return blockData[chain.length];
    }

    function _recordReferredNodes(bytes32 _store, bytes32[] memory _keys) private {
        Block.Data storage data = _getCurrentBlockData();
        bytes32[] storage keys = data.references[_store];

        for (uint i = 0; i < _keys.length; i ++) {
            bool exist = false;
            for (uint j = 0; j < keys.length; j++) {
                if (keys[j] == _keys[i]) {
                    exist = true;
                    break;
                }
            }
            if (!exist) keys.push(_keys[i]);
        }
    }

    function _recordNewStore(bytes32 _store) private {
        Block.Data storage data = _getCurrentBlockData();
        data.storeKeys.push(_store);
    }

    function _recordStore(bytes32 _store, bytes32 _hash) private {
        Block.Data storage data = _getCurrentBlockData();
        data.storeHashes[_store] = _hash;
    }

    function _recordTransition(
        Transition.Type _sort,
        uint256 _height,
        bytes32 _store,
        string _action,
        bytes _data
    ) private {
        // TODO require(stake > estimated defence cost);
        Transition.Object memory transition = Transition.Object(
            msg.sender,
            _sort,
            _height,
            _store,
            _action,
            _data
        );
        Block.Data storage data = _getCurrentBlockData();
        data.transitions.push(transition);
        emit Dispatched(height, transition.getTransitionHash());
        height = height.add(1);
    }
}
