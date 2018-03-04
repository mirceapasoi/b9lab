pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/lifecycle/Pausable.sol';
import 'zeppelin-solidity/contracts/lifecycle/Destructible.sol';
import 'zeppelin-solidity/contracts/payment/PullPayment.sol';

contract Remittance is Pausable, Destructible, PullPayment {
    event LogDeposit(bytes32 id, address indexed from, address indexed to, uint value, uint32 until);
    event LogWithdraw(bytes32 id, address indexed from, address indexed to, uint value);

    uint constant MIN_DEPOSIT = 1 hours;
    uint constant MAX_DEPOSIT = 1 years;

    struct Deposit {
        bool used;
        uint32 until;
        address from;
        uint value;
    }
    mapping (bytes32 => Deposit) public deposits;


    function Remittance() public {}

    // Called by sender off-chain to hide their secrets
    function encode(address from, address to, bytes32 secret1, bytes32 secret2) public pure returns (bytes32) {
        // Valid addresses
        require(from != address(0));
        require(to != address(0));
        // We index deposits by the 3 addresses involved + the secret hashes
        return keccak256(from, to, secret1, secret2);
    }

    function deposit(bytes32 id, address to, uint32 until) external payable whenNotPaused {
        // Non-zero deposit
        require(msg.value > 0);
        // Hold for at least 1 hour
        require(until >= block.timestamp + MIN_DEPOSIT);
        // Can hold for 1 year
        require(until <= block.timestamp + MAX_DEPOSIT);
        // Deposit IDs should be unique
        Deposit storage d = deposits[id];
        require(!d.used);
        d.from = msg.sender;
        d.value = msg.value;
        d.until = until;
        d.used = true;
        LogDeposit(id, msg.sender, to, msg.value, until);
    }

    function _cleanDeposit(Deposit storage d) private {
        d.from = address(0);
        d.value = 0;
        d.until = 0;
    }

    function reclaim(bytes32 id) external whenNotPaused {
        Deposit storage d = deposits[id];
        // Deposit must exist
        require(d.until != 0);
        // Deposit is locked for a certain amount of time
        require(d.until < block.timestamp);
        // Can only be claimed by owner of deposit
        require(d.from == msg.sender);
        // Pay owner back
        asyncSend(msg.sender, d.value);
        LogWithdraw(id, msg.sender, msg.sender, d.value);
        // Delete deposit
        _cleanDeposit(d);
    }

    function unlock(bytes32 id, bytes32 secret1, bytes32 secret2) external whenNotPaused {
        Deposit storage d = deposits[id];
        // Deposit must exist
        require(d.until != 0);
        // Check secrets, which ensures only receiver can unlock it
        require(encode(d.from, msg.sender, secret1, secret2) == id);
        // Pay sender back
        asyncSend(msg.sender, d.value);
        LogWithdraw(id, d.from, msg.sender, d.value);
        // Delete deposit
        _cleanDeposit(d);
    }
}