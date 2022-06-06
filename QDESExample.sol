// SPDX-License-Identifier: MIT
// Creator: vectorized.eth

pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import "erc721a/contracts/ERC721A.sol";
import "./QDES.sol";

contract QDESExample is ERC721A, Ownable, QDES {

    constructor() ERC721A("QDESExample", "QDES") {}

    function qdesSurgeNumerator() public view virtual returns (uint64) {
        return 101;
    }

    function qdesSurgeDenominator() public view virtual returns (uint64) {
        return 100;
    }

    function qdesDecayTime() public view virtual returns (uint64) {
        return 86400;
    }

    function qdesStartingPrice() public view virtual returns (uint192) {
        return 80000000000000000;
    }

	function qdesBottomPrice() public view virtual returns (uint192) {
        return 50000000000000000;
    }

    function startSale() external onlyOwner {
    	_qdesStart();
    }

    function mint(uint256 quantity) external payable {
        _safeMint(msg.sender, quantity);
        
        // This will automatically charge payment, refund excess, 
        // and re-adjust prices.
        _qdesPurchase(quantity);
    }
}