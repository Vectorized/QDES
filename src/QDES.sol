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
    error QDESPurchaseZeroQuantity();

    /**
     * Insufficient payment.
     */
    error QDESInsufficientPayment();

    /**
     * Unable to refund excess payment.
     */
    error QDESRefundFailed();

    /**
     * Not started.
     */
    error QDESNotStarted();

    /**
     * @dev `keccak256("QDES_STATE_SLOT")`.
     */
    uint256 private constant QDES_STATE_SLOT = 0xe1ad96ab4a2a322eaedcc880654f108e9d75d8996494b0a370912ff23b0eaa63;


    constructor() {}

    /**
     * @dev Returns the surge numerator (default: `101`).
     * 
     * Override this function to return a different value.
     */
    function qdesSurgeNumerator() public view virtual returns (uint64) {
        return 101;
    }

    /**
     * @dev Returns the surge denominator (default: `100`).
     * 
     * Override this function to return a different value.
     */
    function qdesSurgeDenominator() public view virtual returns (uint64) {
        return 100;
    }

    /**
     * @dev Returns the decay time (default: `86400`).
     * 
     * Override this function to return a different value.
     */
    function qdesDecayTime() public view virtual returns (uint64) {
        return 86400;
    }

    /**
     * @dev Returns the starting price (default: `1 ether`).
     * 
     * Override this function to return a different value.
     */
    function qdesStartingPrice() public view virtual returns (uint192) {
        return 1000000000000000000;
    }

    /**
     * @dev Returns the bottom price (default: `0.5 ether`).
     * 
     * Override this function to return a different value.
     */
    function qdesBottomPrice() public view virtual returns (uint192) {
        return 500000000000000000;
    }

    /**
     * @dev Starts the QDES algorithm.
     */
    function _qdesStart() internal {
        uint256 startingPrice = qdesStartingPrice();
        /// @solidity memory-safe-assembly
        assembly {
            sstore(QDES_STATE_SLOT, or(shl(64, startingPrice), timestamp()))
        }
    }

    /**
     * @dev Returns the previous purchase timestamp.
     */
    function qdesLastTimestamp() public view returns (uint64 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := sload(QDES_STATE_SLOT)
        }
    }

    /**
     * @dev Returns the previous purchase price per token.
     */
    function qdesLastPrice() public view returns (uint192 result) {
        /// @solidity memory-safe-assembly
        assembly {
            result := shr(64, sload(QDES_STATE_SLOT))
        }
    }

    /**
     * @dev Returns the current purchase price per token.
     *
     * The price decays quadratically from `qdesLastPrice()` to `qdesBottomPrice()` as
     * `block.timestamp - qdesLastTimestamp()` approaches `qdesDecayTime()`.
     */
    function qdesCurrentPrice() public view returns (uint192 currentPrice) {
        uint256 decayTime = qdesDecayTime();
        uint256 bottomPrice = qdesBottomPrice();
        
        /// @solidity memory-safe-assembly
        assembly {
            let blockTimestamp := timestamp()

            // Unpack the state.
            let lastState := sload(QDES_STATE_SLOT)
            let lastTimestamp := and(lastState, 0xffffffffffffffff)
            let lastPrice := shr(64, lastState)

            // Quadratic decay.

            // timeDiff = max(blockTimestamp - lastTimestamp, 0)
            let timeDiff := mul(gt(blockTimestamp, lastTimestamp), sub(blockTimestamp, lastTimestamp))
            // priceDiff = max(lastPrice - bottomPrice, 0)
            let priceDiff := mul(gt(lastPrice, bottomPrice), sub(lastPrice, bottomPrice))
            
            // timeDiff = min(decayTime, timeDiff)
            timeDiff := sub(decayTime, mul(lt(timeDiff, decayTime), sub(decayTime, timeDiff)))
            
            // p = priceDiff * timeDiff / decayTime
            let p := div(mul(priceDiff, timeDiff), decayTime)
            // currentPrice = lastPrice - (2 * p) + (p * timeDiff / decayTime)
            currentPrice := add(sub(sub(lastPrice, p), p), div(mul(p, timeDiff), decayTime))    
        }
    }

    /**
     * @dev Purchase `quantity` tokens.
     *
     * This function is to be called inside the minting function.
     *
     * Each token purchased multiplies `qdesLastPrice()` by 
     * `qdesSurgeNumerator() / qdesSurgeDenominator()`, 
     * and will only affect the price paid in future purchase transactions.
     *
     * All the tokens will be charged at `qdesCurrentPrice()` at the start
     * of the function. This incentivises bulk purchases to avoid incuring
     * exponentially increasing unit prices, reducing the network load.
     * 
     * If the `msg.value` is greater or equal to the required payment, 
     * `quantity * (qdesCurrentPrice() * scaleNumerator / scaleDenominator)`,
     * the excess is refunded.
     * 
     * Otherwise, the transaction reverts.
     */
    function _qdesPurchase(
        uint256 quantity,
        uint256 scaleNumerator,
        uint256 scaleDenominator
    ) internal {
        if (quantity == 0) revert QDESPurchaseZeroQuantity();
        
        uint256 currentPrice = qdesCurrentPrice();
        uint256 currentState;

        assembly {
            currentState := sload(QDES_STATE_SLOT)
        }

        if (currentPrice == 0) if (currentState == 0) revert QDESNotStarted();        

        uint256 surgeNumerator = qdesSurgeNumerator();
        uint256 surgeDenominator = qdesSurgeDenominator();
        uint256 requiredPayment;

        /// @solidity memory-safe-assembly
        assembly {
            // Exponential surge.
            let price := div(mul(currentPrice, surgeNumerator), surgeDenominator)
            for { let i := sub(quantity, 1) } i { i := sub(i, 1) } {
                price := div(mul(price, surgeNumerator), surgeDenominator)
            }
            sstore(QDES_STATE_SLOT, or(shl(64, price), timestamp()))

            requiredPayment := mul(quantity, div(mul(currentPrice, scaleNumerator), scaleDenominator))
        }

        if (msg.value < requiredPayment) revert QDESInsufficientPayment();

        unchecked {
            if (msg.value > requiredPayment) {
                uint256 refund = msg.value - requiredPayment;
                (bool sent, ) = msg.sender.call{value: refund}("");
                if (!sent) revert QDESRefundFailed();
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