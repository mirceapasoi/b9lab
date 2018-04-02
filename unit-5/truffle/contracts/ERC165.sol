pragma solidity ^0.4.21;

contract ERC165 {
    /// @dev You must not set element 0xffffffff to true
    mapping(bytes4 => bool) internal supportedInterfaces;

    function ERC165ID() public pure returns (bytes4) {
        return this.supportsInterface.selector;
    }

    function ERC165() internal {
        supportedInterfaces[ERC165ID()] = true;
    }

    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceID) external view returns (bool) {
        return supportedInterfaces[interfaceID];
    }
}