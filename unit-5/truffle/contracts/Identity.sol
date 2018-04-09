pragma solidity ^0.4.21;

import "./Destructible.sol";
import "./ERC735.sol";
import "./KeyGetters.sol";
import "./KeyManager.sol";
import "./MultiSig.sol";
import "./ClaimManager.sol";

contract Identity is Destructible, KeyManager, KeyGetters, MultiSig, ClaimManager {
    function Identity(
        bytes32[] keys,
        uint256[] purposes,
        uint256[] keyTypes
    )
        public
    {
        // Validate keys are sorted and unique
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
            bytes32 senderKey = addrToKey(msg.sender);
            // Add key that deployed the contract for MANAGEMENT, ACTION, CLAIM
            _addKey(senderKey, MANAGEMENT_KEY, ECDSA_TYPE);
            _addKey(senderKey, ACTION_KEY, ECDSA_TYPE);
            _addKey(senderKey, CLAIM_SIGNER_KEY, ECDSA_TYPE);
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