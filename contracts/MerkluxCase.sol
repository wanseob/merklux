pragma solidity ^0.4.24;

import "solidity-rlp/contracts/RLPReader.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/access/Roles.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "./MerkluxStore.sol";
import "./MerkluxReducer.sol";
import "./MerkluxStoreForProof.sol";
import {Block, Transition} from "./Types.sol";


contract MerkluxCase {
    using Transition for Transition.Object;
    using Block for Block.Object;
    using Block for Block.Data;
    using Roles for Roles.Role;
    enum Task {
        SUBMIT_ORIGINAL_BLOCK,
        SUBMIT_STORE_DATA,
        SUBMIT_REFERENCE_DATA,
        SUBMIT_SEAL_STORES,
        SUBMIT_DISPATCHES
    }

    address public accuser;
    address public defendant;
    bytes32 public original;
    bytes32 public target;
    Roles.Role private attorneys;
    mapping(uint => bool) todos;

    uint256 public height;
    mapping(bytes32 => MerkluxStoreForProof) stores;
    mapping(uint256 => Transition.Object) transitions;

    Block.Object originalBlock;
    Block.Data originalBlockData;

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
        todos[uint(_task)] = true;
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
        address _defendant
    ) public {
        // Init status
        original = _originalRootHash;
        target = _targetRootHash;
        defendant = _defendant;
        accuser = msg.sender;
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

    function commitOriginalBlock(
        bytes32 _previousBlock,
        uint256 _height,
        bytes32 _stores,
        bytes32 _references,
        bytes32 _transitions,
        address _sealer,
        bytes _signature
    ) public onlyDefendant task(Task.SUBMIT_ORIGINAL_BLOCK) {
        originalBlock.previousBlock = _previousBlock;
        originalBlock.height = _height;
        originalBlock.stores = _stores;
        originalBlock.references = _references;
        originalBlock.transitions = _transitions;
        originalBlock.sealer = _sealer;
        originalBlock.signature = _signature;
        require(originalBlock.getBlockHash() == original);
        require(originalBlock.isSealed());
    }

    function commitStoreForOriginalBlockData(
        bytes32[] _storeKeys,
        bytes32[] _storeHashes
    )
    onlyDefendant
    hasPredecessor(Task.SUBMIT_ORIGINAL_BLOCK)
    task(Task.SUBMIT_STORE_DATA)
    {
        originalBlockData.storeKeys = _storeKeys;
        require(_storeKeys.length == _storeHashes.length);
        for (uint i = 0; i < _storeKeys.length; i++) {
            originalBlockData.storeHashes[_storeKeys[i]] = _storeHashes[i];
        }
        require(originalBlockData.getStoreRoot() == originalBlock.stores);
    }

    function commitReferencesForOriginalBlockData(
        bytes32 _storeKey,
        bytes32[] _references
    )
    onlyDefendant
    hasPredecessor(Task.SUBMIT_ORIGINAL_BLOCK)
    task(Task.SUBMIT_REFERENCE_DATA)
    {
        originalBlockData.references[_storeKey] = _references;
        require(originalBlockData.getReferenceRoot() == originalBlock.references);
    }

    function commitBranch(
        bytes32 _storeKey,
        bytes _key,
        bytes _value,
        uint _branchMask,
        bytes32[] _siblings
    ) public
    onlyDefendant
    hasPredecessor(Task.SUBMIT_STORE_DATA)
    subTask(Task.SUBMIT_SEAL_STORES)
    {

    }

    function commitOriginalEdgeOfStore(
        bytes32 _storeKey,
        uint _originalLabelLength,
        bytes32 _originalLabel,
        bytes32 _originalValue
    ) public
    onlyDefendant
    hasPredecessor(Task.SUBMIT_STORE_DATA)
    subTask(Task.SUBMIT_SEAL_STORES)
    {
        require(stores[_storeKey] == address(0));
        bytes32 originalRootHash = originalBlockData.storeHashes[_storeKey];
        MerkluxStoreForProof storeForProof = new MerkluxStoreForProof(originalRootHash);
        stores[_storeKey] = storeForProof;
        storeForProof.commitOriginalEdge(
            _originalLabelLength,
            _originalLabel,
            _originalValue
        );
    }

    function commitNodeOfStore(
        bytes32 _storeKey,
        bytes32 _nodeHash,
        uint _firstEdgeLabelLength,
        bytes32 _firstEdgeLabel,
        bytes32 _firstEdgeValue,
        uint _secondEdgeLabelLength,
        bytes32 _secondEdgeLabel,
        bytes32 _secondEdgeValue
    ) public
    onlyDefendant
    hasPredecessor(Task.SUBMIT_STORE_DATA)
    subTask(Task.SUBMIT_SEAL_STORES)
    {
        MerkluxStoreForProof storeForProof = stores[_storeKey];
        storeForProof.commitNode(
            _nodeHash,
            _firstEdgeLabelLength,
            _firstEdgeLabel,
            _firstEdgeValue,
            _secondEdgeLabelLength,
            _secondEdgeLabel,
            _secondEdgeValue
        );
    }

    function commitReferredValue(
        bytes32 _storeKey,
        bytes _value
    ) public
    onlyDefendant
    hasPredecessor(Task.SUBMIT_STORE_DATA)
    subTask(Task.SUBMIT_SEAL_STORES)
    {
        MerkluxStoreForProof storeForProof = stores[_storeKey];
        storeForProof.commitValue(
            _value
        );
    }


    function sealAllStores()
    onlyDefendant
    hasPredecessor(Task.SUBMIT_STORE_DATA)
    subTask(Task.SUBMIT_SEAL_STORES)
    {
        for (uint i = 0; i < originalBlockData.storeKeys.length; i ++) {
            bytes32 storeKey = originalBlockData.storeKeys[i];
            require(stores[storeKey] != address(0));
            require(stores[storeKey].status() == MerkluxStoreForProof.Status.READY);
        }
    }
}