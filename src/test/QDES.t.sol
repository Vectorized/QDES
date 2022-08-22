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
        assertEq(qdes.qdesLastPrice(), 0);
    }
    
    function testLastTimestampNotStarted() public {
        assertEq(qdes.qdesLastTimestamp(), 0);
    }
    
    function testCurrentPriceNotStarted() public {
        assertEq(qdes.qdesCurrentPrice(), 0);
    }

    function testLastPriceStarted() public {
        qdes.start();
        assertEq(qdes.qdesLastPrice(), qdes.qdesStartingPrice());
    }

    function testLastTimestampStarted() public {
        vm.warp(123456789);
        qdes.start();
        assertEq(qdes.qdesLastTimestamp(), 123456789);
    }

    function testCurrentPriceStarted() public {
        qdes.start();
        assertEq(qdes.qdesCurrentPrice(), qdes.qdesStartingPrice());
    }

    function testCannotPurchaseIfNotStarted() public {
        vm.expectRevert(QDES.QDESNotStarted.selector);
        qdes.purchase{value: 10}(1);
    }

    function testCannotPurchaseIfUnderpaid() public {
        qdes.start();
        vm.expectRevert(QDES.QDESInsufficientPayment.selector);
        qdes.purchase{value: 0}(1);
        uint256 price = qdes.qdesCurrentPrice();
        vm.expectRevert(QDES.QDESInsufficientPayment.selector);
        qdes.purchase{value: price - 1}(1);
    }

    function testCannotPurchaseZeroQuantity() public {
        qdes.start();
        uint256 price = qdes.qdesCurrentPrice();
        vm.expectRevert(QDES.QDESPurchaseZeroQuantity.selector);
        qdes.purchase{value: price}(0);
    }

    function testOverpayRefunds() public {
        vm.startPrank(users[0]);
        uint256 expectedBalance;
        uint256 price;
        uint256 initialBalance = address(users[0]).balance;

        qdes.start();
        price = qdes.qdesCurrentPrice();
        qdes.purchase{value: price}(1);

        expectedBalance = initialBalance - price;
        assertEq(address(users[0]).balance, expectedBalance);

        price = qdes.qdesCurrentPrice();
        qdes.purchase{value: price + 1}(1);
        expectedBalance = expectedBalance - price;
        assertEq(address(users[0]).balance, expectedBalance);

        vm.stopPrank();
    }

    function testExponentialSurge() public {
        uint256 price;
        qdes.start();
        price = qdes.qdesCurrentPrice();
        uint256 quantity = 7;
        uint256 expectedNextPrice = price;
        uint256 surgeNumerator = qdes.qdesSurgeNumerator();
        uint256 surgeDenominator = qdes.qdesSurgeDenominator();

        for (uint256 i; i < quantity; ++i) {
            expectedNextPrice = expectedNextPrice * surgeNumerator / surgeDenominator;
        }
        qdes.purchase{value: price * quantity}(quantity);
        assertEq(qdes.qdesCurrentPrice(), qdes.qdesLastPrice());
        assertEq(qdes.qdesCurrentPrice(), expectedNextPrice);
    }

    function testQuadraticDecay() public {
        vm.warp(1000000);
        qdes.start();
        uint256 startPrice = qdes.qdesCurrentPrice();
        vm.warp(1000000 + 86400 / 2);
        uint256 halfDecayedPrice = qdes.qdesCurrentPrice();
        assertLt(halfDecayedPrice, (startPrice + qdes.qdesBottomPrice()) / 2);
        assertGt(halfDecayedPrice, qdes.qdesBottomPrice());
        vm.warp(1000000 + 86400 - 1);
        uint256 almostFullDecayedPrice = qdes.qdesCurrentPrice();
        assertLt(almostFullDecayedPrice, halfDecayedPrice);
        assertGt(almostFullDecayedPrice, qdes.qdesBottomPrice());
        vm.warp(1000000 + 86400);
        assertEq(qdes.qdesCurrentPrice(), qdes.qdesBottomPrice());
        vm.warp(1000000 + 86400 + 1);
        assertEq(qdes.qdesCurrentPrice(), qdes.qdesBottomPrice());
        vm.warp(1000000 + 86400 + 10000000);
        assertEq(qdes.qdesCurrentPrice(), qdes.qdesBottomPrice());
    }

    function testQuadraticDecayExponentialSurge() public {
        uint256 price;
        vm.warp(1000000);
        qdes.start();
        vm.warp(1000000 + 86400 / 2);
        price = qdes.qdesCurrentPrice();
        uint256 quantity = 7;
        qdes.purchase{value: price * quantity}(quantity);
        uint256 expectedNextPrice = price;
        uint256 surgeNumerator = qdes.qdesSurgeNumerator();
        uint256 surgeDenominator = qdes.qdesSurgeDenominator();

        for (uint256 i; i < quantity; ++i) {
            expectedNextPrice = expectedNextPrice * surgeNumerator / surgeDenominator;
        }
        assertEq(qdes.qdesCurrentPrice(), expectedNextPrice);
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

    function testCurrentPriceGas() public view {
        qdes.qdesCurrentPrice();
    }

    function testPurchaseOneGas() public {
        qdes.purchase{value: qdes.qdesCurrentPrice() * 1}(1);
    }

    function testPurchaseTenGas() public {
        qdes.purchase{value: qdes.qdesCurrentPrice() * 10}(10);
    }
}
