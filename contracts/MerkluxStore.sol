pragma solidity ^0.4.24;

import {PatriciaTree} from "solidity-patricia-tree/contracts/tree.sol";
import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "openzeppelin-solidity/contracts/access/Roles.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "solidity-rlp/contracts/RLPReader.sol";
import "./interfaces/IStateTree.sol";
import "./interfaces/IMerkluxReducerRegistry.sol";
import "./interfaces/IMerkluxStoreForVM.sol";
import {Action} from "./Types.sol";

/**
 * @title MerkluxTree data structure for
 *
 */
contract MerkluxStore is Secondary, IMerkluxStoreForVM, IStateTree {
    using SafeMath for uint256;
    using PatriciaTree for PatriciaTree.Tree;
    using Roles for Roles.Role;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    using Action for Action.Object;
    bytes constant EXIST = "1";

    uint256 private actionNum;
    Roles.Role private reducers;
    PatriciaTree.Tree private stateTree;
    PatriciaTree.Tree private referenceTree;
    PatriciaTree.Tree private actionTree;
    address[] private callers;
    mapping(address => uint256) private nonce;
    bytes[] public references;
    Action.Object[] public actions;

    modifier onlyReducers() {
        require(msg.sender == primary() || reducers.has(msg.sender));
        _;
    }

    constructor() public Secondary() {
    }


    function deployReducer(IMerkluxReducerRegistry _registry, string _action, bytes _data) public onlyPrimary {
        bytes32 reducerKey;
        address deployedAddress;
        (reducerKey, deployedAddress) = _registry.registerReducer(_data);
        require(bytes(_action).length != 0);
        bytes memory actionKey = _appendPrefix(_action);
        _updateState(actionKey, abi.encodePacked(reducerKey), true);
        reducers.add(deployedAddress);
    }

    function runReducer(IMerkluxReducerRegistry _registry, address _sender, string _action, bytes _data) public onlyPrimary {
        MerkluxReducer reducer = _retrieveReducer(_registry, _action);
        // Not a registered reducer
        require(address(reducer) != address(0));

        bytes memory rlpEncodedPairs;

        // Get pairs to update from reducer
        rlpEncodedPairs = reducer.reduce(this, _sender, _data);
        RLPReader.RLPItem[] memory pairs = rlpEncodedPairs.toRlpItem().toList();
        // length should be an even number
        // Reducer should returns rlp encoded list which length is an even number
        require(pairs.length & 1 == 0);

        // Update key value pairs
        for (uint i = 0; i < (pairs.length / 2); i++) {
            _updateState(pairs[i * 2].toBytes(), pairs[i * 2 + 1].toBytes(), false);
        }
    }

    function increaseAccountActionNonce(address _user, uint256 _nonce) public onlyPrimary {
        require(nonce[_user] < _nonce);
        if (nonce[_user] == 0) {
            callers.push(_user);
        }
        nonce[_user] = _nonce;
    }

    function putAction(
        bytes32 _prevBlockHash,
        address _from,
        uint256 _nonce,
        string _action,
        bool _deployReducer,
        bytes _data,
        bytes _signature
    ) public onlyPrimary returns (bytes32 _actionHash) {
        Action.Object memory action = Action.Object(
            _prevBlockHash,
            _from,
            actionNum,
            _nonce,
            _action,
            _deployReducer,
            _data,
            _signature
        );
        actions.push(action);
        bytes32 actionHash = action.getActionHash();
        actionTree.insert(abi.encodePacked(actionHash), EXIST);
        actionNum = actionNum.add(1);
        return actionHash;
    }

    function resetCurrentData() public onlyPrimary {
        _resetReferenceData();
        _resetActionData();
        _resetNonce();
    }

    function read(bytes key) public onlyReducers returns (bytes) {
        return _get(key);
    }

    function getActionNum() public view returns (uint256) {
        return actionNum;
    }

    function getStateRoot() public view returns (bytes32) {
        return stateTree.getRootHash();
    }

    function getReferenceRoot() public view returns (bytes32) {
        return referenceTree.getRootHash();
    }

    function getActionRoot() public view returns (bytes32) {
        return actionTree.getRootHash();
    }

    function get(bytes _key) public view returns (bytes) {
        return stateTree.get(_key);
    }

    function getProof(bytes _key) public view returns (bytes _value, uint _branchMask, bytes32[] _siblings) {
        (_branchMask, _siblings) = stateTree.getProof(_key);
        _value = stateTree.get(_key);
    }

    function getActionProof(bytes32 actionHash) public view returns (uint _branchMask, bytes32[] _siblings) {
        return actionTree.getProof(abi.encodePacked(actionHash));
    }

    function getAccountActionNonce(address _sender) public view returns (uint256) {
        return nonce[_sender];
    }

    function _resetReferenceData() private {
        delete referenceTree;
        delete references;
    }

    function _resetActionData() private {
        delete actions;
        delete actionTree;
    }

    function _resetNonce() private {
        for (uint i = 0; i < callers.length; i++) {
            delete nonce[callers[i]];
        }
        delete callers;
    }

    function _retrieveReducer(IMerkluxReducerRegistry _registry, string _action) private returns (MerkluxReducer reducer) {
        bytes32 reducerHash;
        bytes memory actionKey = _appendPrefix(_action);
        bytes memory storedValue = _get(actionKey);

        if (storedValue.length == 32) {
            for (uint i = 0; i < 32; i++) {
                reducerHash |= bytes32(storedValue[i] & 0xFF) >> (i * 8);
            }
        }
        reducer = _registry.getReducer(reducerHash);
    }

    function _updateState(bytes _key, bytes _value, bool _isReducer) private {
        if (!_isReducer && _key.length > 1) {
            // Reducer cannot be overwritten through this function
            require(!(_key[0] == byte(0) && _key[1] == byte(38)));
        }
        _set(_key, _value);
    }

    function _get(bytes memory _key) private returns (bytes){
        _refer(_key);
        return stateTree.get(_key);
    }

    function _set(bytes memory _key, bytes memory _value) private {
        _refer(_key);
        stateTree.insert(_key, _value);
    }

    function _refer(bytes memory _key) private {
        if (referenceTree.get(_key).length == 0) {
            references.push(_key);
            referenceTree.insert(_key, EXIST);
        }
    }

    /**
     * @dev
     * @return _reducerKey always starts with 0x0026
     */
    function _appendPrefix(string _action) private pure returns (bytes memory _actionKey) {
        // add '&' as a prefix
        bytes memory _a = bytes(_action);
        _actionKey = new bytes(_a.length + 1);
        _actionKey[0] = "&";
        for (uint i = 1; i < _actionKey.length; i++) _actionKey[i] = _a[i - 1];
    }
}
