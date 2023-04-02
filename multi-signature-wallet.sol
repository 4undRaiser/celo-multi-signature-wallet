// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet {
    address[] public owners;
    uint256 public required;

    struct Transaction {
        address destination;
        uint256 value;
        bytes data;
        bool executed;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    uint256 public transactionCount;

    modifier validRequirement(uint256 _ownerCount, uint256 _required) {
        require(_required > 0, "Required should be greater than 0");
        require(_ownerCount >= _required, "Owners count should be greater than or equal to required");
        _;
    }

    modifier ownerExists(address _owner) {
        require(isOwner(_owner), "Not an owner");
        _;
    }

    modifier notNull(address _address) {
        require(_address != address(0), "Address should not be null");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) validRequirement(_owners.length, _required) {
        for (uint256 i = 0; i < _owners.length; i++) {
            require(!isOwner(_owners[i]), "Duplicate owner");
            owners.push(_owners[i]);
        }
        required = _required;
    }

    function isOwner(address _owner) public view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                return true;
            }
        }
        return false;
    }

    function submitTransaction(address _destination, uint256 _value, bytes memory _data)
        public
        ownerExists(msg.sender)
        notNull(_destination)
        returns (uint256)
    {
        uint256 transactionId = addTransaction(_destination, _value, _data);
        confirmTransaction(transactionId);
        return transactionId;
    }

    function confirmTransaction(uint256 _transactionId) public ownerExists(msg.sender) {
        require(!confirmations[_transactionId][msg.sender], "Transaction already confirmed by this owner");
        confirmations[_transactionId][msg.sender] = true;
        executeTransaction(_transactionId);
    }

    function executeTransaction(uint256 _transactionId) public {
        require(transactions[_transactionId].executed == false, "Transaction already executed");
        if (isConfirmed(_transactionId)) {
            transactions[_transactionId].executed = true;
            (bool success, ) = transactions[_transactionId].destination.call{value: transactions[_transactionId].value}(
                transactions[_transactionId].data
            );
            require(success, "Transaction execution failed");
        }
    }

    function isConfirmed(uint256 _transactionId) public view returns (bool) {
        uint256 count = 0;
        for (uint256 i = 0; i < owners.length; i++) {
            if (confirmations[_transactionId][owners[i]]) {
                count += 1;
            }
            if (count == required) {
                return true;
            }
        }
        return false;
    }

    function addTransaction(address _destination, uint256 _value, bytes memory _data)
        internal
        notNull(_destination)
        returns (uint256)
    {
        uint256 transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: _destination,
        value: _value,
        data: _data,
        executed: false
    });
    transactionCount += 1;
    return transactionId;
}

function getOwners() public view returns (address[] memory) {
    return owners;
}

function getTransaction(uint256 _transactionId) public view returns (address destination, uint256 value, bytes memory data, bool executed) {
    Transaction memory transaction = transactions[_transactionId];
    return (transaction.destination, transaction.value, transaction.data, transaction.executed);
}

function getConfirmationCount(uint256 _transactionId) public view returns (uint256) {
    uint256 count = 0;
    for (uint256 i = 0; i < owners.length; i++) {
        if (confirmations[_transactionId][owners[i]]) {
            count += 1;
        }
    }
    return count;
}

function isConfirmedBy(uint256 _transactionId, address _owner) public view returns (bool) {
    return confirmations[_transactionId][_owner];
}

receive() external payable {}
}