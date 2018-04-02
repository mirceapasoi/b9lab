pragma solidity ^0.4.21;

import "./Destructible.sol";
import "./ERC735.sol";
import "./KeyGetters.sol";
import "./KeyManager.sol";
import "./MultiSig.sol";
import "./ClaimManager.sol";

contract Identity is Destructible, KeyManager, KeyGetters, MultiSig, ClaimManager {
    function Identity() public {
        // Add key that deployed the contract
        _addKey(addrToKey(msg.sender), MANAGEMENT_KEY, ECDSA_TYPE);
    }

    // Fallback function accepts Ether transactions
    function () external payable {
    }
}