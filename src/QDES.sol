// SPDX-License-Identifier: MIT
// Creator: vectorized.eth

pragma solidity ^0.8.4;

/**
 * @dev Quadratic Decay Exponential Surge (QDES)
 *
 * A mechanism to sell NFTs with adaptive pricing based on demand pressure.
 */
contract QDES {
    /**
     * Cannot purchase zero tokens.
     */
    error PurchaseZeroQuantity();

    /**
     * Insufficient payment.
     */
    error InsufficientPayment();

    /**
     * Unable to refund excess payment.
     */
    error RefundFailed();

    /**
     * Not started.
     */
    error NotStarted();

    uint256 private _qdesState;

    constructor() {}

    /**
     * @dev Returns the growth numerator (default: `101`).
     * 
     * Override this function to return a different value.
     */
    function _qdesGrowthNumerator() internal view virtual returns (uint64) {
        return 101;
    }

    /**
     * @dev Returns the growth denominator (default: `100`).
     * 
     * Override this function to return a different value.
     */
    function _qdesGrowthDenominator() internal view virtual returns (uint64) {
        return 100;
    }

    /**
     * @dev Returns the decay time (default: `86400`).
     * 
     * Override this function to return a different value.
     */
    function _qdesDecayTime() internal view virtual returns (uint64) {
        return 86400;
    }

    /**
     * @dev Returns the starting price (default: `1 ether`).
     * 
     * Override this function to return a different value.
     */
    function _qdesStartingPrice() internal view virtual returns (uint192) {
        return 1000000000000000000;
    }

    /**
     * @dev Returns the bottom price (default: `0.5 ether`).
     * 
     * Override this function to return a different value.
     */
    function _qdesBottomPrice() internal view virtual returns (uint192) {
        return 500000000000000000;
    }

    /**
     * @dev Starts the QDES algorithm.
     */
    function _qdesStart() internal {
        uint256 startingPrice = _qdesStartingPrice();
        assembly {
            sstore(_qdesState.slot, or(shl(64, startingPrice), timestamp()))
        }
    }

    /**
     * @dev Returns the previous purchase timestamp.
     */
    function _qdesLastTimestamp() internal view returns (uint64 result) {
        assembly {
            result := and(sload(_qdesState.slot), 0xffffffffffffffff)
        }
    }

    /**
     * @dev Returns the previous purchase price per token.
     */
    function _qdesLastPrice() internal view returns (uint192 result) {
        assembly {
            result := shr(64, sload(_qdesState.slot))
        }
    }

    /**
     * @dev Returns the current purchase price per token.
     *
     * The price decays quadratically from `_qdesLastPrice()` to `_qdesBottomPrice()` as
     * `block.timestamp - _qdesLastTimestamp()` approaches `_qdesDecayTime()`.
     */
    function _qdesCurrentPrice() internal view returns (uint192 currentPrice) {
        uint256 decayTime = _qdesDecayTime();
        uint256 bottomPrice = _qdesBottomPrice();
        
        assembly {
            let currentTimestamp := timestamp()

            // Unpack the state.
            let lastState := sload(_qdesState.slot)
            let lastTimestamp := and(lastState, 0xffffffffffffffff)
            let lastPrice := shr(64, lastState)

            // Quadratic decay.

            // timeDiff = max(currentTimestamp - lastTimestamp, 0)
            let timeDiff := mul(gt(currentTimestamp, lastTimestamp), 
                sub(currentTimestamp, lastTimestamp))
            // priceDiff = max(lastPrice - bottomPrice, 0)
            let priceDiff := mul(gt(lastPrice, bottomPrice), sub(lastPrice, bottomPrice))
            
            currentPrice := bottomPrice
            if lt(timeDiff, decayTime) {
                // p = priceDiff * timeDiff / decayTime
                let p := div(mul(priceDiff, timeDiff), decayTime)
                // currentPrice = lastPrice - (2 * p) + (p * timeDiff / decayTime)
                currentPrice := add(sub(sub(lastPrice, p), p), div(mul(p, timeDiff), decayTime))    
            }
            
        }
    }

    /**
     * @notice Returns the previous purchase timestamp.
     *
     * @dev The previous timestamp can be useful to estimate a max bid price per token.
     */
    function qdesLastTimestamp() public view returns (uint64) {
        return _qdesLastTimestamp();
    }

    /**
     * @notice Returns the current purchase price per token.
     *
     * @dev This current price is essential for UI, and is thus exposed as a public function.
     */
    function qdesCurrentPrice() public view returns (uint192) {
        return _qdesCurrentPrice();
    }

    /**
     * @dev Purchase `quantity` tokens.
     *
     * This function is to be called inside the minting function.
     *
     * Each token purchased multiplies `_qdesLastPrice()` by 
     * `_qdesGrowthNumerator() / _qdesGrowthDenominator()`, 
     * and will only affect the price paid in future purchase transactions.
     *
     * All the tokens will be charged at `_qdesCurrentPrice()` at the start
     * of the function. This incentivises bulk purchases to avoid incuring
     * exponentially increasing unit prices, reducing the network load.
     * 
     * If the `msg.value` is greater or equal to the required payment, 
     * `quantity * (_qdesCurrentPrice() * scaleNumerator / scaleDenominator)`,
     * the excess is refunded.
     * 
     * Otherwise, the transaction reverts.
     */
    function _qdesPurchase(
        uint256 quantity,
        uint256 scaleNumerator,
        uint256 scaleDenominator
    ) internal {
        if (quantity == 0) revert PurchaseZeroQuantity();
        if (_qdesState == 0) revert NotStarted();

        uint256 currentPrice = _qdesCurrentPrice();

        uint256 requiredPayment = quantity * (currentPrice * scaleNumerator / scaleDenominator);
        if (msg.value < requiredPayment) revert InsufficientPayment();

        uint256 growthNumerator = _qdesGrowthNumerator();
        uint256 growthDenominator = _qdesGrowthDenominator();
        
        unchecked {
            // Exponential surge.
            assembly {
                let nextPrice := currentPrice
                for { let i := 0 } lt(i, quantity) { i := add(i, 1) } {
                    nextPrice := div(mul(nextPrice, growthNumerator), growthDenominator)
                }
                sstore(_qdesState.slot, or(shl(64, nextPrice), timestamp()))
            }

            if (msg.value > requiredPayment) {
                uint256 refund = msg.value - requiredPayment;
                (bool sent, ) = msg.sender.call{value: refund}("");
                if (!sent) revert RefundFailed();
            }
        }
    }

    /**
     * @dev Equivalent to `_qdesPurchase(quantity, 1, 1)`.
     */
    function _qdesPurchase(uint256 quantity) internal {
        _qdesPurchase(quantity, 1, 1);
    }
}