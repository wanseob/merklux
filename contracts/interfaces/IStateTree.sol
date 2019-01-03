pragma solidity ^0.4.24;


/**
 * @title IMerkluxTree data structure for
 *
 */
contract IStateTree {
    function read(bytes key) public returns (bytes);
}
