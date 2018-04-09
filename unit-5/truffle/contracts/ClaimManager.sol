pragma solidity ^0.4.21;

import "../../node_modules/zeppelin-solidity/contracts/ECRecovery.sol";
import "./Pausable.sol";
import "./ERC725.sol";
import "./ERC735.sol";
import "./ERC165Query.sol";

contract ClaimManager is Pausable, ERC725, ERC735 {
    using ECRecovery for bytes32;
    using ERC165Query for address;

    bytes constant ETH_PREFIX = "\x19Ethereum Signed Message:\n32";

    struct Claim {
        uint256 claimType;
        uint256 scheme;
        address issuer; // msg.sender
        bytes signature; // this.address + claimType + data
        bytes data;
        string uri;
    }
    mapping(bytes32 => Claim) claims;
    mapping(uint256 => bytes32[]) claimsByType;
    uint public numClaims;

    function _validSignature(
        uint256 _claimType,
        uint256 _scheme,
        address issuer,
        bytes _signature,
        bytes _data
    )
        internal
        view
        returns (bool)
    {
        if (_scheme == ECDSA_SCHEME) {
            address signedBy = getSignatureAddress(address(this), _claimType, _data, _signature);
            if (issuer == signedBy) {
                // Issuer signed the signature
                return true;
            } else
            if (issuer == address(this) || issuer.doesContractImplementInterface(ERC725ID())) {
                // Issuer is an Identity contract
                // It should hold the key with which the above message was signed.
                // If the key is not present anymore, the claim SHOULD be treated as invalid.
                uint256 purpose;
                (purpose, , ) = ERC725(issuer).getKey(addrToKey(signedBy), CLAIM_SIGNER_KEY);
                return (purpose == CLAIM_SIGNER_KEY);
            }
            // Invalid
            return false;
        }
        else {
            // Not implemented
            return false;
        }
    }

    function _validClaimAction(address issuer)
        internal
        view
        returns (bool)
    {
        if (msg.sender == address(this) || _managementCall()) {
            // MUST only be done by the issuer of the claim, or keys of purpose 1, or the identity itself.
            return true;
        }
        if (issuer == address(0)) {
            // Can't perform action
            return false;
        }
        if (msg.sender == issuer) {
            // MUST only be done by the issuer of the claim
            return true;
        } else
        if (issuer.doesContractImplementInterface(ERC725ID())) {
            // Issuer is another Identity contract, is this an action key?
            uint256 purpose;
            (purpose, , ) = ERC725(issuer).getKey(addrToKey(msg.sender), ACTION_KEY);
            return (purpose == ACTION_KEY);
        }
        // Can't perform action on a claim issued by issuer
        return false;
    }

    function addClaim(
        uint256 _claimType,
        uint256 _scheme,
        address issuer,
        bytes _signature,
        bytes _data,
        string _uri
    )
        public
        whenNotPaused
        returns (uint256 claimRequestId)
    {
        // Check signature
        require(_validSignature(_claimType, _scheme, issuer, _signature, _data));
        // Check we can perform action
        // If we pass "issuer" for an existing claim, then updates won't require any approval
        // from the identity. Just because a claim exists, it doesn't mean all future updates
        // are automatically approved. Hence, we pass address(0)
        bool noApproval = _validClaimAction(0);

        if (!noApproval) {
            // SHOULD be approved or rejected by n of m approve calls from keys of purpose 1
            claimRequestId = this.execute(address(this), 0, msg.data);
            emit ClaimRequested(claimRequestId, _claimType, _scheme, issuer, _signature, _data, _uri);
            return;
        }

        bytes32 claimId = keccak256(issuer, _claimType);
        if (claims[claimId].issuer == address(0)) {
            // New claim
            claims[claimId] = Claim(_claimType, _scheme, issuer, _signature, _data, _uri);
            claimsByType[_claimType].push(claimId);
            numClaims++;
            emit ClaimAdded(claimId, _claimType, _scheme, issuer, _signature, _data, _uri);
        } else {
            // Existing claim
            Claim storage c = claims[claimId];
            c.scheme = _scheme;
            c.signature = _signature;
            c.data = _data;
            c.uri = _uri;
            // You can't change issuer or claimType without affecting the claimId, so we
            // don't need to update those two fields
            emit ClaimChanged(claimId, _claimType, _scheme, issuer, _signature, _data, _uri);
        }
    }

    function removeClaim(bytes32 _claimId)
        public
        returns (bool success)
    {
        // Must exist
        Claim memory c = claims[_claimId];
        require(c.issuer != 0);

        // Can sender act on this claim?
        require(_validClaimAction(c.issuer));

        // Remove from mapping
        delete claims[_claimId];
        // Remove from type array
        bytes32[] storage cTypes = claimsByType[c.claimType];
        for (uint i = 0; i < cTypes.length; i++) {
            if (cTypes[i] == _claimId) {
                cTypes[i] = cTypes[cTypes.length - 1];
                delete cTypes[cTypes.length - 1];
                cTypes.length--;
                break;
            }
        }
        // Decrement
        numClaims--;
        // Event
        emit ClaimRemoved(_claimId, c.claimType, c.scheme, c.issuer, c.signature, c.data, c.uri);
        return true;
    }

    function getClaim(bytes32 _claimId)
        public
        view
        returns (
        uint256 claimType,
        uint256 scheme,
        address issuer,
        bytes signature,
        bytes data,
        string uri
        )
    {
        Claim memory c = claims[_claimId];
        require(c.claimType != 0);
        claimType = c.claimType;
        scheme = c.scheme;
        issuer = c.issuer;
        signature = c.signature;
        data = c.data;
        uri = c.uri;
    }

    function getClaimIdsByType(uint256 _claimType)
        public
        view
        returns(bytes32[] claimIds)
    {
        claimIds = claimsByType[_claimType];
    }

    // Helper functions
    function refreshClaim(bytes32 _claimId)
        public
        returns (bool)
    {
        // Must exist
        Claim memory c = claims[_claimId];
        require(c.issuer != 0);

        // Check we can perform action
        require(_validClaimAction(c.issuer));

        // Check claim is still valid
        if (!_validSignature(c.claimType, c.scheme, c.issuer, c.signature, c.data)) {
            // Remove claim
            removeClaim(_claimId);
            return false;
        }

        // Return true if claim is still valid
        return true;
    }

    function getClaimId(address issuer, uint256 claimType)
        public
        pure
        returns (bytes32)
    {
        return keccak256(issuer, claimType);
    }

    function claimToSign(address subject, uint256 claimType, bytes data)
        public
        pure
        returns (bytes32)
    {
        return keccak256(subject, claimType, data);
    }

    function getSignatureAddress(address subject, uint256 claimType, bytes data, bytes signature)
        public
        pure
        returns (address)
    {
        bytes32 toSign = claimToSign(subject, claimType, data);
        bytes32 prefixed = keccak256(ETH_PREFIX, toSign);
        return prefixed.recover(signature);
    }
}