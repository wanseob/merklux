pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

library Block {
    using SafeMath for uint256;
    using ECDSA for bytes32;
    using Action for Action.Object;

    struct Object {
        bytes32 previousBlock;
        uint256 actionNum;
        bytes32 state;
        bytes32 references;
        bytes32 actions;
        address sealer;
        bytes signature;
        // address[] validators; TODO use modified Casper
        // bytes32[] crosslinks; TODO
    }

    function isSealed(Object memory _block) internal pure returns (bool) {
        return _block.sealer == getBlockHash(_block).toEthSignedMessageHash().recover(_block.signature);
    }

    function getBlockHash(Object memory _block) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
                _block.previousBlock,
                _block.actionNum,
                _block.state,
                _block.references,
                _block.actions,
                _block.sealer
            )
        );
    }
}

library Chain {
    using SafeMath for uint256;
    struct Object {
        bytes32[] chain;
        mapping(bytes32 => Block.Object) blocks;
    }

    function addBlock(Object storage _obj, Block.Object memory _candidate) internal {
        bytes32 blockHash = Block.getBlockHash(_candidate);
        if (_obj.chain.length > 0) {
            require(_obj.blocks[_candidate.previousBlock].actionNum < _candidate.actionNum);
        }
        _obj.chain.push(blockHash);
        _obj.blocks[blockHash] = _candidate;
    }

    function getLastBlockHash(Object storage _obj) internal view returns (bytes32) {
        return _obj.chain[_obj.chain.length - 1];
    }

    function getBlockWithHash(Object storage _obj, bytes32 _hash) internal view returns (
        bytes32 _previousBlock,
        uint256 _actionNum,
        bytes32 _state,
        bytes32 _references,
        bytes32 _actions,
        address _sealer,
        bytes memory _signature
    ) {
        Block.Object storage blockObj = _obj.blocks[_hash];
        return (
        blockObj.previousBlock,
        blockObj.actionNum,
        blockObj.state,
        blockObj.references,
        blockObj.actions,
        blockObj.sealer,
        blockObj.signature
        );
    }

    function getBlockWithHeight(Object storage _obj, uint _height) internal view returns (
        bytes32 _previousBlock,
        uint256 _actionNum,
        bytes32 _state,
        bytes32 _references,
        bytes32 _actions,
        address _sealer,
        bytes memory _signature
    ) {
        bytes32 hash = _obj.chain[_height - 1];
        return getBlockWithHash(_obj, hash);
    }

    function getHeight(Object storage _obj) internal view returns (uint256) {
        return _obj.chain.length;
    }
}

library Action {
    using ECDSA for bytes32;
    struct Object {
        bytes32 base;
        address from;
        uint256 actionNum;
        uint256 nonce;
        string action;
        bool deployReducer;
        bytes data;
        bytes signature;
    }

    function getActionHash(Object memory _action) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                _action.base,
                _action.from,
                _action.actionNum,
                _action.nonce,
                _action.action,
                _action.data
            )
        );
    }

    function isSigned(Object memory _action) internal pure returns (bool) {
        return _action.from == getActionHash(_action).toEthSignedMessageHash().recover(_action.signature);
    }
}
