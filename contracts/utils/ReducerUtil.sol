pragma solidity ^0.4.0;

import "../../libs/bakaoh/solidity-rlp-encode/contracts/RLPEncode.sol";

library ReducerUtil {
    using RLPEncode for bytes[];

    struct RlpData {
        bytes[] pairs;
    }

    function addBytes(RlpData memory obj, bytes key, bytes value) internal pure returns (RlpData memory newObj) {
        newObj.pairs = _extend(obj.pairs);
        newObj.pairs[newObj.pairs.length - 2] = RLPEncode.encodeBytes(key);
        newObj.pairs[newObj.pairs.length - 1] = RLPEncode.encodeBytes(value);
    }

    function addString(RlpData memory obj, bytes key, string value) internal pure returns (RlpData memory newObj) {
        newObj.pairs = _extend(obj.pairs);
        newObj.pairs[newObj.pairs.length - 2] = RLPEncode.encodeBytes(key);
        newObj.pairs[newObj.pairs.length - 1] = RLPEncode.encodeString(value);
    }

    function addAddress(RlpData memory obj, bytes key, address value) internal pure returns (RlpData memory newObj) {
        newObj.pairs = _extend(obj.pairs);
        newObj.pairs[newObj.pairs.length - 2] = RLPEncode.encodeBytes(key);
        newObj.pairs[newObj.pairs.length - 1] = RLPEncode.encodeAddress(value);
    }

    function addUint(RlpData memory obj, bytes key, uint value) internal pure returns (RlpData memory newObj) {
        newObj.pairs = _extend(obj.pairs);
        newObj.pairs[newObj.pairs.length - 2] = RLPEncode.encodeBytes(key);
        newObj.pairs[newObj.pairs.length - 1] = RLPEncode.encodeUint(value);
    }

    function addInt(RlpData memory obj, bytes key, int value) internal pure returns (RlpData memory newObj) {
        newObj.pairs = _extend(obj.pairs);
        newObj.pairs[newObj.pairs.length - 2] = RLPEncode.encodeBytes(key);
        newObj.pairs[newObj.pairs.length - 1] = RLPEncode.encodeInt(value);
    }

    function addBool(RlpData memory obj, bytes key, bool value) internal pure returns (RlpData memory newObj) {
        newObj.pairs = _extend(obj.pairs);
        newObj.pairs[newObj.pairs.length - 2] = RLPEncode.encodeBytes(key);
        newObj.pairs[newObj.pairs.length - 1] = RLPEncode.encodeBool(value);
    }

    function _extend(bytes[] memory pairs) private pure returns (bytes[] memory newPairs) {
        newPairs = new bytes[](pairs.length + 2);
        for (uint i = 0; i < newPairs.length - 2; i++) {
            newPairs[i] = pairs[i];
        }
    }

    function encode(RlpData memory obj) internal pure returns (bytes) {
        return obj.pairs.encodeList();
    }
}
