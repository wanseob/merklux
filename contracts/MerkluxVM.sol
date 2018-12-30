pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./MerkluxStore.sol";
import "./interfaces/IMerkluxReducerRegistry.sol";
import "./interfaces/IMerkluxProvider.sol";
import {Block, Chain, Transition} from "./Types.sol";



/**
 * @title Merklux
 * @dev Merklux is a state management smart contract to control the state with a
 * unidirectional data flow. It can be used for state verifications accross evm
 * based block chains.
 */
contract MerkluxVM is IMerkluxProvider {
    string constant SET_REDUCER = "SET_REDUCER";

    using Block for Block.Object;
    using Chain for Chain.Object;
    using SafeMath for uint256;
    using ECDSA for bytes32;

    // Every action dispatches increment the txNum
    //    uint256 public txNum;

    event Sealed(bytes32 _blockHash, bytes _signature);

    function dispatch(string _action, bytes _data, bytes32 _prevBlock, uint256 _nonce, bool _deployReducer, bytes _signature) public {
        Chain.Object storage chain = getChain();
        IMerkluxReducerRegistry registry = getRegistry();
        MerkluxStore store = getStore();
        bytes32 lastBlockHash = chain.getLastBlockHash();
        // only accept when prev block is same
        require(_prevBlock == lastBlockHash);
        // check the signature
        address from = keccak256(abi.encodePacked(
                _action,
                _data,
                _prevBlock,
                _nonce,
                _deployReducer
            )).toEthSignedMessageHash().recover(_signature);

        // increase nonce
        store.increaseAccountTxNonce(from, _nonce);

        // update state tree & reference tree
        if (_deployReducer) {
            store.deployReducer(registry, _action, _data);
        } else {
            store.runReducer(registry, from, _action, _data);
        }

        store.putTransition(
            lastBlockHash,
            from,
            _nonce,
            _action,
            _data
        );
    }

    // TODO set modifier to allow only the pseudo-randomly selected snapshot submitter
    function seal(bytes _signature) external {
        Block.Object memory candidate = _getBlockCandidate(msg.sender);
        Chain.Object storage chain = getChain();

        candidate.signature = _signature;
        // Check signature
        require(candidate.isSealed());
        bytes32 blockHash = candidate.getBlockHash();
        chain.addBlock(candidate);
        emit Sealed(blockHash, _signature);
    }

    function get(bytes _key) public view returns (bytes) {
        return getStore().get(_key);
    }

    function getBlockHashToSeal() public view returns (bytes32) {
        return _getBlockCandidate(msg.sender).getBlockHash();
    }

    function getDataForNewTx() public view returns (bytes32 prevBlockHash, uint256 nonce) {
        Chain.Object storage chain = getChain();
        MerkluxStore store = getStore();
        return (chain.getLastBlockHash(), store.getAccountTxNonce(msg.sender).add(1));
    }

    function getBlock(bytes32 _blockHash) public view returns (
        bytes32 _previousBlock,
        uint256 _txNum,
        bytes32 _state,
        bytes32 _references,
        bytes32 _transitions,
        address _sealer,
        bytes memory _signature
    ) {
        Chain.Object storage chain = getChain();
        return chain.getBlockWithHash(_blockHash);
    }

    function _getBlockCandidate(address _sealer) private view returns (Block.Object memory candidate) {
        Chain.Object storage chain = getChain();
        MerkluxStore store = getStore();
        candidate.previousBlock = chain.getLastBlockHash();
        candidate.txNum = store.getTxNum();
        candidate.state = store.getStateRoot();
        candidate.references = store.getReferenceRoot();
        candidate.transitions = store.getTransitionRoot();
        candidate.sealer = _sealer;
        return candidate;
    }
}
