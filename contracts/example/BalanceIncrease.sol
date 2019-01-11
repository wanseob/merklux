pragma solidity ^0.4.24;

import '../MerkluxReducer.sol';

contract BalanceIncrease is MerkluxReducer {
    function reduce(
        IStateTree _tree,
        address _from,
        bytes memory _encodedParams // rlp encoded params
    ) public returns (
        bytes memory _encodedPairs // rlp encoded key value pairs
    ) {
        // 1. Decode data with RLP decoder
        uint amount = _encodedParams.toRlpItem().toUint();

        // 2. Calculate
        bytes memory _senderKey = abi.encodePacked(_from);
        uint currentAmount = _tree.read(_senderKey).toRlpItem().toUint();

        // 3. Return pairs
        ReducerUtil.RlpData memory pairsToReturn;
        pairsToReturn = pairsToReturn.addUint(_senderKey, amount + currentAmount);
        return pairsToReturn.encode();
    }
}
