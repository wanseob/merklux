pragma solidity ^0.4.24;

import "solidity-rlp/contracts/RLPReader.sol";
import "./interfaces/IStateTree.sol";
import "./utils/ReducerUtil.sol";


contract MerkluxReducer {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    using ReducerUtil for ReducerUtil.RlpData;

    /**
    * @dev This only returns key-value pairs to update, and keys which are referred during the calculation.
    * @param _tree The merkle tree to get & set states
    * @param _from The address of the transaction caller
    * @param _encodedParams RLP encoded data set for its reducer
    * @return _encodedPairs rlp encoded keys value pairs to update
    It is possible to process a merkle proof with a minimum number of nodes by submitting only the referred nodes.
    */
    function reduce(IStateTree _tree, address _from, bytes _encodedParams) public returns (bytes memory _encodedPairs);
}
