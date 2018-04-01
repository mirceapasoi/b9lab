pragma solidity ^0.4.21;

contract IdentityTest {
    mapping (address => uint) numCalls;

    function IdentityTest() public {
    }

    function callMe() external {
        numCalls[msg.sender] += 1;
    }

    function getCalls() external view returns (uint) {
        return numCalls[msg.sender];
    }
}
