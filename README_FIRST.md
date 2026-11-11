# SCS Unit IV Lab: Dynamic Testing with Hardhat 3

## Student Details

- **Name:** sakshi chavan
- **Roll Number:** 3022411007
- **Subject:** Smart Contract Security
- **Lab:** Unit IV – Dynamic Testing with Hardhat 3
- **Solidity Version:** 0.8.24
- **Framework:** Hardhat 3

---

## 1. Lab Objective

The objective of this lab is to understand and perform dynamic testing of Solidity smart contracts using Hardhat.

The lab focuses on:

- Writing unit tests for smart contracts.
- Testing access control and failure conditions.
- Identifying vulnerabilities through exploit testing.
- Understanding reentrancy attacks.
- Applying the Checks-Effects-Interactions (CEI) pattern.
- Measuring code coverage and gas usage.
- Using debugging output to understand contract execution.

## 2. Project Setup

### Requirements

- Node.js
- npm
- Hardhat 3
- Solidity 0.8.24

### Installation

Install project dependencies:

```powershell
npm install
```

Build the project:

```powershell
npx hardhat build
```

Run Solidity tests:

```powershell
npx hardhat test solidity
```

Check installed versions:

```powershell
node --version
npm --version
npx hardhat --version
```

Record the actual versions displayed by these commands before submission.

### Project Structure

```text
SCS_U4_Lab_Completed/
│
├── contracts/
│   ├── SavingsPool.sol
│   ├── SavingsPoolFixed.sol
│   └── Attacker.sol
│
├── test/
│   └── (if applicable)
│
├── hardhat.config.ts
├── package.json
├── README_FIRST.md
└── LAB_STATUS.md
```

The Solidity test files are located in the project according to the Hardhat configuration.

---

## 3. Understanding the SavingsPool Contract

The SavingsPool contract allows users to deposit ETH, withdraw funds, and pay a withdrawal fee.

It also allows the owner to collect accumulated fees.

### Question 1: Which functions move ETH out of the contract, and to whom?

There are three functions that transfer ETH out of the contract:

1. **withdraw(amount):** Sends the withdrawal amount after deducting the fee to the user who called the function.
2. **withdrawAll():** Sends the user's entire recorded balance after deducting the fee to the user.
3. **claimFees():** Sends the accumulated fees to the contract owner.

### Question 2: Which functions should be restricted to the owner?

The `setFee()` and `claimFees()` functions should be restricted to the contract owner.

- `setFee()` should only allow the owner to change the withdrawal fee.
- `claimFees()` should only allow the owner to collect accumulated fees.

In the vulnerable contract, `claimFees()` checks the caller against the owner address. However, `setFee()` does not perform an owner authorization check.

### Question 3: What state changes happen before and after ETH transfers?

**withdraw():**

- Checks the withdrawal amount and user balance.
- Calculates the fee.
- Reduces the user's recorded balance.
- Increases collected fees.
- Transfers the remaining ETH to the user.

**withdrawAll():**

- Reads the user's recorded balance.
- Calculates the fee.
- Transfers ETH to the user.
- Sets the user's recorded balance to zero.
- Updates collected fees.

The original `withdrawAll()` performs the external ETH transfer before updating the user's balance. This creates a reentrancy vulnerability.

**claimFees():**

- Checks whether the caller is the owner.
- Reads the accumulated fees.
- Sets collected fees to zero.
- Transfers ETH to the owner.

---

## 4. Unit Testing

Unit tests were written to verify normal contract behaviour and failure conditions.

### Tests performed

| Test | Purpose |
|---|---|
| `test_DepositCreditsSender` | Checks whether deposits increase the user's balance |
| `test_RevertWhen_DepositIsZero` | Checks whether zero-value deposits revert |
| `test_WithdrawChargesOnePercentFee` | Checks the 1% withdrawal fee |
| `test_PartialWithdrawLeavesRemainder` | Checks whether the remaining balance is correct |
| `test_RevertWhen_WithdrawMoreThanBalance` | Checks withdrawal beyond the available balance |
| `test_WithdrawAllPaysOnceAndZeroes` | Checks the withdraw-all operation |
| `test_RevertWhen_ConstructorFeeTooHigh` | Checks the maximum fee restriction |
| `test_OwnerClaimsFees` | Checks whether the owner can collect fees |
| `test_Invariant_PoolHoldsBalancesPlusFees` | Checks the relationship between pool funds, user balances and fees |
| `test_RevertWhen_NonOwnerClaimsFees` | Checks access control for fee collection |
| `test_RevertWhen_NonOwnerSetsFee` | Checks whether a non-owner can change the fee |
| `test_WithdrawTransferFailedForNonPayableCaller` | Checks the failed ETH transfer condition |

### Example fee calculation

Assume a user withdraws 1 ETH with a fee of 100 basis points.

```text
Fee = (1 ETH × 100) / 10000
Fee = 0.01 ETH

Amount received = 1 ETH - 0.01 ETH
Amount received = 0.99 ETH
```

The user receives 0.99 ETH, and 0.01 ETH is added to collected fees.

---

## 5. Testing Access Control

The original contract contains a missing authorization check in `setFee()`.

A non-owner can call this function and change the withdrawal fee.

### Test performed

`test_RevertWhen_NonOwnerSetsFee`

Expected behaviour:

A non-owner should not be allowed to change the withdrawal fee.

Actual behaviour:

The vulnerable contract allows the non-owner to change the fee because the function does not check `msg.sender == owner`.

The test fails with:

```text
Error: next call did not revert as expected
```

This is an intentional security finding. The failure demonstrates that the original contract does not follow the expected access-control rule.

### Impact test

`test_Exploit_AnyoneRaisesFee`

This test demonstrates how an attacker can increase the withdrawal fee and cause additional financial loss to users.

For example:

- Original fee: 1%
- Manipulated fee: 5%
- Withdrawal: 1 ETH
- Expected fee at 1%: 0.01 ETH
- Fee at 5%: 0.05 ETH
- Additional loss: 0.04 ETH

Therefore, missing access control can directly affect users financially.

---

## 6. Reentrancy Attack

The original `withdrawAll()` function performs an external ETH transfer before updating the user's balance.

An attacker can use a malicious contract with a `receive()` function to call `withdrawAll()` repeatedly before the original balance is set to zero.

### Attack sequence

1. The attacker deposits 1 ETH.
2. The attacker calls `withdrawAll()`.
3. The SavingsPool transfers ETH to the attacker's contract.
4. The attacker's `receive()` function calls `withdrawAll()` again.
5. The process repeats while the original balance remains recorded.
6. The attacker receives more ETH than the initial deposit.

### Exploit test

`test_Exploit_WithdrawAll`

The exploit test produced the following results:

| Parameter | Result |
|---|---:|
| Attacker's initial deposit | 1 ETH |
| Total withdrawAll entries | 11 |
| Reentries | 10 |
| Attacker's final ETH | 10.89 ETH |
| Attacker's net profit | 9.89 ETH |
| Remaining pool ETH | 0.11 ETH |
| Alice's recorded balance | 10 ETH |
| Collected fees | 0.11 ETH |

The results demonstrate that the vulnerable contract allows the attacker to withdraw ETH repeatedly.

### Why does setting the balance to zero twice not revert?

Setting a balance to zero is an assignment operation:

```solidity
balances[msg.sender] = 0;
```

Assigning zero multiple times does not cause an arithmetic underflow.

However, subtracting an amount from a balance that is already too small can revert because Solidity 0.8.x checks arithmetic underflow.

---

## 7. Fixing the Vulnerabilities

A separate contract named `SavingsPoolFixed.sol` was created to implement the security fixes while keeping the original vulnerable contract available for comparison.

### Fix 1: Checks-Effects-Interactions pattern

The fixed `withdrawAll()` function updates the user's balance and collected fees before making the external ETH transfer.

This prevents the attacker from re-entering the function using the old balance.

### Fix 2: Owner authorization

The fixed `setFee()` function checks whether the caller is the owner.

Only the owner can change the withdrawal fee.

### Fixed contract security principles

- Validate inputs before executing operations.
- Update contract state before external interactions.
- Restrict sensitive functions using owner authorization.
- Revert transactions when ETH transfers fail.

### Fixed contract tests

| Test | Expected result |
|---|---|
| `test_Fix_WithdrawAllStillWorks` | Normal withdrawal works |
| `test_Fix_ReentrancyAttackReverts` | Reentrancy attack is prevented |
| `test_Fix_NonOwnerCannotSetFee` | Non-owner cannot change the fee |

**Result:** All three fixed-contract tests passed.

---

## 8. Code Coverage and Gas Analysis

Coverage was measured using:

```powershell
npx hardhat test solidity --coverage
```

### Latest coverage results

| Contract | Line Coverage | Statement Coverage |
|---|---:|---:|
| Attacker.sol | 100% | 100% |
| SavingsPool.sol | 81.82% | 85.71% |
| SavingsPoolFixed.sol | 41.94% | 42.86% |
| **Total** | **66.20%** | **67.03%** |

### Coverage observation

The test `test_WithdrawTransferFailedForNonPayableCaller()` was added to exercise the failed ETH transfer condition in `withdraw()`.

The corresponding `TransferFailed` branch in `withdraw()` is covered.

Some lines remain uncovered in the vulnerable and fixed contracts. These include additional failure conditions and branches that were not exercised by the current test suite.

Coverage helps identify untested code, but high coverage alone does not prove that a smart contract is secure. Test assertions and security analysis are also necessary.

### Gas measurements

The recorded gas report showed:

| Function | Median Gas | Maximum Gas |
|---|---:|---:|
| `withdraw()` | 61,287 | 61,287 |
| `withdrawAll()` | 60,583 | 60,583 |

The `withdrawAll()` result has one directly recorded call in the gas report. Therefore, its median and maximum are equal.

Gas consumption can change depending on the execution path, storage operations and external calls.

---

## 9. Debugging with console.log

The Hardhat console logging feature was used to understand the execution of the vulnerable `withdrawAll()` function.

The following debugging statement was temporarily added:

```solidity
import "hardhat/console.sol";

console.log("withdrawAll entered; pool balance:", address(this).balance);
```

The exploit test printed 11 entries into `withdrawAll()`.

The last displayed pool balance was:

```text
1100000000000000000 wei
```

This is equal to:

```text
1.1 ETH
```

The debugging output helped demonstrate repeated execution of the vulnerable function.

After debugging, the temporary console import and logging statement should be removed from the final contract.

---

## 10. Additional Wrap-up Questions

### Question 1: Why do both the exploit test passing and the fixed attack test reverting matter?

The exploit test passing proves that the original vulnerable contract can be attacked successfully.

The fixed attack test reverting proves that the security changes prevent the same attack.

Both tests are important because they demonstrate the vulnerability and verify the effectiveness of the fix.

### Question 2: Why is withdrawAll() vulnerable while withdraw() is not vulnerable to the same attack?

The original `withdrawAll()` transfers ETH before updating the user's balance. This allows an attacker to re-enter the function while the old balance is still recorded.

In contrast, `withdraw()` updates the user's balance and collected fees before transferring ETH.

Therefore, `withdraw()` follows the Checks-Effects-Interactions pattern, while the original `withdrawAll()` does not.

### Question 3: Does code coverage prove that a contract is secure?

No. Code coverage only indicates how much of the code was executed during testing.

It does not guarantee that every possible input, attack or execution path has been tested.

Security also requires meaningful assertions, negative tests, fuzz testing, invariant testing and manual review.

### Question 4: What happens when a user withdraws 99 wei with a 1% fee?

The fee is calculated as:

```solidity
fee = (99 * 100) / 10000;
```

The result is 0 wei because Solidity integer division rounds down.

Therefore, the user receives the full 99 wei without paying a fee.

This is worth reporting as an observation about fee precision. Its security severity depends on the economic impact and whether the behaviour can be abused at scale.

---

## 11. Final Test Results

The final full test run produced:

```text
16 passing
1 failing
```

The one failing test is:

```text
test_RevertWhen_NonOwnerSetsFee
```

This failure is intentional in the original vulnerable contract because `setFee()` does not contain an owner authorization check.

The corresponding fixed-contract test:

```text
test_Fix_NonOwnerCannotSetFee
```

passes successfully.

The exploit tests also pass against the original contract, demonstrating the vulnerabilities, while the fixed-contract reentrancy test passes by confirming that the attack is prevented.

### Important distinction

The original contract is intentionally vulnerable for testing and demonstration. The fixed contract is maintained separately to demonstrate the security improvements.

---

## 12. Conclusion

In this lab, dynamic testing of Solidity smart contracts was performed using Hardhat 3.

Unit testing helped verify normal contract operations and failure conditions. Access-control testing identified a missing owner authorization check. Exploit testing demonstrated a reentrancy vulnerability in the original `withdrawAll()` function.

The vulnerabilities were addressed in a separate fixed contract using the Checks-Effects-Interactions pattern and owner authorization.

Code coverage, gas measurements and console debugging were also used to understand contract execution and identify areas requiring further testing.

This lab provided practical experience in identifying, reproducing, fixing and testing smart contract security vulnerabilities.

---

## 13. Commands Used

```powershell
# Install dependencies
npm install

# Build contracts
npx hardhat build

# Run all Solidity tests
npx hardhat test solidity

# Run exploit tests
npx hardhat test solidity --grep test_Exploit

# Run fixed contract tests
npx hardhat test solidity --grep test_Fix

# Generate coverage report
npx hardhat test solidity --coverage

# Check versions
node --version
npm --version
npx hardhat --version
```

**End of Lab Report**

**Student:** sakshi chavan
**Roll Number:** 3022411007