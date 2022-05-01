// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {QDES} from "../../QDES.sol";

contract MockQDES is QDES {

    function startingPrice() external view virtual returns (uint192) {
        return _qdesStartingPrice();
    }

    function bottomPrice() external view virtual returns (uint192) {
        return _qdesBottomPrice();
    }

    function currentPrice() external view virtual returns (uint192) {
        return _qdesCurrentPrice();
    }

    function start() external {
        _qdesStart();
    }
    
    function lastTimestamp() external view returns (uint64) {
        return _qdesLastTimestamp();
    }

    function lastPrice() external view returns (uint192) {
        return _qdesLastPrice();
    }

    function purchase(uint256 quantity) external payable {
        _qdesPurchase(quantity);
    }

    function surgeNumerator() external view returns (uint64) {
        return _qdesSurgeNumerator();
    }

    function surgeDenominator() external view returns (uint64) {
        return _qdesSurgeDenominator();
    }
}
