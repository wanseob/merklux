pragma solidity ^0.4.24;

import "solidity-rlp/contracts/RLPReader.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/access/Roles.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "solidity-rlp/contracts/RLPReader.sol";
import "./MerkluxStore.sol";
import "./MerkluxReducer.sol";
import "./MerkluxStoreForProof.sol";
import "./MerkluxReducerRegistry.sol";
import {Block, Transition} from "./Types.sol";


contract MerkluxCase {
    using Transition for Transition.Object;
    using Block for Block.Object;
    using Block for Block.Data;
    using Roles for Roles.Role;
    using RLPReader for RLPReader.RLPItem;
    using SafeMath for uint256;
    using RLPReader for bytes;

    enum Task {
        SUBMIT_ORIGINAL_BLOCK,
        SUBMIT_REFERENCE_DATA,
        SUBMIT_STORE_DATA,
        SUBMIT_DISPATCHES
    }

    address public accuser;
    address public defendant;
    bytes32 public original;
    bytes32 public target;
    Roles.Role private attorneys;
    mapping(uint => bool) todos;

    uint256 public height;
    MerkluxStoreForProof storeForProof;
    MerkluxReducerRegistry registry;

    mapping(uint256 => Transition.Object) transitions;

    Block.Object originalBlock;
    Block.Data originalBlockData;

    mapping(bytes32 => bool) submittedReferences;

    event TaskDone(Task _task);

    modifier hasPredecessor(Task _task) {
        require(todos[uint(_task)]);
        _;
    }

    modifier subTask(Task _task) {
        require(!todos[uint(_task)]);
        _;
    }

    modifier task(Task _task) {
        require(!todos[uint(_task)]);
        _;
        _done(_task);
        emit TaskDone(_task);
    }

    /**
    * @dev Only the defendant can execute this function.
    * If the defendant appoint attorneys, then they are also allowed to call this function
    */
    modifier onlyDefendant() {
        require(msg.sender == defendant || attorneys.has(msg.sender));
        _;
    }

    constructor(
        bytes32 _originalRootHash,
        bytes32 _targetRootHash,
        address _defendant,
        address _reducerRegistry
    ) public {
        // Init status
        original = _originalRootHash;
        target = _targetRootHash;
        defendant = _defendant;
        accuser = msg.sender;
        registry = MerkluxReducerRegistry(_reducerRegistry);
    }

    function appoint(address _attorney) public onlyDefendant {
        attorneys.add(_attorney);
    }

    function cancel(address _attorney) public onlyDefendant {
        attorneys.remove(_attorney);
    }

    function destroy() external {
        require(msg.sender == accuser);
        // TODO When it has the fraud state, innocent state, or on_going state
        selfdestruct(accuser);
    }

    function submitBlockData(
        bytes32 _previousBlock,
        uint256 _height,
        bytes32 _store,
        bytes32 _references,
        bytes32 _transitions,
        address _sealer,
        bytes _signature
    ) public onlyDefendant task(Task.SUBMIT_ORIGINAL_BLOCK) {
        originalBlock.previousBlock = _previousBlock;
        originalBlock.height = _height;
        originalBlock.store = _store;
        originalBlock.references = _references;
        originalBlock.transitions = _transitions;
        originalBlock.sealer = _sealer;
        originalBlock.signature = _signature;
        require(originalBlock.getBlockHash() == original);
        require(originalBlock.isSealed());
        storeForProof = new MerkluxStoreForProof(_store);
        height = _height;
    }

    function submitReferredKeyData(
        bytes32[] _references
    ) public
    onlyDefendant
    hasPredecessor(Task.SUBMIT_ORIGINAL_BLOCK)
    task(Task.SUBMIT_REFERENCE_DATA)
    {
        originalBlockData.references = _references;
        require(originalBlockData.getReferenceRoot() == originalBlock.references);
    }

    function submitBranch(
        bytes _key,
        bytes _value,
        uint _branchMask,
        bytes32[] _siblings
    ) public
    onlyDefendant
    hasPredecessor(Task.SUBMIT_REFERENCE_DATA)
    subTask(Task.SUBMIT_STORE_DATA)
    {
        bytes32 _hashedKey = keccak256(_key);
        require(!submittedReferences[_hashedKey]);
        storeForProof.commitBranch(_key, _value, _branchMask, _siblings);

        // Check it is completed to commit all branch data for the referred nodes
        submittedReferences[_hashedKey] = true;
        bool submittedAllReferredNodes = true;
        for (uint i = 0; i < originalBlockData.references.length; i++) {
            if (!submittedReferences[originalBlockData.references[i]]) {
                submittedAllReferredNodes = false;
                break;
            }
        }
        if (submittedAllReferredNodes) {
            _done(Task.SUBMIT_STORE_DATA);
            emit TaskDone(Task.SUBMIT_STORE_DATA);
        }
    }

    function submitDispatch(
      uint256 _height,
      string _action,
      bytes _data
    ) public
    onlyDefendant
    hasPredecessor(Task.SUBMIT_STORE_DATA)
    subTask(Task.SUBMIT_DISPATCHES)
    {
      require(height==_height);

      MerkluxReducer reducer = registry.getReducer(storeForProof.getReducerKey(_action));

      bytes memory rlpEncodedKeys;
      bytes memory rlpEncodedValues;
      bytes32[] memory referredKeys;
      (rlpEncodedKeys, rlpEncodedValues, referredKeys) = reducer.reduce(storeForProof, msg.sender, _data);

      // compare referred keys & submitted references
      // (referredKeys);

      RLPReader.RLPItem[] memory keys = rlpEncodedKeys.toRlpItem().toList();
      RLPReader.RLPItem[] memory values = rlpEncodedValues.toRlpItem().toList();
      require(keys.length == values.length);

      for (uint i = 0; i < keys.length; i++) {
        storeForProof.insert(keys[i].toBytes(), values[i].toBytes());
      }

      // Calculate first
      height = height.add(1);
    }

    function isNeeded(bytes memory _key) hasPredecessor(Task.SUBMIT_REFERENCE_DATA) public view returns (bool) {
        bytes32 _hashedKey = keccak256(_key);
        for (uint i = 0; i < originalBlockData.references.length; i++) {
            // If it is included in the referred key list
            if (originalBlockData.references[i] == _hashedKey) {
                // Check it is already submitted or not
                return !submittedReferences[_hashedKey];
            }
        }
        // It is not included in the referred key list
        return false;
    }

    function _done(Task _task) private {
        todos[uint(_task)] = true;
    }
}
