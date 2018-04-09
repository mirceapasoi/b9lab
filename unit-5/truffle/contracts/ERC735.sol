pragma solidity ^0.4.21;

import "./ERC165.sol";

contract ERC735 is ERC165 {
    function ERC735ID() public pure returns (bytes4) {
        return (
            this.getClaim.selector ^ this.getClaimIdsByType.selector ^
            this.addClaim.selector ^ this.removeClaim.selector
        );
    }

    function ERC735() internal {
        supportedInterfaces[ERC735ID()] = true;
    }

    // ClaimType
    uint256 constant BIOMETRIC_CLAIM = 1; // you're a person and not a business
    uint256 constant RESIDENCE_CLAIM = 2; // you have a physical address or reference point
    uint256 constant REGISTRY_CLAIM = 3;
    uint256 constant PROFILE_CLAIM = 4; // social media profiles
    uint256 constant LABEL_CLAIM = 5; // real name, business name, nick name, brand name, alias, etc.

    // Scheme
    uint256 constant ECDSA_SCHEME = 1;
    // https://medium.com/@alexberegszaszi/lets-bring-the-70s-to-ethereum-48daa16a4b51
    uint256 constant RSA_SCHEME = 2;
    // 3 is contract verification, where the data will be call data, and the issuer a contract address to call
    uint256 constant CONTRACT_SCHEME = 3;

    event ClaimRequested(uint256 indexed claimRequestId, uint256 indexed claimType, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimAdded(bytes32 indexed claimId, uint256 indexed claimType, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimRemoved(bytes32 indexed claimId, uint256 indexed claimType, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);
    event ClaimChanged(bytes32 indexed claimId, uint256 indexed claimType, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri);

    function getClaim(bytes32 _claimId) public view returns(uint256 claimType, uint256 scheme, address issuer, bytes signature, bytes data, string uri);
    function getClaimIdsByType(uint256 _claimType) public view returns(bytes32[] claimIds);
    function addClaim(uint256 _claimType, uint256 _scheme, address issuer, bytes _signature, bytes _data, string _uri) public returns (uint256 claimRequestId);
    function removeClaim(bytes32 _claimId) public returns (bool success);
    // TODO: Not part of the standard
    function getClaimByTypeAndIndex(uint256 _claimType, uint256 _index) public view returns(uint256 claimType, uint256 scheme, address issuer, bytes32 signature, bytes32 data, bytes32 uri);
}