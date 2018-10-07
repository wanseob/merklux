pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Secondary.sol";
import "./MerkluxTree.sol";

contract MerkluxStore is Secondary {
    struct Namespace {
        string name;
        address[] allowedReducers;
        MerkluxTree tree;
    }

    Namespace[] public namespaces;

    function createNamespace(string _name) public {
        // If there already exists a same namespace, revert the transaction
        for (uint i = 0; i < namespaces.length; i++) {
            require(!_compareString(_name, namespaces[i].name));
        }
        namespaces.push(Namespace({
            name : _name,
            allowedReducers : new address[](0),
            tree : new MerkluxTree()
            }));
    }

    function deleteNamespace(string _name) public {
        var (exist, index) = _findNamespaceIndex(_name);
        if (exist) {
            for (uint i = index; i < namespaces.length; i++) {
                if (i + 1 < namespaces.length) {
                    namespaces[i] = namespaces[i + 1];
                }
            }
            delete namespaces[namespaces.length - 1];
            namespaces.length--;
        }
    }

    function allowReducer(string _namespace, address _reducer) public {
        var (exist, index) = _findNamespaceIndex(_namespace);
        if (exist) {
            for (uint i = 0; i < namespaces[index].allowedReducers.length; i++) {
                require(_reducer != namespaces[index].allowedReducers[i]);
            }
            namespaces[index].allowedReducers.push(_reducer);
        }
    }

    function denyReducer(string _namespace, address _reducer) public {
        var (exist, index) = _findNamespaceIndex(_namespace);
        if (exist) {
            uint reducerIndex = 0;
            for (uint i = 0; i < namespaces[index].allowedReducers.length; i++) {
                if (_reducer == namespaces[index].allowedReducers[i]) {
                    for (uint j = reducerIndex; j < namespaces[index].allowedReducers.length; j++) {
                        if (reducerIndex + 1 < namespaces[index].allowedReducers.length) {
                            namespaces[index].allowedReducers[reducerIndex] = namespaces[index].allowedReducers[reducerIndex + 1];
                        }
                    }
                    delete namespaces[index].allowedReducers[namespaces[index].allowedReducers.length - 1];
                    namespaces[index].allowedReducers.length--;
                }
            }
        }
    }

    function getAllowedReducers(string _namespace) view public returns (address[] memory reducers) {
        var (exist, index) = _findNamespaceIndex(_namespace);
        if (exist) {
            return namespaces[index].allowedReducers;
        }
    }

    function isAllowed(string _namespace, address _reducer) view public returns (bool){
        var (exist, index) = _findNamespaceIndex(_namespace);
        if (exist) {
            for (uint i = 0; i < namespaces[index].allowedReducers.length; i++) {
                if (_reducer == namespaces[index].allowedReducers[i]) {
                    return true;
                }
            }
        }
        return false;
    }

    function totalNamespace() view public returns (uint) {
        return namespaces.length;
    }

    function getNamespace(uint index) view public returns (string) {
        return namespaces[index].name;
    }

    function _findNamespaceIndex(string _name) view private returns (bool exist, uint index) {
        for (uint i = 0; i < namespaces.length; i++) {
            if (_compareString(_name, namespaces[i].name)) {
                index = i;
                exist = true;
                return;
            }
        }
        exist = false;
        return;
    }

    function _compareString(string a, string b) pure private returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
