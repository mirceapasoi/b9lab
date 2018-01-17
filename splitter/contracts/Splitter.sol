pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract Splitter is Ownable {
    address public alice;
    address public bob;
    address public carol;

    function Splitter(address _alice, address _bob, address _carol) public {
        alice = _alice;
        bob = _bob;
        carol = _carol;
    }

    function _getBalance(address _address) internal view returns (uint) {
        return _address.balance;
    }

    function getBalance() external view returns (uint) {
        return _getBalance(this);
    }

    function getAliceBalance() external view returns (uint) {
        return _getBalance(alice);
    }

    function getBobBalance() external view returns (uint) {
        return _getBalance(bob);
    }

    function getCarolBalance() external view returns (uint) {
        return _getBalance(carol);
    }

    function kill() external onlyOwner returns (bool) {
        selfdestruct(owner);
        return true;
    }

    function split(address _bob, address _carol) public payable {
        require(_bob != address(0));
        require(_carol != address(0));
        _bob.transfer(msg.value / 2);
        _carol.transfer(msg.value / 2);
    }

    function () public payable {
        require(alice != address(0));
        if (msg.sender == alice) {
            split(bob, carol);
        }
    }
}