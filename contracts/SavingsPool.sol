
 // SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract SavingsPool {
    uint256 public feeBps;
    uint256 public constant MAX_FEE_BPS = 500;

    address public owner;

    mapping(address => uint256) public balances;
    uint256 public collectedFees;

    error ZeroAmount();
    error InsufficientBalance();
    error TransferFailed();
    error NotOwner();
    error FeeTooHigh();

    constructor(uint256 initialFeeBps) {
        if (initialFeeBps > MAX_FEE_BPS) revert FeeTooHigh();

        owner = msg.sender;
        feeBps = initialFeeBps;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();

        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance();
        }

        uint256 fee = (amount * feeBps) / 10000;
        uint256 amountToSend = amount - fee;

        balances[msg.sender] -= amount;
        collectedFees += fee;

        (bool success, ) =
            payable(msg.sender).call{value: amountToSend}("");

        if (!success) revert TransferFailed();
    }

    // INTENTIONALLY VULNERABLE: state updates happen after external call.
    function withdrawAll() external {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * feeBps) / 10000;
        uint256 amountToSend = amount - fee;

        (bool success, ) =
            payable(msg.sender).call{value: amountToSend}("");

        if (!success) revert TransferFailed();

        balances[msg.sender] = 0;
        collectedFees += fee;
    }

    // INTENTIONALLY VULNERABLE: missing owner authorization check.
    function setFee(uint256 newFeeBps) external {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();

        feeBps = newFeeBps;
    }

    function claimFees() external {
        if (msg.sender != owner) revert NotOwner();

        uint256 amount = collectedFees;
        if (amount == 0) revert ZeroAmount();

        collectedFees = 0;

        (bool success, ) = payable(owner).call{value: amount}("");

        if (!success) revert TransferFailed();
    }
}
