pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'zeppelin-solidity/contracts/lifecycle/Destructible.sol';
import 'zeppelin-solidity/contracts/payment/PullPayment.sol';

contract Remittance is Pausable, Destructible, PullPayment {
    enum Reason { RECLAIM, UNLOCK }

    event LogDeposit(bytes32 id, address from, address to, address other, uint value, uint until);
    event LogWithdraw(bytes32 id, address from, address to, uint value, Reason reason);

    uint constant MIN_DEPOSIT = 1 hours;
    uint constant MAX_DEPOSIT = 1 years;

    struct Deposit {
        address from;
        address to;
        address other;
        uint value;
        uint until;
    }
    mapping (bytes32 => Deposit) public deposits;


    function Remittance() public {}

    // Called by sender off-chain to hide their secrets
    function encode(address from, address to, address other, bytes32 secret1, bytes32 secret2) public pure returns (bytes32) {
        // Valid addresses
        require(from != address(0));
        require(to != address(0));
        require(other != address(0));
        // We index deposits by the 3 addresses involved + the secret hashes
        return keccak256(from, to, other, secret1, secret2);
    }

    function deposit(bytes32 id, address to, address other, uint until) external payable whenNotPaused {
        // Non-zero deposit
        require(msg.value > 0);
        // Hold for at least 1 hour
        require(until >= block.timestamp + MIN_DEPOSIT);
        // Can hold for 1 year
        require(until <= block.timestamp + MAX_DEPOSIT);
        // Deposit IDs should be unique
        require(deposits[id].until == 0);
        deposits[id] = Deposit(msg.sender, to, other, msg.value, until);
        LogDeposit(id, msg.sender, to, other, msg.value, until);
    }

    function reclaim(bytes32 id) external whenNotPaused {
        var d = deposits[id];
        // Deposit must exist
        require(d.until != 0);
        // Deposit is locked for a certain amount of time
        require(d.until < block.timestamp);
        // Can only be claimed by owner of deposit
        require(d.from == msg.sender);
        // Pay owner back
        asyncSend(msg.sender, d.value);
        LogWithdraw(id, msg.sender, msg.sender, d.value, Reason.RECLAIM);
        // Delete deposit
        delete deposits[id];
    }

    function unlock(bytes32 id, bytes32 secret1, bytes32 secret2) external whenNotPaused {
        var d = deposits[id];
        // Deposit must exist
        require(d.until != 0);
        // Sender or other can unlock it
        require(msg.sender == d.other || msg.sender == d.to);
        // Check secrets
        require(encode(d.from, d.to, d.other, secret1, secret2) == id);
        // Pay sender back
        asyncSend(msg.sender, d.value);
        LogWithdraw(id, d.from, msg.sender, d.value, Reason.UNLOCK);
        // Delete deposit
        delete deposits[id];
    }
}