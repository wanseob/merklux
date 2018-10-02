pragma solidity ^0.4.24;

import {PatriciaTree} from "../libs/chriseth/patricia-trie/patricia.sol";

contract MerkluxTree is PatriciaTree {
    mapping(bytes=>mapping(bytes=>bytes)) store;
    mapping(bytes=>address[]) allowedReducers;

    function set(bytes key, bytes value)  {
        insert(key, value);
    }
    function get(bytes key) returns (bytes) {

    }
}
