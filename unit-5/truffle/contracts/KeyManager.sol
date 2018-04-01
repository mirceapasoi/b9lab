pragma solidity ^0.4.21;

import "./Pausable.sol";
import "./ERC725.sol";

contract KeyManager is Pausable, ERC725 {
    function _addKey(bytes32 _key, uint256 _purpose, uint256 _keyType) internal {
        allKeys.add(_key, _purpose, _keyType);
        emit KeyAdded(_key, _purpose, _keyType);
    }

    function addKey(bytes32 _key, uint256 _purpose, uint256 _keyType)
        public
        onlyManagementOrSelf
        whenNotPaused
        returns (bool success)
    {
        uint index;
        bool found;
        (index, found) = allKeys.find(_key, _purpose);
        if (found) {
            return false;
        }
        _addKey(_key, _purpose, _keyType);
        return true;
    }

    function removeKey(bytes32 _key, uint256 _purpose)
        public
        onlyManagementOrSelf
        whenNotPaused
        returns (bool success)
    {
        uint index;
        bool found;
        (index, found) = allKeys.find(_key, _purpose);
        if (found) {
            KeyArray.Key memory k = allKeys.remove(index);
            emit KeyRemoved(k.key, k.purpose, k.keyType);
        }
        return found;
    }
}