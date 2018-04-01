pragma solidity ^0.4.21;

import "./Destructible.sol";
import "./ERC735.sol";
import "./KeyGetters.sol";
import "./KeyManager.sol";
import "./MultiSig.sol";

contract Identity is Destructible, KeyManager, KeyGetters, MultiSig {
    function Identity() public {
        // Add key that deployed the contract
        _addKey(keccak256(msg.sender), MANAGEMENT_KEY, ECDSA);
    }

    // Helper function
    function addressToKey(address addr) public pure returns (bytes32) {
        return keccak256(addr);
    }

    // Fallback function accepts Ether transactions
    function () external payable {
    }
}