pragma solidity ^0.4.18;

import "./ERC725.sol";

contract ManagementKeys is ERC725 {
    Key[] allKeys;

    function _getKeyIndex(bytes32 _key, uint256 _purpose) internal view returns (uint, bool) {
        for (uint i = 0; i < allKeys.length; i++) {
            if (allKeys[i].key == _key && allKeys[i].purpose == _purpose) {
                return (i, true);
            }
        }
        return (0, false);
    }

    function _addKey(bytes32 _key, uint256 _purpose, uint256 _keyType) internal {
        allKeys.push(Key(_purpose, _keyType, _key));
        KeyAdded(_key, _purpose, _keyType);
    }

    modifier onlyManagementOrSelf {
        // MUST only be done by keys of purpose 1, or the identity itself
        if (msg.sender == address(this)) {
            _;
        } else {
            bytes32 key = keccak256(msg.sender);
            var (, found) = _getKeyIndex(key, MANAGEMENT_KEY);
            require(found);
            _;
        }
    }
}
