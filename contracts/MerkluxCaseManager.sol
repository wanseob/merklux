pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "./MerkluxVM.sol";
import "./MerkluxCase.sol";
import "./MerkluxStoreForCase.sol";
import "./MerkluxReducerRegistry.sol";


/**
 * @title Merklux
 * @dev Merklux is a state management smart contract to control the state with a
 * unidirectional data flow. It can be used for state verifications accross evm
 * based block merkluxCases.
 */
contract MerkluxCaseManager is Secondary, MerkluxReducerRegistry {
    struct Case {
        address accuser;
        address defendant;
        address merkluxCase;
        address store;
        bytes32 original;
        bytes32 target;
        uint256 duration;
        bool closed;
        bool result;
    }

    string public version;
    bytes32 public merkluxCaseCode;
    bytes32 public storeCode;
    mapping(bytes32 => Case) public cases;

    modifier onlyAccuser(bytes32 _caseHash) {
        require(cases[_caseHash].accuser == msg.sender);
        _;
    }

    constructor (string _version, bytes32 _merkluxCaseCode, bytes32 _storeCode) public Secondary() {
        version = _version;
        merkluxCaseCode = _merkluxCaseCode;
        storeCode = _storeCode;
    }

    function createCase(
        bytes32 _original,
        bytes32 _target,
        address _defendant,
        uint256 _duration
    ) public {
        require(cases[_target].accuser == address(0));
        cases[_target].accuser = msg.sender;
        cases[_target].original = _original;
        cases[_target].target = _target;
        cases[_target].defendant = _defendant;
        cases[_target].duration = _duration;
    }

    function deployCase(bytes32 _target, bytes _bytecode) public onlyAccuser(_target) {
        // Should not be deployed before
        require(cases[_target].merkluxCase == address(0));
        // hash value of the bytecode to deploy should be same with the configuration
        require(merkluxCaseCode == keccak256(_bytecode));
        // deploy and save address
        cases[_target].merkluxCase = _deployContractWithByteCode(_bytecode);
    }

    function deployStore(bytes32 _caseHash, bytes _bytecode) public onlyAccuser(_caseHash) {
        // Should not be deployed before
        require(cases[_caseHash].store == address(0));
        // hash value of the bytecode to deploy should be same with the configuration
        require(storeCode == keccak256(_bytecode));
        // deploy and save address
        cases[_caseHash].store = _deployContractWithByteCode(_bytecode);
    }

    function openCase(bytes32 _target) public onlyAccuser(_target) {
        // Both contract should be deployed first
        address merkluxCase = cases[_target].merkluxCase;
        address store = cases[_target].store;
        require(merkluxCase != address(0));
        require(store != address(0));
        MerkluxStoreForCase(store).transferPrimary(merkluxCase);
        MerkluxCase(merkluxCase).init(
            store,
            address(this),
            cases[_target].duration,
            cases[_target].original,
            cases[_target].target,
            cases[_target].defendant,
            this.updateResult
        );
        MerkluxCase(merkluxCase).transferPrimary(msg.sender);
    }

    function updateResult(bytes32 _original, bytes32 _target, bool _result) external {
        require(cases[_target].merkluxCase == msg.sender);
        require(cases[_target].original == _original);
        cases[_target].closed = true;
        cases[_target].result = _result;
    }

    function getMerkluxCase(bytes32 _caseHash) public view returns (address merkluxCase, address store) {
        merkluxCase = cases[_caseHash].merkluxCase;
        store = cases[_caseHash].store;
        require(merkluxCase != address(0));
        require(store != address(0));
    }

    function _deployContractWithByteCode(bytes _bytecode) private returns (address _deployed) {
        // Deploy
        assembly {
            _deployed := create(0, add(_bytecode, 0x20), mload(_bytecode))
        }
    }

}
