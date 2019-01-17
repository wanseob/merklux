pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "./MerkluxVM.sol";
import "./MerkluxStore.sol";


/**
 * @title Merklux
 * @dev Merklux is a state management smart contract to control the state with a
 * unidirectional data flow. It can be used for state verifications accross evm
 * based block chains.
 */
contract MerkluxChain is Secondary, MerkluxVM {
    // Every action dispatches increment the height
    MerkluxStore public store;
    IMerkluxReducerRegistry public registry;
    Chain.Object private chain;

    constructor () public Secondary() {
        Block.Object memory genesis;
        chain.addBlock(genesis);
    }

    function init(address _store, address _registry) public onlyPrimary {
        require(_store != address(0), "MerkluxChain: invalid store address");
        require(_registry != address(0), "MerkluxChain: invalid registry address");
        store = MerkluxStore(_store);
        registry = IMerkluxReducerRegistry(_registry);
    }

    function dispatch(
        string _action,
        bytes _data,
        bytes32 _prevBlock,
        uint256 _nonce,
        bool _deployReducer,
        bytes _signature
    ) public onlyPrimary {
        super.reduce(_action, _data, _prevBlock, _nonce, _deployReducer, _signature);
    }

    function makeAction(
        string _action,
        bytes _data,
        bool _deployReducer
    ) public view returns (
        bytes32 actionHash,
        bytes32 prevBlockHash,
        uint256 nonce
    ) {
        (prevBlockHash, nonce) = getDataForNewAction();
        actionHash = keccak256(
            abi.encodePacked(
                _action,
                _data,
                prevBlockHash,
                nonce,
                _deployReducer
            )
        );
    }

    function getLastBlock() public view returns (bytes32) {
        return chain.getLastBlockHash();
    }

    function getChain() internal view returns (Chain.Object storage) {
        return chain;
    }

    function getStore() internal view returns (IMerkluxStoreForVM) {
        return store;
    }

    function getRegistry() internal view returns (IMerkluxReducerRegistry) {
        return registry;
    }
}
