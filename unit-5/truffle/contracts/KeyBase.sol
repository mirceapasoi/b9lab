pragma solidity ^0.4.21;

import "./KeyArray.sol";

contract KeyBase {
    // Copied from ERC725
    uint256 constant MANAGEMENT_KEY = 1;

    // For multi-sig
    uint256 managementThreshold = 1;
    uint256 actionThreshold = 1;

    using KeyArray for KeyArray.Key[];
    KeyArray.Key[] allKeys;

    modifier onlyManagementOrSelf {
        // MUST only be done by keys of purpose 1, or the identity itself
        if (msg.sender == address(this)) {
            _;
        } else {
            // Only works with 1 key
            require(managementThreshold == 1);
            uint index;
            bool found;
            (index, found) = allKeys.findAddr(msg.sender, MANAGEMENT_KEY);
            require(found);
            _;
        }
    }
}
