// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import {QDES} from "../../QDES.sol";

contract QDESMock is QDES {

    function start() external {
        _qdesStart();
    }

    function purchase(uint256 quantity) external payable {
        _qdesPurchase(quantity);
    }
}
