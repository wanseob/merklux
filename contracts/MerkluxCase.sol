pragma solidity ^0.4.24;

import "./MerkluxChain.sol";
import "./MerkluxStoreForCase.sol";

contract MerkluxCase is Secondary, MerkluxVM {
    using Roles for Roles.Role;
    using Action for Action.Object;

    enum Task {
        INIT_BY_CONTRACT,
        SUBMIT_ORIGINAL_BLOCK,
        SUBMIT_TARGET_BLOCK,
        SUBMIT_REFERENCE_DATA,
        SUBMIT_STORE_DATA,
        SUBMIT_DISPATCHES
    }

    MerkluxStoreForCase public store;
    IMerkluxReducerRegistry public registry;
    uint256 public currentActionNum;
    address public accuser;
    address public defendant;
    bytes32 public original;
    bytes32 public target;
    uint256 public deadline;
    bool public hasResult;
    bool public result;
    Block.Object private originalBlock;
    Block.Object private targetBlock;
    Roles.Role private attorneys;
    Chain.Object private chain;
    function(bytes32, bytes32, bool) external onResult;
    mapping(uint => bool) todos;
    mapping(uint256 => Action.Object) actions;

    event TaskDone(Task _task);
    event OnResult(bytes32 _original, bytes32 _target, bool _result);

    modifier hasPredecessor(Task _task) {
        require(todos[uint(_task)]);
        _;
    }

    modifier subTask(Task _task) {
        require(!todos[uint(_task)]);
        _;
    }

    modifier task(Task _task) {
        _;
        _done(_task);
    }

    /**
    * @dev Only the defendant can execute this function.
    * If the defendant appoint attorneys, then they are also allowed to call this function
    */
    modifier onlyDefendant() {
        require(msg.sender == defendant || attorneys.has(msg.sender));
        _;
    }

    constructor() public Secondary() {
    }

    function init(
        address _store,
        address _registry,
        uint256 _duration,
        bytes32 _original,
        bytes32 _target,
        address _defendant,
        function(bytes32, bytes32, bool) external _onResult
    )
    public
    onlyPrimary
    task(Task.INIT_BY_CONTRACT)
    {
        require(_store != address(0));
        require(_registry != address(0));
        store = MerkluxStoreForCase(_store);
        registry = IMerkluxReducerRegistry(_registry);
        deadline = _duration.add(now);
        original = _original;
        target = _target;
        defendant = _defendant;
        onResult = _onResult;
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

    function submitOriginalBlock(
        bytes32 _previousBlock,
        uint256 _actionNum,
        bytes32 _state,
        bytes32 _references,
        bytes32 _actions,
        address _sealer,
        bytes _signature
    )
    public
    onlyDefendant
    hasPredecessor(Task.INIT_BY_CONTRACT)
    task(Task.SUBMIT_ORIGINAL_BLOCK)
    {
        Block.Object memory _block = Block.Object(
            _previousBlock,
            _actionNum,
            _state,
            _references,
            _actions,
            _sealer,
            _signature
        );
        require(_block.getBlockHash() == original);
        require(_block.isSealed());
        originalBlock = _block;
        currentActionNum = _actionNum;
        store.setActionNum(_actionNum);
        store.initialize(_state);
        chain.addBlock(_block);
    }

    function submitTargetBlock(
        bytes32 _previousBlock,
        uint256 _actionNum,
        bytes32 _state,
        bytes32 _references,
        bytes32 _actions,
        address _sealer,
        bytes _signature
    )
    public
    onlyDefendant
    hasPredecessor(Task.SUBMIT_ORIGINAL_BLOCK)
    task(Task.SUBMIT_TARGET_BLOCK)
    {
        Block.Object memory _block = Block.Object(
            _previousBlock,
            _actionNum,
            _state,
            _references,
            _actions,
            _sealer,
            _signature
        );
        require(_block.getBlockHash() == target);
        require(_block.isSealed());
        targetBlock = _block;
    }

    function submitReference(bytes _key, bytes _value, uint _branchMask, bytes32[] _siblings)
    public
    onlyDefendant
    hasPredecessor(Task.SUBMIT_TARGET_BLOCK)
    subTask(Task.SUBMIT_REFERENCE_DATA)
    {
        store.commitBranch(_key, _value, _branchMask, _siblings);
        if (_key[0] == byte(38)) {
            // It is a reducer
            bytes32 reducerHash;
            for (uint i = 0; i < 32; i++) {
                reducerHash |= bytes32(_value[i] & 0xFF) >> (i * 8);
            }

            address deployedReducer = address(registry.getReducer(reducerHash));
            store.registerDeployedReducer(deployedReducer);
        }
        if (store.getReferenceRoot() == targetBlock.references) {
            _done(Task.SUBMIT_REFERENCE_DATA);
        }
    }

    function submitAction(
        bytes32 _prevBlock,
        address _from,
        uint256 _actionNum,
        uint256 _nonce,
        string _action,
        bool _deployReducer,
        bytes _data,
        bytes _signature
    ) public
    onlyDefendant
    hasPredecessor(Task.SUBMIT_REFERENCE_DATA)
    {
        Action.Object memory action = Action.Object(
            _prevBlock,
            _from,
            _actionNum,
            _nonce,
            _action,
            _deployReducer,
            _data,
            _signature
        );
        require(
            originalBlock.actionNum <= _actionNum &&
            _actionNum < targetBlock.actionNum
        );
        require(action.isSigned());
        actions[_actionNum] = action;
    }

    function runAction() public
    hasPredecessor(Task.SUBMIT_REFERENCE_DATA)
    {
        require(currentActionNum < targetBlock.actionNum);
        Action.Object storage actionObj = actions[currentActionNum];
        require(isSubmitted(currentActionNum));
        super.reduce(
            actionObj.action,
            actionObj.data,
            actionObj.base,
            actionObj.nonce,
            actionObj.deployReducer,
            actionObj.signature
        );
        currentActionNum = currentActionNum.add(1);
        if (currentActionNum == targetBlock.actionNum) {
            _complete();
        }
    }

    function isSubmitted(uint256 _actionNum) public view returns (bool) {
        return actions[_actionNum].signature.length != 0;
    }

    function close() public {
        if (now > deadline) {
            _complete();
        }
    }

    function _complete() private {
        bool stateCheck = store.getStateRoot() == targetBlock.state;
        bool actionCheck = store.getActionRoot() == targetBlock.actions;
        hasResult = true;
        result = stateCheck && actionCheck;
        onResult(original, target, result);
        emit OnResult(original, target, result);
    }

    function _done(Task _task) private {
        require(!todos[uint(_task)]);
        todos[uint(_task)] = true;
        emit TaskDone(_task);
    }

    function getChain() internal view returns (Chain.Object storage) {
        return chain;
    }

    function getStore() internal view returns (IMerkluxStoreForVM) {
        return store;
    }

    function getRegistry() internal view returns (IMerkluxReducerRegistry) {
        return registry;
    }
}
