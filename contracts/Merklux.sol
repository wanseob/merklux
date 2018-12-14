pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "solidity-rlp/contracts/RLPReader.sol";
import "./MerkluxStore.sol";
import "./MerkluxReducer.sol";
import "./MerkluxReducerRegistry.sol";
import {Block, Transition} from "./Types.sol";


/**
 * @title Merklux
 * @dev Merklux is a state management smart contract to control the state with a
 * unidirectional data flow. It can be used for state verifications accross evm
 * based block chains.
 */
contract Merklux is Secondary, MerkluxReducerRegistry{

    using Block for Block.Object;
    using Block for Block.Data;
    using Transition for Transition.Object;
    using SafeMath for uint256;
    using ECDSA for bytes32;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    // Every action dispatches increment the height
    uint256 public height;
    mapping(bytes32 => MerkluxReducer) private reducers;
    MerkluxStore private store;


    bytes32[] chain;
    mapping(bytes32 => Block.Object) blocks;
    mapping(uint256 => Block.Data) blockData;

    event Dispatched(uint _height, bytes32 _transactionDataHash);
    event Sealed(bytes32 _blockHash, bytes _signature);

    constructor () public Secondary() {
        // Set null value as the genesis block
        chain.push(bytes32(0));
        store = new MerkluxStore();
    }

    /**
    * @dev This is the only way to updates the merkle trees
    *
    * @param _action The name of the action
    * @param _data RLP encoded data set
    */
    function dispatch(string _action, bytes _data) external {
        bytes32 reducerKey = store.getReducerKey(_action);
        MerkluxReducer reducer = getReducer(reducerKey);

        bytes memory rlpEncodedKeys;
        bytes memory rlpEncodedValues;
        bytes32[] memory referredKeys;
        (rlpEncodedKeys, rlpEncodedValues, referredKeys) = reducer.reduce(store, msg.sender, _data);

        RLPReader.RLPItem[] memory keys = rlpEncodedKeys.toRlpItem().toList();
        RLPReader.RLPItem[] memory values = rlpEncodedValues.toRlpItem().toList();
        require(keys.length == values.length);

        // Record references
        bytes32[] memory references = new bytes32[](1 + keys.length + referredKeys.length);
        // record reducer key
        references[0] = reducerKey;
        // record inserted keys
        for (uint i = 0; i < keys.length; i++) {
            store.insert(keys[i].toBytes(), values[i].toBytes());
            references[1 + i] = keccak256(keys[i].toBytes());
        }
        // record referred keys
        for (i = 0; i < referredKeys.length; i++) {
            references[1 + keys.length + i] = referredKeys[i];
        }

        _recordReferences(references);

        // update candidate
        _recordStore(store.getRootHash());

        // record transition
        _recordTransition(
            Transition.Type.DISPATCH,
            height,
            _action,
            _data
        );
    }

    // TODO set modifier to allow only the pseudo-randomly selected snapshot submitter
    function seal(bytes _signature) external {
        Block.Object memory candidate = _getBlockCandidate(msg.sender);
        candidate.signature = _signature;
        // Check signature
        require(candidate.isSealed());
        bytes32 blockHash = candidate.getBlockHash();
        chain.push(blockHash);
        blocks[blockHash] = candidate;
    }

    /**
     * @dev It allows to update reducer by overwriting
     *
     * @param _action Name of the action for the reducer to handle
     * @param _code Compiled reducer code to deploy
     */
    function setReducer(string _action, bytes _code) public onlyPrimary {// TODO committee
        require(bytes(_action).length != 0);
        // Register reducer
        bytes32 reducerKey = registerReducer(_code);
        // Add the action into the actions list
        if (store.getReducerKey(_action) == bytes32(0)) {
            store.setReducer(_action, reducerKey);
        }

        // Record transition
        _recordTransition(
            Transition.Type.SET_REDUCER,
            height,
            _action,
            _code
        );
    }

    function get(bytes _key) public view returns (bytes) {
        return store.get(_key);
    }

    function getBlockHashToSeal() public view returns (bytes32) {
        return _getBlockCandidate(msg.sender).getBlockHash();
    }

    function _getBlockCandidate(address _sealer) private view returns (Block.Object memory candidate) {
        Block.Data storage data = _getCurrentBlockData();
        candidate.height = height;
        candidate.previousBlock = chain[chain.length - 1];
        candidate.store = data.getStoreRoot();
        candidate.references = data.getReferenceRoot();
        candidate.transitions = data.getTransitionRoot();
        candidate.sealer = _sealer;
        return candidate;
    }

    function _getCurrentBlockData() private view returns (Block.Data storage) {
        return blockData[chain.length];
    }

    function _recordReferences(bytes32[] memory _keys) private {
        Block.Data storage data = _getCurrentBlockData();
        bytes32[] storage keys = data.references;

        for (uint i = 0; i < _keys.length; i ++) {
            bool exist = false;
            for (uint j = 0; j < keys.length; j++) {
                if (keys[j] == _keys[i]) {
                    exist = true;
                    break;
                }
            }
            if (!exist) keys.push(_keys[i]);
        }
    }

    function _recordStore(bytes32 _hash) private {
        Block.Data storage data = _getCurrentBlockData();
        data.storeHash = _hash;
    }

    function _recordTransition(
        Transition.Type _sort,
        uint256 _height,
        string _action,
        bytes _data
    ) private {
        // TODO require(stake > estimated defence cost);
        Transition.Object memory transition = Transition.Object(
            msg.sender,
            _sort,
            _height,
            _action,
            _data
        );
        Block.Data storage data = _getCurrentBlockData();
        data.transitions.push(transition);
        emit Dispatched(height, transition.getTransitionHash());
        height = height.add(1);
    }
}
