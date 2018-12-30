pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "./MerkluxReducerRegistry.sol";
import "./MerkluxVM.sol";


/**
 * @title Merklux
 * @dev Merklux is a state management smart contract to control the state with a
 * unidirectional data flow. It can be used for state verifications accross evm
 * based block chains.
 */
contract MerkluxChain is Secondary, MerkluxVM {
    string constant SET_REDUCER = "SET_REDUCER";

    // Every action dispatches increment the height
    Chain.Object private chain;
    MerkluxStore private store;
    MerkluxReducerRegistry private registry;

    constructor () public Secondary() {
        Block.Object memory genesis;
        store = new MerkluxStore();
        registry = new MerkluxReducerRegistry();
        chain.addBlock(genesis);
    }

    function dispatch(string _action, bytes _data, bytes32 _prevBlock, uint256 _nonce, bool _deployReducer, bytes _signature) public onlyPrimary {
        super.dispatch(_action, _data, _prevBlock, _nonce, _deployReducer, _signature);
    }

    function makeTx(
        string _action,
        bytes _data,
        bool _deployReducer
    ) public view returns (
        bytes32 txHash,
        bytes32 prevBlockHash,
        uint256 nonce
    ) {
        (prevBlockHash, nonce) = getDataForNewTx();
        txHash = keccak256(abi.encodePacked(
                _action,
                _data,
                prevBlockHash,
                nonce,
                _deployReducer
            ));
    }

    function getChain() internal view returns (Chain.Object storage) {
        return chain;
    }

    function getStore() internal view returns (MerkluxStore) {
        return store;
    }

    function getRegistry() internal view returns (IMerkluxReducerRegistry) {
        return registry;
    }
}
