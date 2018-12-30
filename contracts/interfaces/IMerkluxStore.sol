pragma solidity ^0.4.24;


/**
 * @title IMerkluxTree data structure for
 *
 */
contract IMerkluxStore {
    function read(bytes key) public returns (bytes);
}
