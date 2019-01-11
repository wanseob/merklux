pragma solidity ^0.4.24;

import "../MerkluxReducer.sol";

contract IMerkluxReducerRegistry {
    function registerReducer(bytes _code) public returns (bytes32 reducerKey, address reducerAddress);

    function getReducer(bytes32 _reducerKey) public view returns (MerkluxReducer);

    function isDeployed(bytes32 _reducerKey) public view returns (bool);
}
