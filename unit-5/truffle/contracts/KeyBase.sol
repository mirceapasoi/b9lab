pragma solidity ^0.4.21;

import "./KeyArray.sol";

contract KeyBase {
    uint256 constant MANAGEMENT_KEY = 1;

    // For multi-sig
    uint256 public managementThreshold = 1;
    uint256 public actionThreshold = 1;

    using KeyArray for KeyArray.Key[];
    KeyArray.Key[] allKeys;

    function _managementCall()
        internal
        view
        returns (bool found)
    {
        // Only works with 1 key
        require(managementThreshold == 1);
        uint index;
        (index, found) = allKeys.find(addrToKey(msg.sender), MANAGEMENT_KEY);
    }

    modifier onlyManagementOrSelf {
        // MUST only be done by keys of purpose 1, or the identity itself
        require(msg.sender == address(this) || _managementCall());
        _;
    }

    // Helper function
    function addrToKey(address addr)
        public
        pure
        returns (bytes32)
    {
        return keccak256(addr);
    }
}
