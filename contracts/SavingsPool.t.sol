// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SavingsPool} from "./SavingsPool.sol";

contract SavingsPoolTest is Test {
    SavingsPool internal pool;
    address internal owner;
    address internal alice;
    address internal bob;

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.deal(owner, 100 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);

        vm.prank(owner);
        pool = new SavingsPool(100);
    }

    function test_DepositCreditsSender() public {
        vm.prank(alice);
        pool.deposit{value: 2 ether}();
        assertEq(pool.balanceOf(alice), 2 ether);
        assertEq(address(pool).balance, 2 ether);
    }

    function test_RevertWhen_DepositIsZero() public {
        vm.expectRevert(SavingsPool.ZeroAmount.selector);
        vm.prank(alice);
        pool.deposit{value: 0}();
    }

    function test_WithdrawChargesOnePercentFee() public {
        vm.prank(alice); pool.deposit{value: 1 ether}();
        vm.prank(alice); pool.withdraw(1 ether);
        assertEq(alice.balance, 9.99 ether);
        assertEq(pool.balanceOf(alice), 0);
        assertEq(pool.collectedFees(), 0.01 ether);
        assertEq(address(pool).balance, 0.01 ether);
    }

    function test_PartialWithdrawLeavesRemainder() public {
        vm.prank(alice); pool.deposit{value: 2 ether}();
        vm.prank(alice); pool.withdraw(0.5 ether);
        assertEq(pool.balanceOf(alice), 1.5 ether);
        assertEq(alice.balance, 8.495 ether);
        assertEq(pool.collectedFees(), 0.005 ether);
    }

    function test_RevertWhen_WithdrawMoreThanBalance() public {
        vm.prank(alice); pool.deposit{value: 1 ether}();
        vm.expectRevert(SavingsPool.InsufficientBalance.selector);
        vm.prank(alice); pool.withdraw(2 ether);
    }

    function test_WithdrawAllPaysOnceAndZeroes() public {
        vm.prank(alice); pool.deposit{value: 3 ether}();
        vm.prank(alice); pool.withdrawAll();
        assertEq(pool.balanceOf(alice), 0);
        assertEq(alice.balance, 9.97 ether);
        assertEq(pool.collectedFees(), 0.03 ether);
        assertEq(address(pool).balance, 0.03 ether);
    }

    function test_RevertWhen_ConstructorFeeTooHigh() public {
        vm.expectRevert(SavingsPool.FeeTooHigh.selector);
        new SavingsPool(501);
    }

    function test_OwnerClaimsFees() public {
        vm.prank(alice); pool.deposit{value: 1 ether}();
        vm.prank(alice); pool.withdraw(1 ether);
        uint256 ownerBefore = owner.balance;
        vm.prank(owner); pool.claimFees();
        assertEq(owner.balance, ownerBefore + 0.01 ether);
        assertEq(pool.collectedFees(), 0);
    }

    function test_Invariant_PoolHoldsBalancesPlusFees() public {
        vm.prank(alice); pool.deposit{value: 4 ether}();
        vm.prank(bob); pool.deposit{value: 2 ether}();
        vm.prank(alice); pool.withdraw(1 ether);
        assertEq(
            address(pool).balance,
            pool.balanceOf(alice) + pool.balanceOf(bob) + pool.collectedFees()
        );
    }

    function test_RevertWhen_NonOwnerClaimsFees() public {
        vm.expectRevert(SavingsPool.NotOwner.selector);
        vm.prank(bob); pool.claimFees();
    }

    // This is intentionally expected to FAIL against the vulnerable contract.
    function test_RevertWhen_NonOwnerSetsFee() public {
        vm.expectRevert(SavingsPool.NotOwner.selector);
        vm.prank(bob); pool.setFee(500);
    }

    function test_Exploit_AnyoneRaisesFee() public {
        vm.prank(bob); pool.setFee(500);
        vm.prank(alice); pool.deposit{value: 1 ether}();
        vm.prank(alice); pool.withdraw(1 ether);
        assertEq(alice.balance, 9.95 ether);
        assertLt(alice.balance, 9.99 ether);
    }


    function test_WithdrawTransferFailedForNonPayableCaller() public {
        RejectEtherCaller rejector = new RejectEtherCaller(address(pool));
        vm.deal(address(this), 1 ether);
        rejector.depositToPool{value: 1 ether}();

        vm.expectRevert(SavingsPool.TransferFailed.selector);
        rejector.withdrawFromPool(1 ether);
    }
}

contract RejectEtherCaller {
    SavingsPool public pool;

    constructor(address poolAddress) {
        pool = SavingsPool(poolAddress);
    }

    function depositToPool() external payable {
        pool.deposit{value: msg.value}();
    }

    function withdrawFromPool(uint256 amount) external {
        pool.withdraw(amount);
    }
}

