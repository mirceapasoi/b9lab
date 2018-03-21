pragma solidity ^0.4.18;

import "./ManagementKeys.sol";

contract Destructible is ManagementKeys {
    /**
    * @dev Transfers the current balance and terminates the contract.
    */
    function destroyAndSend(address _recipient) onlyManagementOrSelf public {
        selfdestruct(_recipient);
    }
}