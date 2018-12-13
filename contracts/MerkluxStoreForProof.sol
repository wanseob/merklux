pragma solidity ^0.4.24;


import {PartialMerkleTree} from "solidity-partial-tree/contracts/tree.sol";
import {D} from "solidity-partial-tree/contracts/data.sol";
import "openzeppelin-solidity/contracts/ownership/Secondary.sol";

contract MerkluxStoreForProof is Secondary {
    using PartialMerkleTree for PartialMerkleTree.Tree;
    string constant REDUCER = "&";

    PartialMerkleTree.Tree tree;

    constructor() public Secondary() {
    }

    function insert(bytes key, bytes value) public onlyPrimary {
        if (key.length > 1) {
            // Reducer cannot be overwritten through this function
            require(!(key[0] == byte(0) && key[1] == byte(38)));
        }
        tree.insert(key, value);
    }

    function setReducer(string _action, bytes32 _reducerHash) public onlyPrimary {
        tree.insert(_appendPrefix(_action), abi.encodePacked(_reducerHash));
    }

    function commitBranch(bytes key, bytes value, uint branchMask, bytes32[] siblings) public onlyPrimary {
        tree.commitBranch(key, value, branchMask, siblings);
    }

    function getReducerKey(string _action) public view returns (bytes32) {
        bytes32 _reducerHash;
        bytes memory _storedValue = tree.get(_appendPrefix(_action));

        if (_storedValue.length == 32) {
            for (uint i = 0; i < 32; i++) {
                _reducerHash |= bytes32(_storedValue[i] & 0xFF) >> (i * 8);
            }
            return _reducerHash;
        }
        else return bytes32(0);
    }

    function get(bytes key) public view returns (bytes) {
        return tree.get(key);
    }

    function getLeafValue(bytes32 valueHash) public view returns (bytes) {
        return tree.getValue(valueHash);
    }

    function getRootHash() public view returns (bytes32) {
        return tree.getRootHash();
    }

    /**
     * @dev
     * @return _reducerKey always starts with 0x0026
     */
    function _appendPrefix(string _action) private pure returns (bytes memory _reducerKey) {
        bytes memory _a = bytes(_action);
        _reducerKey = new bytes(_a.length + 2);
        _reducerKey[0] = byte(0);
        _reducerKey[1] = byte(38);
        for (uint i = 2; i < _reducerKey.length; i++) _reducerKey[i] = _a[i - 2];
    }
}
