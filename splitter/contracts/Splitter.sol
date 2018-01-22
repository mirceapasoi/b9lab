pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'zeppelin-solidity/contracts/lifecycle/Destructible.sol';
import 'zeppelin-solidity/contracts/payment/PullPayment.sol';
// For testing purposes
import 'zeppelin-solidity/contracts/ownership/HasNoEther.sol';

contract Splitter is Pausable, Destructible, PullPayment {
    address public alice;
    address public bob;
    address public carol;
    event Split(address from, address to, uint value, bool success);

    function Splitter(address _alice, address _bob, address _carol) public {
        require(_alice != address(0));
        require(_bob != address(0));
        require(_carol != address(0));
        alice = _alice;
        bob = _bob;
        carol = _carol;
    }

    function split(address _bob, address _carol) public payable whenNotPaused returns (bool) {
        require(msg.value > 0); // must be non-zero
        require(msg.value % 2 == 0); // must be divisible
        require(_bob != address(0)); // must exist
        require(_carol != address(0)); // must exist
        uint halfValue = msg.value / 2;
        // to prevent sabotage from either bob or carol, we don't stop if one send fails
        bool sentBob = _bob.send(halfValue);
        Split(msg.sender, _bob, halfValue, sentBob);
        if (!sentBob) {
            // refund sender
            asyncSend(msg.sender, halfValue);
        }
        bool sentCarol = _carol.send(halfValue);
        Split(msg.sender, _carol, halfValue, sentCarol);
        if (!sentCarol) {
            // refund sender
            asyncSend(msg.sender, halfValue);
        }
        return sentBob && sentCarol;
    }

    function splitBobCarol() external payable whenNotPaused returns (bool) {
        // only allow Alice to send to this contract, otherwise your ether gets trapped
        require(msg.sender == alice);
        return split(bob, carol);
    }
}