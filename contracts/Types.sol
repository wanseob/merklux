pragma solidity ^0.4.24;

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

    function getBlockHash(Object memory _block) internal pure returns (bytes32){
        return keccak256(abi.encodePacked(
                _block.height,
                _block.previousBlockHash,
                abi.encodePacked(_block.reducers),
                abi.encodePacked(_block.stores),
                abi.encodePacked(_block.transitions)
            )
        );
    }
}

library Transition {
    enum Type  {SET_REDUCER, NEW_STORE, DISPATCH}

    struct Object {
        Type sort;
        bytes32 store;
        string action;
        bytes data;
    }

    function getTransitionHash(Object transition) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(transition.sort, transition.store, transition.action, transition.data));
    }
}
