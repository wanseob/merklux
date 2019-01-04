pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./interfaces/IMerkluxReducerRegistry.sol";
import "./interfaces/IMerkluxProvider.sol";
import "./interfaces/IMerkluxStoreForVM.sol";
import {Block, Chain} from "./Types.sol";



/**
 * @title Merklux
 * @dev Merklux is a state management smart contract to control the state with a
 * unidirectional data flow. It can be used for state verifications accross evm
 * based block chains.
 */

contract MerkluxVM is IMerkluxProvider {
    using Block for Block.Object;
    using Chain for Chain.Object;
    using SafeMath for uint256;
    using ECDSA for bytes32;

    // Every action dispatches increment the actionNum
    //    uint256 public actionNum;

    event Dispatched(bytes32 _actionHash);
    event Sealed(bytes32 _blockHash, bytes _signature);

    function dispatch(
        string _action,
        bytes _data,
        bytes32 _prevBlock,
        uint256 _nonce,
        bool _deployReducer,
        bytes _signature
    ) public {
        IMerkluxReducerRegistry registry = getRegistry();
        IMerkluxStoreForVM store = getStore();
        // only accept when prev block is same
        require(_isRecent(_prevBlock));
        // check the signature
        address _from = keccak256(abi.encodePacked(
                _action,
                _data,
                _prevBlock,
                _nonce,
                _deployReducer
            )).toEthSignedMessageHash().recover(_signature);

        // increase nonce
        store.increaseAccountActionNonce(_from, _nonce);

        // update state tree & reference tree
        if (_deployReducer) {
            store.deployReducer(registry, _action, _data);
        } else {
            store.runReducer(registry, _from, _action, _data);
        }

        // record action
        bytes32 actionHash = store.putAction(
            _prevBlock,
            _from,
            _nonce,
            _action,
            _deployReducer,
            _data,
            _signature
        );
        emit Dispatched(actionHash);
    }

    // TODO set modifier to allow only the pseudo-randomly selected snapshot submitter
    function seal(bytes _signature) external {
        Block.Object memory candidate = _getBlockCandidate(msg.sender);
        Chain.Object storage chain = getChain();
        IMerkluxStoreForVM store = getStore();

        candidate.signature = _signature;
        // Check signature
        require(candidate.isSealed());
        bytes32 blockHash = candidate.getBlockHash();
        chain.addBlock(candidate);
        emit Sealed(blockHash, _signature);
        store.resetCurrentData();
    }

    function getBlockHashToSeal() public view returns (bytes32) {
        return _getBlockCandidate(msg.sender).getBlockHash();
    }

    function getDataForNewAction() public view returns (bytes32 prevBlockHash, uint256 nonce) {
        Chain.Object storage chain = getChain();
        IMerkluxStoreForVM store = getStore();
        return (chain.getLastBlockHash(), store.getAccountActionNonce(msg.sender).add(1));
    }

    function getBlock(bytes32 _blockHash) public view returns (
        bytes32 _previousBlock,
        uint256 _actionNum,
        bytes32 _state,
        bytes32 _references,
        bytes32 _actions,
        address _sealer,
        bytes memory _signature
    ) {
        Chain.Object storage chain = getChain();
        return chain.getBlockWithHash(_blockHash);
    }

    function _isRecent(bytes32 _hash) private view returns (bool){
        Chain.Object storage chain = getChain();
        return (chain.getLastBlockHash() == _hash);
    }

    function _getBlockCandidate(address _sealer) private view returns (Block.Object memory candidate) {
        Chain.Object storage chain = getChain();
        IMerkluxStoreForVM store = getStore();
        candidate.previousBlock = chain.getLastBlockHash();
        candidate.actionNum = store.getActionNum();
        candidate.state = store.getStateRoot();
        candidate.references = store.getReferenceRoot();
        candidate.actions = store.getActionRoot();
        candidate.sealer = _sealer;
        return candidate;
    }
}
