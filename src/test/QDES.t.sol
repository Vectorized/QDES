// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";

import {MockQDES, QDES} from "./mock/MockQDES.sol";

contract QDESTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;
    MockQDES internal qdes;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(2);
        qdes = new MockQDES();
        vm.deal(address(this), 100000 ether);
        vm.deal(address(users[0]), 100000 ether);
        vm.deal(address(users[1]), 100000 ether);
    }

    function testLastPriceNotStarted() public {
        assertEq(qdes.lastPrice(), 0);
    }
    
    function testLastTimestampNotStarted() public {
        assertEq(qdes.lastTimestamp(), 0);
    }
    
    function testCurrentPriceNotStarted() public {
        assertEq(qdes.currentPrice(), 0);
    }

    function testLastPriceStarted() public {
        qdes.start();
        assertEq(qdes.lastPrice(), qdes.startingPrice());
    }

    function testLastTimestampStarted() public {
        vm.warp(123456789);
        qdes.start();
        assertEq(qdes.lastTimestamp(), 123456789);
    }

    function testCurrentPriceStarted() public {
        qdes.start();
        assertEq(qdes.currentPrice(), qdes.startingPrice());
    }

    function testCannotPurchaseIfNotStarted() public {
        vm.expectRevert(QDES.NotStarted.selector);
        qdes.purchase{value: 10}(1);
    }

    function testCannotPurchaseIfUnderpaid() public {
        qdes.start();
        vm.expectRevert(QDES.InsufficientPayment.selector);
        qdes.purchase{value: 0}(1);
        uint256 price = qdes.currentPrice();
        vm.expectRevert(QDES.InsufficientPayment.selector);
        qdes.purchase{value: price - 1}(1);
    }

    function testCannotPurchaseZeroQuantity() public {
        qdes.start();
        uint256 price = qdes.currentPrice();
        vm.expectRevert(QDES.PurchaseZeroQuantity.selector);
        qdes.purchase{value: price}(0);
    }

    function testOverpayRefunds() public {
        vm.startPrank(users[0]);
        uint256 expectedBalance;
        uint256 price;
        uint256 initialBalance = address(users[0]).balance;

        qdes.start();
        price = qdes.currentPrice();
        qdes.purchase{value: price}(1);

        expectedBalance = initialBalance - price;
        assertEq(address(users[0]).balance, expectedBalance);

        price = qdes.currentPrice();
        qdes.purchase{value: price + 1}(1);
        expectedBalance = expectedBalance - price;
        assertEq(address(users[0]).balance, expectedBalance);

        vm.stopPrank();
    }

    function testExponentialSurge() public {
        uint256 price;
        qdes.start();
        price = qdes.currentPrice();
        uint256 quantity = 7;
        uint256 expectedNextPrice = price;
        uint256 growthNumerator = qdes.growthNumerator();
        uint256 growthDenominator = qdes.growthDenominator();

        for (uint256 i; i < quantity; ++i) {
            expectedNextPrice = expectedNextPrice * growthNumerator / growthDenominator;
        }
        qdes.purchase{value: price * quantity}(quantity);
        assertEq(qdes.currentPrice(), qdes.lastPrice());
        assertEq(qdes.currentPrice(), expectedNextPrice);
    }

    function testQuadraticDecay() public {
        vm.warp(1000000);
        qdes.start();
        uint256 startPrice = qdes.currentPrice();
        vm.warp(1000000 + 86400 / 2);
        uint256 halfDecayedPrice = qdes.currentPrice();
        assertLt(halfDecayedPrice, (startPrice + qdes.bottomPrice()) / 2);
        assertGt(halfDecayedPrice, qdes.bottomPrice());
        vm.warp(1000000 + 86400 - 1);
        uint256 almostFullDecayedPrice = qdes.currentPrice();
        assertLt(almostFullDecayedPrice, halfDecayedPrice);
        assertGt(almostFullDecayedPrice, qdes.bottomPrice());
        vm.warp(1000000 + 86400);
        assertEq(qdes.currentPrice(), qdes.bottomPrice());
        vm.warp(1000000 + 86400 + 1);
        assertEq(qdes.currentPrice(), qdes.bottomPrice());
        vm.warp(1000000 + 86400 + 10000000);
        assertEq(qdes.currentPrice(), qdes.bottomPrice());
    }

    function testQuadraticDecayExponentialSurge() public {
        uint256 price;
        vm.warp(1000000);
        qdes.start();
        vm.warp(1000000 + 86400 / 2);
        price = qdes.currentPrice();
        uint256 quantity = 7;
        qdes.purchase{value: price * quantity}(quantity);
        uint256 expectedNextPrice = price;
        uint256 growthNumerator = qdes.growthNumerator();
        uint256 growthDenominator = qdes.growthDenominator();

        for (uint256 i; i < quantity; ++i) {
            expectedNextPrice = expectedNextPrice * growthNumerator / growthDenominator;
        }
        assertEq(qdes.currentPrice(), expectedNextPrice);
    }
}

contract QDESBenchmark is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);
    Utilities internal utils;
    address payable[] internal users;
    MockQDES internal qdes;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(2);
        qdes = new MockQDES();
        vm.deal(address(this), 100000 ether);
        vm.deal(address(users[0]), 100000 ether);
        vm.deal(address(users[1]), 100000 ether);
        vm.warp(1000000);
        qdes.start();
        vm.warp(1000000 + 86400 / 2);
    }

    function testCurrentPriceGas() public {
        qdes.currentPrice();
    }

    function testPurchaseOneGas() public {
        qdes.purchase{value: qdes.currentPrice() * 1}(1);
    }

    function testPurchaseTenGas() public {
        qdes.purchase{value: qdes.currentPrice() * 10}(10);
    }
}
