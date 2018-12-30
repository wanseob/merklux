pragma solidity ^0.4.24;

import {PatriciaTree} from "solidity-patricia-tree/contracts/tree.sol";
import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "openzeppelin-solidity/contracts/access/Roles.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "solidity-rlp/contracts/RLPReader.sol";
import "../libs/bakaoh/solidity-rlp-encode/contracts/RLPEncode.sol";
import "./interfaces/IMerkluxStore.sol";
import "./interfaces/IMerkluxReducerRegistry.sol";
import {Transition} from "./Types.sol";


/**
 * @title MerkluxTree data structure for
 *
 */
contract MerkluxStore is Secondary, IMerkluxStore {
    using SafeMath for uint256;
    using PatriciaTree for PatriciaTree.Tree;
    using Roles for Roles.Role;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;
    using RLPEncode for bytes[];
    using Transition for Transition.Object;
    bytes constant EXIST = "1";

    PatriciaTree.Tree stateTree;
    PatriciaTree.Tree referenceTree;
    PatriciaTree.Tree transitionTree;
    Roles.Role private reducers;
    uint256 txNum;
    bytes[] references;
    Transition.Object[] transitions;
    address[] callers;
    mapping(address => uint256) nonce;


    event Dispatched(uint _txNum, bytes32 _transactionDataHash);

    modifier onlyReducers() {
        require(msg.sender == primary() || reducers.has(msg.sender));
        _;
    }

    constructor() public Secondary() {
    }

    function read(bytes key) public onlyReducers returns (bytes) {
        _refer(key);
        return stateTree.get(key);
    }

    function deployReducer(IMerkluxReducerRegistry _registry, string _action, bytes _data) public onlyPrimary {
        bytes32 reducerKey;
        address deployedAddress;
        (reducerKey, deployedAddress) = _registry.registerReducer(_data);
        require(bytes(_action).length != 0);
        bytes memory actionKey = _appendPrefix(_action);
        _updateState(actionKey, abi.encodePacked(reducerKey), true);
        _refer(actionKey);
        reducers.add(deployedAddress);
    }

    function runReducer(IMerkluxReducerRegistry _registry, address _sender, string _action, bytes _data) public onlyReducers {
        MerkluxReducer reducer = _retrieveReducer(_registry, _action);
        bytes memory rlpEncodedPairs;

        // Get pairs to update from reducer
        rlpEncodedPairs = reducer.reduce(this, _sender, _data);
        RLPReader.RLPItem[] memory pairs = rlpEncodedPairs.toRlpItem().toList();
        // length should be an even number
        require(pairs.length & 1 == 0);

        // Update key value pairs
        for (uint i = 0; i < (pairs.length / 2); i++) {
            _updateState(pairs[i * 2].toBytes(), pairs[i * 2 + 1].toBytes(), false);
        }
    }

    function increaseAccountTxNonce(address _user, uint256 _nonce) public onlyPrimary {
        require(nonce[_user] < _nonce);
        if (nonce[_user] == 0) {
            callers.push(_user);
        }
        nonce[_user] = _nonce;
    }

    function putTransition(
        bytes32 _prevBlockHash,
        address _from,
        uint256 _nonce,
        string _action,
        bytes _data
    ) public onlyPrimary {
        Transition.Object memory transition = Transition.Object(
            _prevBlockHash,
            _from,
            txNum,
            _nonce,
            _action,
            _data
        );
        transitions.push(transition);
        bytes32 transitionHash = transition.getTransitionHash();
        transitionTree.insert(abi.encodePacked(transitionHash), EXIST);
        emit Dispatched(txNum, transitionHash);
        txNum = txNum.add(1);
    }

    function resetCurrentData() public onlyPrimary {
        _resetReferenceData();
        _resetTransitionData();
        _resetNonce();
    }

    function _resetReferenceData() public onlyPrimary {
        delete referenceTree;
        delete references;
    }

    function _resetTransitionData() private {
        delete transitions;
        delete transitionTree;
    }

    function _resetNonce() private {
        for (uint i = 0; i < callers.length; i++) {
            delete nonce[callers[i]];
        }
        delete callers;
    }

    function getTxNum() public view returns (uint256) {
        return txNum;
    }

    function getStateRoot() public view returns (bytes32) {
        stateTree.getRootHash();
    }

    function getReferenceRoot() public view returns (bytes32) {
        referenceTree.getRootHash();
    }

    function getTransitionRoot() public view returns (bytes32) {
        transitionTree.getRootHash();
    }

    function getReducerKey(string _action) public view returns (bytes32) {
        bytes32 reducerHash;
        bytes memory actionKey = _appendPrefix(_action);
        bytes memory storedValue = stateTree.get(actionKey);

        if (storedValue.length == 32) {
            for (uint i = 0; i < 32; i++) {
                reducerHash |= bytes32(storedValue[i] & 0xFF) >> (i * 8);
            }
            return reducerHash;
        } else {
            return bytes32(0);
        }
    }

    function get(bytes key) public view onlyPrimary returns (bytes) {
        return stateTree.get(key);
    }

    function getLeafValue(bytes32 valueHash) public view onlyPrimary returns (bytes) {
        return stateTree.getValue(valueHash);
    }

    function getRootHash() public view returns (bytes32) {
        return stateTree.getRootHash();
    }

    function getAccountTxNonce(address _sender) public view returns (uint256) {
        return nonce[_sender];
    }

    function _retrieveReducer(IMerkluxReducerRegistry _registry, string _action) private returns (MerkluxReducer reducer) {
        bytes32 reducerHash;
        bytes memory actionKey = _appendPrefix(_action);
        bytes memory storedValue = read(actionKey);

        if (storedValue.length == 32) {
            for (uint i = 0; i < 32; i++) {
                reducerHash |= bytes32(storedValue[i] & 0xFF) >> (i * 8);
            }
        }
        reducer = _registry.getReducer(reducerHash);
    }

    function _updateState(bytes key, bytes value, bool isReducer) private {
        if (!isReducer && key.length > 1) {
            // Reducer cannot be overwritten through this function
            require(!(key[0] == byte(0) && key[1] == byte(38)));
        }
        stateTree.insert(key, value);
        _refer(key);
    }

    function _refer(bytes memory key) private {
        referenceTree.insert(key, EXIST);
        references.push(key);
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
