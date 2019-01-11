pragma solidity ^0.4.0;

library StringUtil {
    function equals(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

