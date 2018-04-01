pragma solidity ^0.4.21;

import "./KeyBase.sol";

contract Destructible is KeyBase {
    /// @dev Transfers the current balance and terminates the contract
    function destroyAndSend(address _recipient)
        onlyManagementOrSelf
        public
    {
        require(_recipient != address(0));
        selfdestruct(_recipient);
    }
}