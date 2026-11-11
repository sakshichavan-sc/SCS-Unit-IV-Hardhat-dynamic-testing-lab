// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract SavingsPoolFixed {
    address public owner;
    uint256 public feeBps;
    uint256 public collectedFees;
    mapping(address => uint256) public balanceOf;
    uint256 public constant MAX_FEE_BPS = 500;

    error ZeroAmount();
    error InsufficientBalance();
    error TransferFailed();
    error NotOwner();
    error FeeTooHigh();

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 fee);
    event FeeChanged(uint256 newFeeBps);

    constructor(uint256 initialFeeBps) {
        if (initialFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        owner = msg.sender;
        feeBps = initialFeeBps;
    }

    function deposit() external payable {
        if (msg.value == 0) revert ZeroAmount();
        balanceOf[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();

        uint256 fee = (amount * feeBps) / 10_000;
        balanceOf[msg.sender] -= amount;
        collectedFees += fee;

        (bool ok, ) = msg.sender.call{value: amount - fee}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(msg.sender, amount, fee);
    }

    // Fixed: checks -> effects -> interactions.
    function withdrawAll() external {
        uint256 amount = balanceOf[msg.sender];
        if (amount == 0) revert ZeroAmount();

        uint256 fee = (amount * feeBps) / 10_000;
        balanceOf[msg.sender] = 0;
        collectedFees += fee;

        (bool ok, ) = msg.sender.call{value: amount - fee}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(msg.sender, amount, fee);
    }

    // Fixed: owner-only access control.
    function setFee(uint256 newFeeBps) external {
        if (msg.sender != owner) revert NotOwner();
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        feeBps = newFeeBps;
        emit FeeChanged(newFeeBps);
    }

    function claimFees() external {
        if (msg.sender != owner) revert NotOwner();
        uint256 amount = collectedFees;
        collectedFees = 0;
        (bool ok, ) = owner.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
