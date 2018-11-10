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
        bytes keys, // rlp encoded key values
        bytes values, // rlp encoded key valuesTODO return as bytes[] after the solidity 0.5.0
        bytes32[] references
    ) {
        // Decode data with RLP decoder
        uint amount = _data.toRlpItem().toUint();
        // Check current state
        bytes memory _senderKey = abi.encodePacked(_from);
        uint currentAmount = _tree.get(_senderKey).toRlpItem().toUint();

        // Prepare arrays to return
        bytes[] memory encodedKeys = new bytes[](1);
        bytes[] memory encodedValues = new bytes[](1);

        // Encode key-value pairs
        encodedKeys[0] = encodeBytes(_senderKey);
        encodedValues[0] = encodeUint(amount + currentAmount);

        // Encode list
        keys = encodedKeys.encodeList();
        values = encodedValues.encodeList();
        references = new bytes32[](1);
        references[0] = keccak256(_senderKey);
    }
}
