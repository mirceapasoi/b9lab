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
            address signedBy = getSignatureAddress(claimToSign(address(this), _claimType, _data), _signature);
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

    modifier onlyManagementOrSelfOrIssuer(bytes32 _claimId) {
        address issuer = claims[_claimId].issuer;
        // Must exist
        require(issuer != 0);

        bool valid = false;
        if (_managementOrSelf()) {
            valid = true;
        } else
        if (msg.sender == issuer) {
            // MUST only be done by the issuer of the claim
            valid = true;
        } else
        if (issuer.doesContractImplementInterface(ERC725ID())) {
            // Issuer is another Identity contract, is this an action key?
            uint256 purpose;
            (purpose, , ) = ERC725(issuer).getKey(addrToKey(msg.sender), ACTION_KEY);
            valid = (purpose == ACTION_KEY);
        }
        // Can perform action on claim
        require(valid);
        _;
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
        bool noApproval = _managementOrSelf();

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
        whenNotPaused
        onlyManagementOrSelfOrIssuer(_claimId)
        returns (bool success)
    {
        Claim memory c = claims[_claimId];
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

    function getClaimByTypeAndIndex(uint256 _claimType, uint256 _index)
        public
        view
        returns (
        uint256 claimType,
        uint256 scheme,
        address issuer,
        bytes32 signature,
        bytes32 data,
        bytes32 uri
        )
    {
        // TODO: Get rid of this when Solidity 0.4.22 is out
        // https://github.com/ethereum/solidity/issues/3270
        bytes32 claimId = claimsByType[_claimType][_index];
        bytes memory _signature;
        bytes memory _data;
        string memory _uri;
        (claimType, scheme, issuer, _signature, _data, _uri) = getClaim(claimId);
        // https://ethereum.stackexchange.com/questions/9142/how-to-convert-a-string-to-bytes32
        assembly {
            signature := mload(add(_signature, 32))
            data := mload(add(_data, 32))
            uri := mload(add(_uri, 32))
        }
    }

    // Helper functions
    function refreshClaim(bytes32 _claimId)
        public
        whenNotPaused
        onlyManagementOrSelfOrIssuer(_claimId)
        returns (bool)
    {
        // Must exist
        Claim memory c = claims[_claimId];
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

    function getSignatureAddress(bytes32 signed, bytes signature)
        public
        pure
        returns (address)
    {
        return keccak256(ETH_PREFIX, signed).recover(signature);
    }
}