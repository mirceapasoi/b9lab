pragma solidity ^0.4.23;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/Splitter.sol";

contract TestSplitter {
    uint public initialBalance = 101 finney;
    address bobby = address(1);
    address carol = address(2);

    function testSplitEqual() public {
        Splitter splitter = Splitter(DeployedAddresses.Splitter());

        splitter.split.value(100 finney)(bobby, carol);

        Assert.equal(address(splitter).balance, 100 finney, "Splitter contract should have the Ether");
        Assert.equal(splitter.payments(bobby), 50 finney, "Bob should be owed the exact half");
        Assert.equal(splitter.payments(carol), 50 finney, "Carol should be owed the exact half");
    }
}