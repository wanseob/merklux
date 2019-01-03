pragma solidity ^0.4.24;

import "./IMerkluxReducerRegistry.sol";

/**
 * @title MerkluxTree data structure for
 *
 */
contract IMerkluxStoreForVM {
    function deployReducer(IMerkluxReducerRegistry _registry, string _action, bytes _data) public;

    function runReducer(IMerkluxReducerRegistry _registry, address _sender, string _action, bytes _data) public;

    function increaseAccountActionNonce(address _user, uint256 _nonce) public;

    function putAction(
        bytes32 _prevBlockHash,
        address _from,
        uint256 _nonce,
        string _action,
        bytes _data,
        bytes _sig
    ) public returns (bytes32);

    function resetCurrentData() public;

    function getActionNum() public view returns (uint256);

    function getStateRoot() public view returns (bytes32);

    function getReferenceRoot() public view returns (bytes32);

    function getActionRoot() public view returns (bytes32);

    function getAccountActionNonce(address _sender) public view returns (uint256);
}
