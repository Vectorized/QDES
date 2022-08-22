// SPDX-License-Identifier: MIT
// Creator: vectorized.eth

pragma solidity ^0.8.4;

import {QDES} from "../../QDES.sol";

contract MockQDES is QDES {

    function start() external {
        _qdesStart();
    }

    function purchase(uint256 quantity) external payable {
        _qdesPurchase(quantity);
    }
}
