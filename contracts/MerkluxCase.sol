pragma solidity ^0.4.24;

import {PatriciaTree} from "../libs/chriseth/patricia-trie/patricia.sol";
import {D} from "../libs/chriseth/patricia-trie/data.sol";
import {Utils} from "../libs/chriseth/patricia-trie/utils.sol";
import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "./MerkluxTree.sol";


contract MerkluxCase is MerkluxTree {
    enum Status {OPENED, ONGOING, SUCCESS, FAILURE}

    event OnChangeStatus(Status s);

    modifier onlyFor(Status _status) {
        require(status == _status);
        _;
    }

    mapping(bytes32 => bool) committedValues;

    Status public status;
    D.Edge originalRootEdge;
    bytes32 originalRoot;
    D.Edge targetRootEdge;
    bytes32 targetRoot;

    constructor(
        uint _originalLabelLength,
        bytes32 _originalLabel,
        bytes32 _originalValue,
        uint _targetLabelLength,
        bytes32 _targetLabel,
        bytes32 _targetValue
    ) public MerkluxTree() {
        // Init original root edge
        originalRootEdge.label = D.Label(_originalLabel, _originalLabelLength);
        originalRootEdge.node = _originalValue;
        originalRoot = edgeHash(originalRootEdge);
        // Init target root edge
        targetRootEdge.label = D.Label(_targetLabel, _targetLabelLength);
        targetRootEdge.node = _targetValue;
        targetRoot = edgeHash(targetRootEdge);
        // Init status
        status = Status.OPENED;
    }

    function insert(bytes key, bytes value) public onlyFor(Status.ONGOING) onlyPrimary {
        bytes32 k = keccak256(value);
        committedValues[k] = true;
        super.insert(key, value);
    }

    function commitNode(
        bytes32 nodeHash,
        uint firstEdgeLabelLength,
        bytes32 firstEdgeLabel,
        bytes32 firstEdgeValue,
        uint secondEdgeLabelLength,
        bytes32 secondEdgeLabel,
        bytes32 secondEdgeValue
    ) public onlyFor(Status.OPENED) onlyPrimary {
        D.Label memory k0 = D.Label(firstEdgeLabel, firstEdgeLabelLength);
        D.Edge memory e0 = D.Edge(firstEdgeValue, k0);
        D.Label memory k1 = D.Label(secondEdgeLabel, secondEdgeLabelLength);
        D.Edge memory e1 = D.Edge(secondEdgeValue, k1);
        require(nodes[nodeHash].children[0].node == 0);
        require(nodes[nodeHash].children[1].node == 0);
        require(nodeHash == keccak256(edgeHash(e0), edgeHash(e1)));
        nodes[nodeHash].children[0] = e0;
        nodes[nodeHash].children[1] = e1;
    }

    function commitValue(bytes value) public onlyFor(Status.OPENED) onlyPrimary {
        bytes32 k = keccak256(value);
        committedValues[k] = true;
        values[k] = value;
    }

    function seal() public onlyFor(Status.OPENED) onlyPrimary {
        require(_verifyEdge(originalRootEdge));
        rootEdge = originalRootEdge;
        root = edgeHash(rootEdge);
        _changeStatus(Status.ONGOING);
    }

    function proof() public onlyFor(Status.ONGOING) onlyPrimary {
        require(targetRootEdge.node == rootEdge.node);
        require(targetRootEdge.label.length == rootEdge.label.length);
        require(targetRootEdge.label.data == rootEdge.label.data);
        require(_verifyEdge(rootEdge));
        _changeStatus(Status.SUCCESS);
    }

    function _verifyEdge(D.Edge memory _edge) internal view returns (bool) {
        if (_edge.node == 0) {
            // Empty. Return true because there is nothing to verify
            return true;
        } else if (_isLeaf(_edge)) {
            // check stored value of the leaf node
            require(_hasValue(_edge.node));
        } else {
            D.Edge[2] memory children = nodes[_edge.node].children;
            // its node value should be the hashed value of its child nodes
            require(_edge.node == keccak256(edgeHash(children[0]), edgeHash(children[1])));
            // check children recursively
            require(_verifyEdge(children[0]));
            require(_verifyEdge(children[1]));
        }
        return true;
    }

    function _isLeaf(D.Edge _edge) internal view returns (bool) {
        return (nodes[_edge.node].children[0].node == 0 && nodes[_edge.node].children[1].node == 0);
    }

    function _hasValue(bytes32 valHash) internal view returns (bool) {
        return committedValues[valHash];
    }

    function _changeStatus(Status _status) internal {
        require(status < _status);
        // unidirectional
        status = _status;
        emit OnChangeStatus(status);
    }
}
