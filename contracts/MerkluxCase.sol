pragma solidity ^0.4.24;


import {PatriciaTree} from "solidity-patricia-tree/contracts/tree.sol";
import {D} from "solidity-patricia-tree/contracts/data.sol";
import "solidity-rlp/contracts/RLPReader.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/access/Roles.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "./MerkluxStore.sol";
import "./MerkluxReducer.sol";


contract MerkluxCase is MerkluxStore {
    using Roles for Roles.Role;
    using ECDSA for bytes32;
    using SafeMath for uint256;
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for bytes;

    enum Status {OPENED, ONGOING, SUCCESS, FAILURE}

    event OnChangeStatus(Status s);

    /**
    * @dev Only the defendant can execute this function
    */
    modifier onlyDefendant() {
        require(msg.sender == defendant);
        _;
    }

    /**
    * @dev The defendant can appoint attorneys and they are allowed to call this function
    */
    modifier onlyAttorneys() {
        require(attorneys.has(msg.sender));
        _;
    }

    /**
    * @dev This function is executable when only it has the designated status
    */
    modifier onlyFor(Status _status) {
        require(status == _status);
        _;
    }

    struct TransactionEvidence {
        uint256 height;
        address reducer;
        address from;
        bytes data; // rlp encoded params
    }

    Status public status;
    address public defendant;
    address public merklux;
    Roles.Role private attorneys;
    D.Edge originalRootEdge;
    bytes32 originalRoot;
    D.Edge targetRootEdge;
    bytes32 targetRoot;
    bytes32 transactionHash;
    uint256 public startHeight;
    uint256 public finalHeight;
    uint256 public currentHeight;
    mapping(bytes32 => bool) committedValues;
    mapping(uint256 => TransactionEvidence) committedTransactions;
    bytes32[] transactions;

    constructor(
        address _defendant,
        bytes32 _originalRootHash,
        bytes32 _targetRootHash,
        bytes32 _transactionHash,
        uint256 _startHeight,
        uint256 _finalHeight
    ) public MerkluxStore() {
        // Init status
        merklux = msg.sender;
        status = Status.OPENED;
        defendant = _defendant;
        attorneys.add(_defendant);
        originalRoot = _originalRootHash;
        targetRoot = _targetRootHash;
        transactionHash = _transactionHash;
        startHeight = _startHeight;
        currentHeight = _startHeight;
        finalHeight = _finalHeight;
    }

    function appoint(address _attorney) public onlyDefendant {
        attorneys.add(_attorney);
    }

    function cancel(address _attorney) public onlyDefendant {
        attorneys.remove(_attorney);
    }

    function commitOriginalRootEdge(
        uint _originalLabelLength,
        bytes32 _originalLabel,
        bytes32 _originalValue
    ) public onlyFor(Status.OPENED) onlyAttorneys() {
        // Init original root edge
        originalRootEdge.label = D.Label(_originalLabel, _originalLabelLength);
        originalRootEdge.node = _originalValue;
        require(originalRoot == PatriciaTree.edgeHash(originalRootEdge));
    }

    function commitNode(
        bytes32 nodeHash,
        uint firstEdgeLabelLength,
        bytes32 firstEdgeLabel,
        bytes32 firstEdgeValue,
        uint secondEdgeLabelLength,
        bytes32 secondEdgeLabel,
        bytes32 secondEdgeValue
    ) public onlyFor(Status.OPENED) onlyAttorneys {
        D.Label memory k0 = D.Label(firstEdgeLabel, firstEdgeLabelLength);
        D.Edge memory e0 = D.Edge(firstEdgeValue, k0);
        D.Label memory k1 = D.Label(secondEdgeLabel, secondEdgeLabelLength);
        D.Edge memory e1 = D.Edge(secondEdgeValue, k1);
        require(tree.nodes[nodeHash].children[0].node == 0);
        require(tree.nodes[nodeHash].children[1].node == 0);
        require(nodeHash == keccak256(abi.encodePacked(PatriciaTree.edgeHash(e0), PatriciaTree.edgeHash(e1))));
        tree.nodes[nodeHash].children[0] = e0;
        tree.nodes[nodeHash].children[1] = e1;
    }

    function commitValue(bytes value) public onlyFor(Status.OPENED) onlyAttorneys {
        bytes32 k = keccak256(value);
        committedValues[k] = true;
        tree.values[k] = value;
    }

    function seal() public onlyFor(Status.OPENED) onlyAttorneys {
        require(_verifyEdge(originalRootEdge));
        tree.rootEdge = originalRootEdge;
        tree.root = PatriciaTree.edgeHash(tree.rootEdge);
        _changeStatus(Status.ONGOING);
    }

    function commitTransaction(
        uint256 _height, // height of the merklux child
        uint256 _nonce,
        uint256 _gasPrice,
        uint256 _gas,
        address _to, // target reducer
        uint256 _value, // value
        bytes _data, // data
        bytes _signature
    ) public onlyFor(Status.ONGOING) onlyAttorneys {
        require(_height == currentHeight && _height <= finalHeight);

        // Recover message sender
        address _from = keccak256(abi.encodePacked(
                _nonce,
                _gasPrice,
                _gas,
                _to,
                _value,
                _data
            ))
        .toEthSignedMessageHash()
        .recover(_signature);
        // Store transaction evidence

        _reenact(_to, _from, _data);

        transactions.push(keccak256(abi.encodePacked(_height, _to, _from, _data)));
        currentHeight.add(1);
    }

    function _reenact(address _to, address _from, bytes _data) private {
        bytes memory rlpEncodedKeys;
        bytes memory rlpEncodedValues;
        bytes32[] memory referredKeys;
        (rlpEncodedKeys, rlpEncodedValues, referredKeys) = MerkluxReducer(_to).reduce(this, _from, _data);

        RLPReader.RLPItem[] memory keys = rlpEncodedKeys.toRlpItem().toList();
        RLPReader.RLPItem[] memory values = rlpEncodedValues.toRlpItem().toList();
        require(keys.length == values.length);
        for (uint i = 0; i < keys.length; i ++) {
            insert(keys[i].toBytes(), values[i].toBytes());
        }
    }

    function proof() public onlyFor(Status.ONGOING) onlyAttorneys {
        require(_verifyTransactions(transactions));
        require(keccak256(abi.encodePacked(transactions)) == transactionHash);
        require(targetRoot == PatriciaTree.edgeHash(tree.rootEdge));
        require(_verifyEdge(tree.rootEdge));
        _changeStatus(Status.SUCCESS);
    }

    function _insert(bytes key, bytes value) private onlyFor(Status.ONGOING) {
        bytes32 k = keccak256(value);
        committedValues[k] = true;
        super.insert(key, value);
    }

    function _verifyTransactions(bytes32[] memory _transactions) private view returns (bool) {
        return keccak256(abi.encodePacked(_transactions)) == transactionHash;
    }

    function _verifyEdge(D.Edge memory _edge) private view returns (bool) {
        if (_edge.node == 0) {
            // Empty. Return true because there is nothing to verify
            return true;
        } else if (_isLeaf(_edge)) {
            // check stored value of the leaf node
            require(_hasValue(_edge.node));
        } else {
            D.Edge[2] memory children = tree.nodes[_edge.node].children;
            // its node value should be the hashed value of its child nodes
            require(_edge.node == keccak256(abi.encodePacked(PatriciaTree
                .edgeHash(children[0]),
                PatriciaTree.edgeHash(children[1]))
            ));
            // check children recursively
            require(_verifyEdge(children[0]));
            require(_verifyEdge(children[1]));
        }
        return true;
    }

    function _isLeaf(D.Edge _edge) private view returns (bool) {
        return (tree.nodes[_edge.node].children[0].node == 0 && tree.nodes[_edge.node].children[1].node == 0);
    }

    function _hasValue(bytes32 valHash) private view returns (bool) {
        return committedValues[valHash];
    }

    function _changeStatus(Status _status) private {
        require(status < _status);
        // unidirectional
        status = _status;
        emit OnChangeStatus(status);
    }
}
