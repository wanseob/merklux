pragma solidity ^0.4.0;

import {Block, Chain} from "../Types.sol";
import "./IMerkluxReducerRegistry.sol";
import "./IMerkluxStoreForVM.sol";

contract IMerkluxProvider {
    function getChain() internal view returns (Chain.Object storage);

    function getStore() internal view returns (IMerkluxStoreForVM);

    function getRegistry() internal view returns (IMerkluxReducerRegistry);
}
