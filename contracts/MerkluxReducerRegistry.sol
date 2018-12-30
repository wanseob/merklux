pragma solidity ^0.4.24;

import "./MerkluxReducer.sol";
import "./interfaces/IMerkluxReducerRegistry.sol";
import "openzeppelin-solidity/contracts/ownership/Secondary.sol";

contract MerkluxReducerRegistry is IMerkluxReducerRegistry {
    mapping(bytes32 => MerkluxReducer) reducers;

    /**
     * @dev It allows to update reducer by overwriting
     *
     * @param _code Compiled reducer code to deploy
     */
    function registerReducer(bytes _code) public returns (bytes32 reducerKey, address reducerAddress) {// TODO committee
        // Check it is already deployed or not
        reducerKey = keccak256(_code);
        if (isDeployed(reducerKey)) {
            return (reducerKey, address(reducers[reducerKey]));
        } else {
            // Deploy
            assembly {
                reducerAddress := create(0, add(_code, 0x20), mload(_code))
            }
            // Store
            reducers[reducerKey] = MerkluxReducer(reducerAddress);
            return (reducerKey, reducerAddress);
        }
    }

    function getReducer(bytes32 _reducerKey) public view returns (MerkluxReducer) {
//        require(_reducerKey != bytes32(0));
        // The reducer also should exist
//        require(isDeployed(_reducerKey));
        return reducers[_reducerKey];
    }

    function isDeployed(bytes32 _reducerKey) public view returns (bool) {
        return address(reducers[_reducerKey]) != address(0);
    }
}
