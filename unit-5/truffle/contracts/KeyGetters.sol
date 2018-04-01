pragma solidity ^0.4.21;

import "./KeyBase.sol";

contract KeyGetters is KeyBase {
    function getKey(bytes32 _key, uint256 _purpose)
        public
        view
        returns(uint256 purpose, uint256 keyType, bytes32 key)
    {
        uint index;
        bool found;
        (index, found) = allKeys.find(_key, _purpose);
        if (found) {
            KeyArray.Key storage k = allKeys[index];
            purpose = k.purpose;
            keyType = k.keyType;
            key = k.key;
        }
    }

    function getKeyPurpose(bytes32 _key)
        public
        view
        returns(uint256[] purpose)
    {
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

    function getKeysByPurpose(uint256 _purpose)
        public
        view
        returns(bytes32[] keys)
    {
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

}