pragma solidity ^0.4.0;

import "./MerkluxStore.sol";
import "solidity-rlp/contracts/RLPReader.sol";
import "../libs/bakaoh/solidity-rlp-encode/contracts/RLPEncode.sol";

contract MerkluxReducer {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;


    /**
    * @dev This only returns key-value pairs to update, and keys which are referred during the calculation.
    * @param _tree The merkle tree to get & set states
    * @param _from The address of the transaction caller
    * @param _data RLP encoded data set for its reducer
    * @return rlp encoded keys to update
    * @return rlp encoded values for the keys. It has same length with the array of keys.
    * @return references Array of hashes of the keys in the merkle tree which are referred to return the key-value pairs.
    It is possible to process a merkle proof with a minimum number of nodes by submitting only the referred nodes.
    */
    function reduce(
        MerkluxStore _tree,
        address _from,
        bytes _data
    ) public view returns (
        bytes keys, // rlp encoded key values
        bytes values, // rlp encoded key valuesTODO return as bytes[] after the solidity 0.5.0
        bytes32[] references
    );

    /**
     * @dev RLP encodes a byte string.
     * @param self The byte string to encode.
     * @return The RLP encoded string in bytes.
     */
    function encodeBytes(bytes memory self) public pure returns (bytes) {
        return RLPEncode.encodeBytes(self);
    }


    /**
     * @dev RLP encodes a list of RLP encoded byte byte strings.
     * @param self The list of RLP encoded byte strings.
     * @return The RLP encoded list of items in bytes.
     */
    // It needs ABI Encoder V2
    //    function encodeList(bytes[] memory self) public pure returns (bytes) {
    //        return RLPEncode.encodeList(self);
    //    }

    /**
     * @dev RLP encodes a string.
     * @param self The string to encode.
     * @return The RLP encoded string in bytes.
     */
    function encodeString(string memory self) public pure returns (bytes) {
        return RLPEncode.encodeString(self);
    }

    /**
     * @dev RLP encodes an address.
     * @param self The address to encode.
     * @return The RLP encoded address in bytes.
     */
    function encodeAddress(address self) public pure returns (bytes) {
        return RLPEncode.encodeAddress(self);
    }

    /**
     * @dev RLP encodes a uint.
     * @param self The uint to encode.
     * @return The RLP encoded uint in bytes.
     */
    function encodeUint(uint self) public pure returns (bytes) {
        return RLPEncode.encodeUint(self);
    }

    /**
     * @dev RLP encodes an int.
     * @param self The int to encode.
     * @return The RLP encoded int in bytes.
     */
    function encodeInt(int self) public pure returns (bytes) {
        return RLPEncode.encodeInt(self);
    }

    /**
     * @dev RLP encodes a bool.
     * @param self The bool to encode.
     * @return The RLP encoded bool in bytes.
     */
    function encodeBool(bool self) public pure returns (bytes) {
        return RLPEncode.encodeBool(self);
    }

}
