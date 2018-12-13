pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";

library Block {
    using ECDSA for bytes32;
    using Transition for Transition.Object;

    struct Object {
        bytes32 previousBlock;
        uint256 height;
        bytes32 stores;
        bytes32 references;
        bytes32 transitions;
        address sealer;
        bytes signature;
        // address[] validators; TODO use modified Casper
        // bytes32[] crosslinks; TODO
    }

    struct Data {
        bytes32 storeHash;
        bytes32[] references;
        Transition.Object[] transitions;
    }

    function isSealed(Object memory _block) internal pure returns (bool) {
        return _block.sealer == getBlockHash(_block).toEthSignedMessageHash().recover(_block.signature);
    }

    function getBlockHash(Object memory _block) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
                _block.previousBlock,
                _block.height,
                _block.stores,
                _block.references,
                _block.transitions,
                _block.sealer
            )
        );
    }

    function getStoreRoot(Data storage _data) internal view returns (bytes32) {
        bytes32[] memory storeHashes = new bytes32[](_data.storeKeys.length);
        for (uint i = 0; i < _data.storeKeys.length; i++) {
            storeHashes[i] = _data.storeHashes[_data.storeKeys[i]];
        }
        return keccak256(abi.encodePacked(storeHashes));
    }

    function getReferenceRoot(Data storage _data) internal view returns (bytes32) {
        bytes32[] memory referencesForEachStore = new bytes32[](_data.storeKeys.length);
        for (uint i = 0; i < _data.storeKeys.length; i++) {
            referencesForEachStore[i] = keccak256(abi.encodePacked(_data.references[_data.storeKeys[i]]));
        }
        return keccak256(abi.encodePacked(referencesForEachStore));
    }

    function getTransitionRoot(Data storage _data) internal view returns (bytes32) {
        bytes32[] memory transitions = new bytes32[](_data.transitions.length);
        for (uint i = 0; i < _data.transitions.length; i++) {
            transitions[i] = _data.transitions[i].getTransitionHash();
        }
        return keccak256(abi.encodePacked(transitions));
    }
}

library Transition {
    enum Type  {SET_REDUCER, NEW_STORE, DISPATCH}

    struct Object {
        address from;
        Type sort;
        uint256 height;
        bytes32 store;
        string action;
        bytes data;
    }

    function getTransitionHash(Object transition) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
                transition.from,
                transition.sort,
                transition.height,
                transition.store,
                transition.action,
                transition.data)
        );
    }
}
