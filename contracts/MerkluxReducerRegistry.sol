pragma solidity ^0.4.24;

import "./MerkluxReducer.sol";

contract MerkluxReducerRegistry {
    /**
     * @dev It allows to update reducer by overwriting
     *
     * @param _code Compiled reducer code to deploy
     */
    mapping(bytes32 => MerkluxReducer) reducers;

    function registerReducer(bytes _code) internal returns (bytes32 reducerKey){// TODO committee
        // Check it is already deployed or not
        reducerKey = keccak256(_code);
        require(!isDeployed(reducerKey));

        // Deploy
        address reducerAddress;
        assembly {
            reducerAddress := create(0, add(_code, 0x20), mload(_code))
        }

        // Store
        reducers[reducerKey] = MerkluxReducer(reducerAddress);
    }

    function getReducer(bytes32 _reducerKey) public view returns (MerkluxReducer) {
        require(_reducerKey != bytes32(0));
        // The reducer also should exist
        require(isDeployed(_reducerKey));
        return reducers[_reducerKey];
    }

    function isDeployed(bytes32 _reducerKey) public view returns (bool) {
        return reducers[_reducerKey] != address(0);
    }
}
