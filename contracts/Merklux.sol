pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import {Reducer, Block, Store, Transition} from "./Types.sol";


/**
 * @title Merklux
 * @dev Merklux contract only has the write permission on the MerkluxStore
 */
contract Merklux is Secondary {

    using Block for Block.Object;
    using Store for Store.Object;
    using Transition for Transition.Object;

    using SafeMath for uint256;
    using ECDSA for bytes32;

    uint256 public height;
    string[] storeList;
    bytes32[] reducerList;

    mapping(string => bytes32[]) references;

    Transition.Object[] transitionsOfCurrentBlock;

    mapping(bytes32 => Reducer) private reducers;
    mapping(string => Store.Object) private stores;

    bytes32[] blocks;

    struct BlockData {
        address sealer;
        uint height;
        bytes32 previousBlock;
        bytes32[] reducerList;
        string[] storeList;
        Transition.Object[] transitions;
        mapping(string => bytes32[]) references;
    }

    BlockData lastBlockData;

    event Dispatched(uint _height, bytes32 _transactionDataHash);

    constructor () public Secondary() {
    }

    function newStore(string _name) public onlyPrimary {// TODO committee
        // stores can not be overwritten
        require(!stores[_name].initialized());

        // name cannot be empty
        require(bytes(_name).length != 0);

        // add store name to the list to use as a key
        storeList.push(_name);

        // record transition
        _pushTransition(Merklux.newStoreTransition(_name));
    }

    /**
     * @dev It allows to update reducer by overwriting
     *
     * @param _store The store which contains state tree for the reducer to refer
     * @param _action Name of the action for the reducer to handle
     * @param _code Compiled reducer code to deploy
     */
    function setReducer(string _store, string _action, bytes _code) public onlyPrimary {// TODO committee
        // stores should be initialized
        require(stores[_store].initialized());

        // only create a new reducer when it does not exist
        bytes32 reducerKey = keccak256(_code);
        if (reducers[reducerKey] == bytes32(0)) {
            address memory reducerAddress;
            assembly {
                reducerAddress := create(0, add(_code, 0x20), mload(_code))
                jumpi(invalidJumpLabel, iszero(extcodesize(reducerAddress)))
            }
            reducers[reducerKey] = Reducer(reducerAddress);
            reducerList.push(reducerKey);
        }

        // Add the action into the actions list
        if (stores[_store].allowedReducers[_action] == bytes32(0)) {
            stores[_store].actions.push(_action);
        }

        // Add the reducer into the allowed reducer list of the store
        stores[_store].allowedReducers[_action] = reducers[reducerKey];


        // Record transition
        _pushTransition(
            Merklux.setReducerTransition(
                _store,
                _action,
                _code
            )
        );
    }

    /**
    * @dev This is the only way to updates the merkle trees
    *
    * @param _store The name of the store to update
    * @param _action The name of the action
    * @param _data RLP encoded data set
    */
    function dispatch(string _store, string _action, bytes _data) external returns (bytes32) {
        // stores should be initialized
        require(stores[_store].initialized);

        // It should have a reducer to handle the _action
        bytes32 memory reducerKey = stores[_store].allowedReducers[_action];
        require(reducerKey != bytes32(0));

        // The reducer also should exist
        require(reducers[reducerKey] != address(0));

        // Get key, value pair to update
        bytes[] memory keys;
        bytes[] memory values;
        bytes32[] memory referredKeys;
        (keys, values, referredKeys) = reducers[reducerKey].reduce(stores[_store].tree, msg.sender, _data);

        //keys and values should exist as pairs
        require(keys.length == values.length);

        // update tree if there's a new key-value pair to set
        for (uint i = 0; i < keys.length; i++) {
            stores[_store].tree.insert(keys[i], values[i]);
        }
        // set references
        _addReferences(_store, referredKeys);

        // Record transition
        _pushTransition(
            Merklux.dispatchTransition(
                _store,
                _action,
                _data
            )
        );
    }

    // TODO set modifier to allow only the pseudo-randomly selected snapshot submitter
    function seal() external {
        Block.Object memory newBlock;
        newBlock.sealer = msg.sender;
        newBlock.height = height;
        newBlock.previousBlockHash = blocks[blocks.length - 1];
        newBlock.reducers = reducerList;

        newBlock.stores = new bytes32[](storeList.length);
        for (uint i = 0; i < storeList.length; i++) {
            newBlock.stores[i] = stores[storeList[i]].getStoreHash();
        }

        newBlock.transitions = new bytes32[](transitionsOfCurrentBlock.length);
        for (uint j = 0; j < transitionsOfCurrentBlock.length; j++) {
            newBlock.transitions[i] = transitionsOfCurrentBlock[i].getTransitionHash();
        }

        // save last block data for convenient use.
        // It is unnecessary when we have a client to get the previous block data easily
        lastBlockData.sealer = newBlock.sender;
        lastBlockData.height = newBlock.previousBlockHash;
        lastBlockData.previousBlock = newBlock.previousBlockHash;
        lastBlockData.reducerList = reducerList;
        lastBlockData.storeList = storeList;
        lastBlockData.transitions = transitionsOfCurrentBlock;
        lastBlockData.references = references;

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
        string[] memory _stores,
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

    function _addReferences(string _store, bytes32[] memory _keys) private {
        bytes32[] storage keys = references[_store];
        for (uint i = 0; i < _keys.length; i ++) {
            for (uint j = 0; j < keys.length; j++) {
                if (keys[j] == _keys[i]) {
                    return;
                }
            }
            keys.push(_key);
        }
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
