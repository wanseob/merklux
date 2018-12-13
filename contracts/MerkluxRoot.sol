pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import {Roles} from "openzeppelin-solidity/contracts/access/Roles.sol";
import "./MerkluxStoreForProof.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import {Block} from "./Types.sol";


/**
 * @title Merklux
 * @dev Merklux contract only has the write permission on the
 */
contract MerkluxRoot is Secondary {
//    using block for block.object;
//    using roles for roles.role;
//    using ecdsa for bytes32;
//
//    mapping(bytes32 => bytes32) confirmed;
//    mapping(bytes32 => bytes32[]) unconfirmed;
//    mapping(bytes32 => block.object) childblocks;
//    roles.role users;
//
////    merkluxcase[] cases;
//
//    constructor () public secondary() {
//    }
//
////    // todo set modifier to allow only the pseudo-randomly selected snapshot submitter
////    function submit(block.object _block) public {
////        bytes32 hash = _block.getblockhash();
////        unconfirmed[_block.previousblockhash].push(hash);
////        childblocks[hash] = _block;
////    }
////
////    function accuse(block.object childblock) public {
//////        require(unconfirmed[childblock.previousblockhash] == childblock.getblockhash());
//////        cases.push(merkluxcase(childblock));
////    }
////    //    function createcase(bytes32 _prevhash, bytes32 _nexthash) public onlyprimary returns (address) {
////    //        merkluxcase case = new merkluxcase(_prevhash, _nexthash);
////    //        cases.push(case);
////    //        return address(case);
////    //    }
////
////    function _finalize(
////        address sealer,
////    // address[] validators,
////    // bytes32[] crosslinks,
////        uint256 height,
////        bytes32 previousblockhash,
////        bytes32[] reducers,
////        bytes32[] stores,
////        bytes32[] transitions
////    ) public {
////        // todo snapshot submitting reward
////        // todo validator reward
////        // todo execute cross links
////    }
////
////    function commitoriginalrootedgeforcase(
////        address _case,
////        uint _originallabellength,
////        bytes32 _originallabel,
////        bytes32 _originalvalue
////    ) public onlyprimary() {
////        //        merkluxcase(_case).commitoriginalrootedge(_originallabellength, _originallabel, _originalvalue);
////    }
////
////    //    function dispatch(string _namespace, address _reducer, string _action, bytes _data)
////    //    public
////    //    onlyfordispatchers(_namespace)
////    //    onlyforallowedreducers(_namespace, _reducer)
////    //    returns (bytes32)
////    //    {
////    //        require(reducers[_namespace].has(_reducer));
////    //        require(dispatchers[_namespace].has(msg.sender));
////    //        var (root, key, value) = merkluxreducer(_reducer).dispatch(_action, _data);
////    //        //        require(_reducer.delegatecall(msg.data));
////    //        //        return keccak256(bytes('hi'));
////    //    }
////
////    function registeruser() public {
////        users.add(msg.sender);
////    }
////
////    function verifytransaction(
////        address _from,
////        address _reducer,
////        bytes _data,
////        bytes _signature
////    ) public view returns (bool) {
////        if (!users.has(_from)) {
////            return false;
////        } else {
////            return true;
////        }
////    }
}
