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

    function addClaim(uint256 _claimType, uint256 _scheme, address issuer, bytes _signature, bytes _data, string _uri)
        public
        whenNotPaused
        returns (uint256 claimRequestId)
    {
        // Check signature
        address signedBy = signatureAddress(address(this), _claimType, _data, _signature);
        if (issuer == address(this) || issuer.doesContractImplementInterface(ERC725ID())) {
            // Issuer is this Identity contract
            // If an identity contract, it should hold the key with which the above message was signed.
            // If the key is not present anymore, the claim SHOULD be treated as invalid.
            uint256 purpose;
            uint256 keyType;
            bytes32 key;
            (purpose, keyType, key) = this.getKey(addrToKey(signedBy), CLAIM_SIGNER_KEY);
            require(purpose == CLAIM_SIGNER_KEY);
        } else {
            // Issuer should be the address used to sign the signature
            require(signedBy == issuer);
        }

        bytes32 claimId = keccak256(issuer, _claimType);
        Claim storage c = claims[claimId];
        if (c.issuer != 0) {
            // Existing claim, only issuer can change it
            require(msg.sender == issuer);
            c.scheme = _scheme;
            c.signature = _signature;
            c.data = _data;
            c.uri = _uri;
            // You can't change issuer or claimType without affecting the claimId, so we
            // don't need to update those two
            emit ClaimChanged(claimId, _claimType, _scheme, issuer, _signature, _data, _uri);
            return;
        }

        if (msg.sender == address(this) || _managementCall()) {
            // New claim, done by keys of purpose 1, or the identity itself
            claims[claimId] = Claim(_claimType, _scheme, issuer, _signature, _data, _uri);
            claimsByType[_claimType].push(claimId);
            emit ClaimAdded(claimId, _claimType, _scheme, issuer, _signature, _data, _uri);
            return;
        }

        // New claim, unknown sender, SHOULD be approved or rejected by n of m approve calls from keys of purpose 1
        claimRequestId = this.execute(address(this), 0, msg.data);
        emit ClaimRequested(claimRequestId, _claimType, _scheme, issuer, _signature, _data, _uri);
    }

    function removeClaim(bytes32 _claimId)
        public
        returns (bool success)
    {
        Claim memory c = claims[_claimId];
        // Must exist
        require(c.issuer != 0);
        // MUST only be done by the issuer of the claim, or keys of purpose 1, or the identity itself.
        // If its the identity itself, the approval process will determine its approval.
        require(msg.sender == c.issuer || msg.sender == address(this) || _managementCall());
        // Remove from mapping
        delete claims[_claimId];
        // Remove from type array
        bytes32[] storage cTypes = claimsByType[c.claimType];
        for (uint i = 0; i < cTypes.length; i++) {
            if (cTypes[i] == _claimId) {
                delete cTypes[i];
            }
        }
        // Event
        emit ClaimRemoved(_claimId, c.claimType, c.scheme, c.issuer, c.signature, c.data, c.uri);
        return true;
    }

    function getClaim(bytes32 _claimId)
        public
        view
        returns(uint256 claimType, uint256 scheme, address issuer, bytes signature, bytes data, string uri)
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

    function signatureAddress(address subject, uint256 claimType, bytes data, bytes signature)
        public
        pure
        returns (address)
    {
        bytes32 toSign = claimToSign(subject, claimType, data);
        bytes32 prefixed = keccak256(ETH_PREFIX, toSign);
        return prefixed.recover(signature);
    }
}