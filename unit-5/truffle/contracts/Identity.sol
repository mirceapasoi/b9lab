pragma solidity ^0.4.18;

import "./Destructible.sol";
import "./Pausable.sol";
import "./ERC735.sol";

contract Identity is Destructible, Pausable {
    Key[] allKeys;

    function Identity() public {
        _addKey(keccak256(msg.sender), MANAGEMENT_KEY, ECDSA);
    }

    function addressToKey(address addr) public pure returns (bytes32) {
        return keccak256(addr);
    }

    function addKey(bytes32 _key, uint256 _purpose, uint256 _keyType) public onlyManagementOrSelf whenNotPaused returns (bool success) {
        _addKey(_key, _purpose, _keyType);
        return true;
    }

    function removeKey(bytes32 _key, uint256 _purpose) public onlyManagementOrSelf whenNotPaused returns (bool success) {
        var (index, found) = _getKeyIndex(_key, _purpose);
        if (found) {
            Key memory k = allKeys[index];
            delete allKeys[index];
            KeyRemoved(k.key, k.purpose, k.keyType);
            // allKeys[index] = allKeys[allKeys.length - 1];
            // delete allKeys[allKeys.length - 1];
        }
        return found;
    }

    function getKey(bytes32 _key, uint256 _purpose) public view returns(uint256 purpose, uint256 keyType, bytes32 key) {
        var (index, found) = _getKeyIndex(_key, _purpose);
        if (found) {
            Key storage k = allKeys[index];
            purpose = k.purpose;
            keyType = k.keyType;
            key = k.key;
        }
    }

    function getKeyPurpose(bytes32 _key) public view returns(uint256[] purpose) {
        uint count = 0;
        for (uint i = 0; i < allKeys.length; i++) {
            if (allKeys[i].key == _key) {
                count++;
            }
        }
        purpose = new uint256[](count);
        for (count = i = 0; i < allKeys.length; i++) {
            if (allKeys[i].key == _key) {
                purpose[count++] = allKeys[i].purpose;
            }
        }
    }

    function getKeysByPurpose(uint256 _purpose) public view returns(bytes32[] keys) {
        uint count = 0;
        for (uint i = 0; i < allKeys.length; i++) {
            if (allKeys[i].purpose == _purpose) {
                count++;
            }
        }
        keys = new bytes32[](count);
        for (count = i = 0; i < allKeys.length; i++) {
            if (allKeys[i].purpose == _purpose) {
                keys[count++] = allKeys[i].key;
            }
        }
    }

    function execute(address _to, uint256 _value, bytes _data) public returns (uint256 executionId) {
        return 0;
    }

    function approve(uint256 _id, bool _approve) public returns (bool success) {
        return true;
    }
}