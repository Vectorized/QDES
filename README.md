# QDES

Quadratic Decay Exponential Surge (QDES), is a simple adaptive price mechanism for selling NFTs.

When the demand is high, the price of each NFT increases.

When the demand is low, the price of each NFT decreases.

It is an approximate version of [Constant Rate Issuance Sales Protocol (CRISP)](https://www.paradigm.xyz/2022/01/constant-rate-issuance-sales-protocol).

## Benefits

- Generalizable to projects. 

  - All popularity levels. 
  - All mint periods, be it an hour to years.
  - All EVM compatible blockchains, as it uses `block.timestamp` instead of `block.number`.

- Enable price discovery.

- FUD resistant. 

  - Dutch Auctions starting at high prices are prone to FUD.
  - QDES allows market to decide.

- Minimal gas fees.

  - Only one `SLOAD` and `SSTORE` overhead per tx.

- Simple.

  - One transaction. No need for separate push or pull refund step.

- Flexible.

  - Function overloading API allows you to replace constants with functions.

## Usage

```solidity

pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import "erc721a/contracts/ERC721A.sol";
import "./QDES.sol";

contract Something is ERC721A, Ownable, QDES {
    constructor() ERC721A("Something", "SMTH") {}

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
```

## Recommendations

Because the price can fluctuate upwards, your UI must include an extra field to allow users to specify the maximum price per token (e.g. 2x the currentPrice).

## Contributing

1. Fork the Project
2. Create your Feature Branch (git checkout -b feature/AmazingFeature)
3. Commit your Changes (git commit -m 'Add some AmazingFeature')
4. Push to the Branch (git push origin feature/AmazingFeature)
5. Open a Pull Request

### Running tests locally

This repo uses [Foundry](https://github.com/gakonst/foundry).

- `forge install`
- `forge test`

## Roadmap

- Create Python simulation (preferably agent based).
- Create a writeup on the logic behind it.
- Make a sample NFT contract that uses it.
- Make a sample frontend UI to demonstrate how to implement it.
- Make ERC20 version.

Feel free to help on any of the points. 

## Disclaimer

This is **experimental software** and is provided on an "as is" and "as available" basis.

The code is still under heavy development and testing, and is not audited.  

The author(s) will not be liable for any damages or losses.

## License

MIT