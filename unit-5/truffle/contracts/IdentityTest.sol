pragma solidity ^0.4.21;

contract IdentityTest {
    mapping (address => uint) public numCalls;

    function IdentityTest() public {
    }

    function callMe() external {
        numCalls[msg.sender] += 1;
    }
}
