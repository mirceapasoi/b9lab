pragma solidity ^0.4.21;

library KeyArray {
    struct Key {
        uint256 purpose; //e.g., MANAGEMENT_KEY = 1, ACTION_KEY = 2, etc.
        uint256 keyType; // e.g. 1 = ECDSA, 2 = RSA, etc.
        bytes32 key; // for non-hex and long keys, its the Keccak256 hash of the key
    }

    function find(Key[] storage self, bytes32 key, uint256 purpose)
        internal
        view
        returns (uint, bool)
    {
        for (uint i = 0; i < self.length; i++) {
            if (self[i].key == key && self[i].purpose == purpose) {
                return (i, true);
            }
        }
        return (0, false);
    }

    function add(Key[] storage self, bytes32 key, uint256 purpose, uint256 keyType)
        internal
    {
        self.push(Key(purpose, keyType, key));
    }

    function remove(Key[] storage self, uint index)
        internal
        returns (Key key)
    {
        key = self[index];
        delete self[index];
    }
}