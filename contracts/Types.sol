pragma solidity ^0.4.24;

import {PatriciaTree} from "solidity-patricia-tree/contracts/tree.sol";


interface Reducer {
    /**
    * @dev This only returns key-value pairs to update, and keys which are referred during the calculation.
    * @param _tree The merkle tree to get & set states
    * @param _from The address of the transaction caller
    * @param _data RLP encoded data set for its reducer
    * @return key Array of keys to update
    * @return value Array of values for the keys. It has same length with the array of keys.
    * @return references Array of hashes of the keys in the merkle tree which are referred to return the key-value pairs.
    It is possible to process a merkle proof with a minimum number of nodes by submitting only the referred nodes.
    */
    function reduce(
        PatriciaTree.Tree memory _tree,
        address _from,
        bytes _data
    ) public pure returns (
        bytes[] key,
        bytes[] value,
        bytes32[] references
    );
}


library Block {
    struct Object {
        address sealer;
        // address[] validators; TODO use modified Casper
        // bytes32[] crosslinks; TODO
        uint256 height;
        bytes32 previousBlockHash;
        bytes32[] reducers; // hashed code of each reducer at the given height
        bytes32[] stores; // root hash values of each tree at the given height
        bytes32[] transitions; // transitions between the previous block's height and the given height
    }

    function getBlockHash(Object memory block) internal pure returns (bytes32){
        return keccak256(abi.encodePacked(
                block.height,
                block.previousBlockHash,
                abi.encodePacked(block.reducers),
                abi.encodePacked(block.stores),
                abi.encodePacked(block.transitions)
            )
        );
    }
}

library Store {
    struct Object {
        string name;
        string[] actions;
        mapping(string => bytes32) allowedReducers;
        PatriciaTree.Tree tree;
    }

    function initialized(Object memory store) internal pure returns (bool) {
        return (bytes(store.name).length != 0);
    }

    function getStoreHash(Object memory store) internal pure returns (bytes32) {
        bytes32[] memory reducers = new bytes32[](store.actions.length);
        for (uint i = 0; i < store.actions.length; i ++) {
            reducers[i] = store.allowedReducers[store.actions[i]];
        }
        return keccak256(abi.encodePacked(
                store.name,
                store.actions,
                reducers,
                tree.root
            )
        );
    }
}

library Transition {
    enum TransitionType  {SET_REDUCER, NEW_STORE, DISPATCH}

    struct Object {
        TransitionType type;
        string store;
        string action;
        bytes data;
    }

    function setReducerTransition(
        string _store,
        string _action,
        bytes _code
    ) public pure returns (Object memory transition) {
        transition.type = TransitionType.SET_REDUCER;
        transition.store = _store;
        transition.action = _action;
        transition.data = _code;
    }

    function newStoreTransition(
        string _store
    ) public pure returns (Object memory transition) {
        transition.type = TransitionType.NEW_STORE;
        transition.store = _store;
    }

    function dispatchTransition(
        string _store,
        string _action,
        bytes _data
    ) public pure returns (Object memory transition) {
        transition.type = TransitionType.DISPATCH;
        transition.store = _store;
        transition.action = _action;
        transition.data = _data;
    }

    function getTransitionHash(Object transition) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(transition.type, transition.store, transition.action, transition.data));
    }
}
