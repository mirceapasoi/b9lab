pragma solidity ^0.4.21;

import "./KeyArray.sol";

contract KeyBase {
    uint256 constant MANAGEMENT_KEY = 1;

    // For multi-sig
    uint256 public managementThreshold = 1;
    uint256 public actionThreshold = 1;

    // Store keys in an array
    using KeyArray for KeyArray.Key[];
    KeyArray.Key[] allKeys;

    function _managementOrSelf()
        internal
        view
        returns (bool found)
    {
        if (msg.sender == address(this)) {
            // Identity contract itself
            return true;
        }
        // Only works with 1 key threshold, otherwise need multi-sig
        require(managementThreshold == 1);
        (, found) = allKeys.find(addrToKey(msg.sender), MANAGEMENT_KEY);
    }

    modifier onlyManagementOrSelf {
        // MUST only be done by keys of purpose 1, or the identity itself
        require(_managementOrSelf());
        _;
    }

    // Helper function
    function numKeys()
        external
        view
        returns (uint)
    {
        return allKeys.length;
    }

    function addrToKey(address addr)
        public
        pure
        returns (bytes32)
    {
        return bytes32(addr);
    }
}
