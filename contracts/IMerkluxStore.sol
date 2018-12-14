pragma solidity ^0.4.24;


/**
 * @title IMerkluxTree data structure for
 *
 */
contract IMerkluxStore {
    function insert(bytes key, bytes value) public;

    function setReducer(string _action, bytes32 _reducerHash) public;

    function getReducerKey(string _action) public view returns (bytes32);

    function get(bytes key) public view returns (bytes);

    function getLeafValue(bytes32 valueHash) public view returns (bytes);

    function getRootHash() public view returns (bytes32);
}
