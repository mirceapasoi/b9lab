pragma solidity ^0.4.21;

contract ERC725 {
    // Purpose
    // 1: MANAGEMENT keys, which can manage the identity
    uint256 constant MANAGEMENT_KEY = 1;
    // 2: ACTION keys, which perform actions in this identities name (signing, logins, transactions, etc.)
    uint256 constant ACTION_KEY = 2;
    // 3: CLAIM signer keys, used to sign claims on other identities which need to be revokable.
    uint256 constant CLAIM_SIGNER_KEY = 3;
    // 4: ENCRYPTION keys, used to encrypt data e.g. hold in claims.
    uint256 constant ENCRYPTION_KEY = 4;

    // KeyType
    uint256 constant ECDSA_TYPE = 1;
    uint256 constant RSA_TYPE = 2;

    event KeyAdded(bytes32 indexed key, uint256 indexed purpose, uint256 indexed keyType);
    event KeyRemoved(bytes32 indexed key, uint256 indexed purpose, uint256 indexed keyType);
    event ExecutionRequested(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);
    event Executed(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);
    event Approved(uint256 indexed executionId, bool approved);
    // Extra event, not part of the standard
    event ExecutionFailed(uint256 indexed executionId, address indexed to, uint256 indexed value, bytes data);

    function getKey(bytes32 _key, uint256 _purpose) public view returns(uint256 purpose, uint256 keyType, bytes32 key);
    function getKeyPurpose(bytes32 _key) public view returns(uint256[] purpose);
    function getKeysByPurpose(uint256 _purpose) public view returns(bytes32[] keys);
    function addKey(bytes32 _key, uint256 _purpose, uint256 _keyType) public returns (bool success);
    function execute(address _to, uint256 _value, bytes _data) public returns (uint256 executionId);
    function approve(uint256 _id, bool _approve) public returns (bool success);
    function removeKey(bytes32 _key, uint256 _purpose) public returns (bool success);
}