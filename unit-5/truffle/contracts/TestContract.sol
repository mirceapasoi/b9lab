pragma solidity ^0.4.21;

contract TestContract {
    mapping (address => uint) public numCalls;

    function TestContract() public {
    }

    function callMe() external {
        numCalls[msg.sender] += 1;
    }
}
