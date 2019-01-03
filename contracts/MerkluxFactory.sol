pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "./MerkluxVM.sol";
import "./MerkluxStore.sol";
import "./MerkluxReducerRegistry.sol";
import "./MerkluxChain.sol";


/**
 * @title Merklux
 * @dev Merklux is a state management smart contract to control the state with a
 * unidirectional data flow. It can be used for state verifications accross evm
 * based block chains.
 */
contract MerkluxFactory is Secondary, MerkluxReducerRegistry {
    struct Merklux {
        address primary;
        address chain;
        address store;
    }

    string public version;
    bytes32 public chainCode;
    bytes32 public storeCode;
    mapping(string => Merklux) applications;

    modifier onlyAppOwner(string _appName) {
        require(applications[_appName].primary == msg.sender);
        _;
    }

    constructor (string _version, bytes32 _chainCode, bytes32 _storeCode) public Secondary() {
        version = _version;
        chainCode = _chainCode;
        storeCode = _storeCode;
    }

    function createApp(string _appName) public {
        require(applications[_appName].primary == address(0));
        applications[_appName].primary = msg.sender;
    }

    function deployChain(string _appName, bytes _bytecode) public onlyAppOwner(_appName) {
        // Should not be deployed before
        require(applications[_appName].chain == address(0));
        // hash value of the bytecode to deploy should be same with the configuration
        require(chainCode == keccak256(_bytecode));
        // deploy and save address
        applications[_appName].chain = _deployContractWithByteCode(_bytecode);
    }

    function deployStore(string _appName, bytes _bytecode) public onlyAppOwner(_appName) {
        // Should not be deployed before
        require(applications[_appName].store == address(0));
        // hash value of the bytecode to deploy should be same with the configuration
        require(storeCode == keccak256(_bytecode));
        // deploy and save address
        applications[_appName].store = _deployContractWithByteCode(_bytecode);
    }

    function complete(string _appName) public onlyAppOwner(_appName) {
        // Both contract should be deployed first
        address chain = applications[_appName].chain;
        address store = applications[_appName].store;
        require(chain != address(0));
        require(store != address(0));
        MerkluxStore(store).transferPrimary(chain);
        MerkluxChain(chain).initStore(store);
        MerkluxChain(chain).initRegistry(address(this));
        MerkluxChain(chain).transferPrimary(msg.sender);
    }

    function getMerklux(string _appName) public view returns (address chain, address store) {
        chain = applications[_appName].chain;
        store = applications[_appName].store;
        require(chain != address(0));
        require(store != address(0));
    }

    function _deployContractWithByteCode(bytes _bytecode) private returns (address _deployed) {
        // Deploy
        assembly {
            _deployed := create(0, add(_bytecode, 0x20), mload(_bytecode))
        }
    }
}
