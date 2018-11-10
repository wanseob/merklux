pragma solidity ^0.4.24;

import '../MerkluxReducer.sol';
import "../MerkluxStore.sol";
import "../../libs/bakaoh/solidity-rlp-encode/contracts/RLPEncode.sol";

contract BalanceIncrease is MerkluxReducer {
    function reduce(
        MerkluxStore _tree,
        address _from,
        bytes _data // rlp encoded params
    ) public view returns (
        bytes encodedKeys, // rlp encoded key values
        bytes encodedValues, // rlp encoded key valuesTODO return as bytes[] after the solidity 0.5.0
        bytes32[] referredNodes
    ) {
        // Decode data with RLP decoder
        uint amount = _data.toRlpItem().toUint();
        // Check current state
        bytes memory _senderKey = abi.encodePacked(_from);
        uint currentAmount = _tree.get(_senderKey).toRlpItem().toUint();

        // Prepare arrays to return
        bytes[] memory keys = new bytes[](1);
        bytes[] memory values = new bytes[](1);

        // Encode key-value pairs
        keys[0] = encodeBytes(_senderKey);
        values[0] = encodeUint(amount + currentAmount);

        // Encode list
        encodedKeys = keys.encodeList();
        encodedValues = values.encodeList();
        referredNodes = new bytes32[](1);
        referredNodes[0] = keccak256(_senderKey);
    }
}
