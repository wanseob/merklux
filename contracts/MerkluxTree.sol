pragma solidity ^0.4.24;

import {PatriciaTree} from "../libs/chriseth/patricia-trie/patricia.sol";
import {D} from "../libs/chriseth/patricia-trie/data.sol";
import {Utils} from "../libs/chriseth/patricia-trie/utils.sol";
import "openzeppelin-solidity/contracts/ownership/Secondary.sol";


/**
 * @title MerkluxTree data structure for
 *
 */
contract MerkluxTree is Secondary, PatriciaTree {
    constructor() public Secondary() {
    }

    function insert(bytes key, bytes value) public onlyPrimary {
        super.insert(key, value);
    }

    function get(bytes key) public view returns (bytes) {
        return getValue(_findNode(key));
    }

    function getValue(bytes32 valueHash) public view returns (bytes) {
        return values[valueHash];
    }

    function getRootHash() public view returns (bytes32) {
        return root;
    }

    function _findNode(bytes key) internal view returns (bytes32) {
        if (rootEdge.node == 0 && rootEdge.label.length == 0) {
            return 0;
        } else {
            D.Label memory k = D.Label(keccak256(key), 256);
            return _findAtEdge(rootEdge, k);
        }
    }

    function _findAtNode(bytes32 nodeHash, D.Label key) internal returns (bytes32) {
        require(key.length > 1);
        D.Node memory n = nodes[nodeHash];
        var (head, tail) = Utils.chopFirstBit(key);
        return _findAtEdge(n.children[head], tail);
    }

    function _findAtEdge(D.Edge e, D.Label key) internal view returns (bytes32){
        require(key.length >= e.label.length);
        var (prefix, suffix) = Utils.splitCommonPrefix(key, e.label);
        if (suffix.length == 0) {
            // Full match with the key, update operation
            return e.node;
        } else if (prefix.length >= e.label.length) {
            // Partial match, just follow the path
            return _findAtNode(e.node, suffix);
        } else {
            // Mismatch, so let us create a new branch node.
            revert();
        }
    }
}
