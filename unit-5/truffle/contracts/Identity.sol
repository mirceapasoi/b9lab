pragma solidity ^0.4.21;

import "./Destructible.sol";
import "./ERC735.sol";
import "./KeyGetters.sol";
import "./KeyManager.sol";
import "./MultiSig.sol";
import "./ClaimManager.sol";

contract Identity is Destructible, KeyManager, KeyGetters, MultiSig, ClaimManager {
    function Identity(bytes32[] keys, uint256[] purposes, uint256[] keyTypes) public {
        // TODO: pass some initial keys in the constructor
        // TODO: pass some initial claims in the constructor

        require(keys.length == purposes.length);
        require(purposes.length == keyTypes.length);
        for (uint i = 1; i < keys.length; i++) {
            // Expect input to be in sorted order, first by keys, then by purposes
            // Sorted order guarantees (key, purpose) pairs are unique and we can use
            // _addKey insteaad of addKey (which also checks for existance)
            bytes32 prevKey = keys[i - 1];
            require(keys[i] > prevKey || (keys[i] == prevKey && purposes[i] > purposes[i - 1]));
        }

        // Supports both ERC 725 & 735
        supportedInterfaces[ERC725ID() ^ ERC735ID()] = true;


        if (keys.length == 0) {
            // Add key that deployed the contract
            _addKey(addrToKey(msg.sender), MANAGEMENT_KEY, ECDSA_TYPE);
        } else {
            // Add constructor keys
            for (i = 0; i < keys.length; i++) {
                _addKey(keys[i], purposes[i], keyTypes[i]);
            }
        }
    }

    // Fallback function accepts Ether transactions
    function () external payable {
    }
}