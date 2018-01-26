pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'zeppelin-solidity/contracts/lifecycle/Destructible.sol';
import 'zeppelin-solidity/contracts/payment/PullPayment.sol';
// For testing purposes
import 'zeppelin-solidity/contracts/ownership/HasNoEther.sol';

contract Splitter is Pausable, Destructible, PullPayment {
    event Split(address from, address to, uint value);

    function Splitter() public {
    }

    function split(address b, address c) external payable whenNotPaused returns (bool) {
        require(msg.value > 0); // must be non-zero
        require(msg.value % 2 == 0); // must be divisible
        require(b != address(0)); // must exist
        require(c != address(0)); // must exist
        uint halfValue = msg.value / 2;
        asyncSend(b, halfValue);
        Split(msg.sender, b, halfValue);
        asyncSend(c, halfValue);
        Split(msg.sender, c, halfValue);
        return true;
    }
}