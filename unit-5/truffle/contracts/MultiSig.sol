pragma solidity ^0.4.21;

import "./Pausable.sol";
import "./ERC725.sol";

contract MultiSig is Pausable, ERC725 {
    uint256 nonce = 1;

    struct Execution {
        address to;
        uint256 value;
        bytes data;
        uint256 needsApprove;
    }
    mapping (uint256 => Execution) public execution;
    mapping (uint256 => address[]) public approved;

    function changeManagementThreshold(uint threshold)
        public
        whenNotPaused
        onlyManagementOrSelf
    {
        require(threshold > 0);
        // Don't lock yourself out
        uint numManagementKeys = getKeysByPurpose(MANAGEMENT_KEY).length;
        require(threshold <= numManagementKeys);
        managementThreshold = threshold;
    }

    function changeActionThreshold(uint threshold)
        public
        whenNotPaused
        onlyManagementOrSelf
    {
        require(threshold > 0);
        // Don't lock yourself out
        uint numActionKeys = getKeysByPurpose(ACTION_KEY).length;
        require(threshold <= numActionKeys);
        actionThreshold = threshold;
    }

    function getExecutionId(address _to, uint256 _value, bytes _data)
        internal
        view
        returns (uint256)
    {
        return uint(keccak256(this, _to, _value, _data, nonce));
    }

    function execute(address _to, uint256 _value, bytes _data)
        public
        whenNotPaused
        returns (uint256 executionId)
    {
        bool found;
        uint index;
        uint threshold;
        if (_to == address(this)) {
            if (msg.sender == address(this)) {
                // Contract calling itself
                found = true;
                threshold = managementThreshold;
            } else {
                // Only management keys can operate on this contract
                (index, found) = allKeys.findAddr(msg.sender, MANAGEMENT_KEY);
                threshold = managementThreshold - 1;
            }
        } else {
            require(_to != address(0));
            if (msg.sender == address(this)) {
                // Contract calling itself
                found = true;
                threshold = actionThreshold;
            } else {
                // Action keys can operate on other addresses
                (index, found) = allKeys.findAddr(msg.sender, ACTION_KEY);
                threshold = actionThreshold - 1;
            }
        }
        require(found);

        // Generate id and increment nonce
        executionId = getExecutionId(_to, _value, _data);
        emit ExecutionRequested(executionId, _to, _value, _data);
        nonce++;

        Execution memory e = Execution(_to, _value, _data, threshold);
        if (threshold == 0) {
            // One approval is enough, execute directly
            _execute(executionId, e, false);
        } else {
            execution[executionId] = e;
            approved[executionId].push(msg.sender);
        }

        return executionId;
    }

    function _execute(uint256 _id, Execution e, bool clean)
        internal
        returns (bool)
    {
        // Must exist
        require(e.to != 0);
        // Call
        // TODO: Should we also support DelegateCall and Create (new contract)?
        bool success = e.to.call.value(e.value)(e.data);
        if (!success) {
            emit ExecutionFailed(_id, e.to, e.value, e.data);
            return false;
        }
        emit Executed(_id, e.to, e.value, e.data);
        // Clean up
        if (!clean) {
            return true;
        }
        delete execution[_id];
        delete approved[_id];
        return true;
    }

    function approve(uint256 _id, bool _approve)
        public
        whenNotPaused
        returns (bool success)
    {
        require(_id != 0);
        Execution storage e = execution[_id];
        // Must exist
        require(e.to != 0);

        // Must be approved with the right key
        bool found;
        uint index;
        if (e.to == address(this)) {
            (index, found) = allKeys.findAddr(msg.sender, MANAGEMENT_KEY);
        } else {
            (index, found) = allKeys.findAddr(msg.sender, ACTION_KEY);
        }
        require(found);

        emit Approved(_id, _approve);

        address[] storage approvals = approved[_id];
        if (!_approve) {
            // Find in approvals
            for (uint i = 0; i < approvals.length; i++) {
                if (approvals[i] == msg.sender) {
                    // Undo approval
                    delete approvals[i];
                    e.needsApprove += 1;
                    return true;
                }
            }
            return false;
        } else {
            // Only approve once
            for (i = 0; i < approvals.length; i++) {
                require(approvals[i] != msg.sender);
            }

            // Approve
            approvals.push(msg.sender);
            e.needsApprove -= 1;

            // Do we need more approvals?
            if (e.needsApprove == 0) {
                return _execute(_id, e, true);
            }
            return true;
        }
    }
}