pragma solidity ^0.4.21;

import "./ERC165Query.sol";
import "./ERC735.sol";

contract TestContract {
    using ERC165Query for address;

    event IdentityCalled(bytes32 data);
    mapping (address => uint) public numCalls;

    function TestContract() public {
    }

    function callMe() external {
        numCalls[msg.sender] += 1;
    }

    function whoCalling() external {
        // ERC735
        require(msg.sender.doesContractImplementInterface(0x10765379));
        // Get first LABEL claim
        ERC735 id = ERC735(msg.sender);
        // TODO: Wait until Solidity 0.4.22 is out to call getClaimIdsByType and getClaim
        // https://github.com/ethereum/solidity/issues/3270
        bytes32 data;
        (, , , , data, ) = id.getClaimByTypeAndIndex(5, 0);
        emit IdentityCalled(data);
    }
}
