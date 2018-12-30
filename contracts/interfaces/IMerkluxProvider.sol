pragma solidity ^0.4.0;

import "./IMerkluxReducerRegistry.sol";
import "../MerkluxStore.sol";
import {Block, Chain} from "../Types.sol";

contract IMerkluxProvider {
    function getChain() internal view returns (Chain.Object storage);

    function getStore() internal view returns (MerkluxStore);

    function getRegistry() internal view returns (IMerkluxReducerRegistry);
}
