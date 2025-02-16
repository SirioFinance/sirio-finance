# TWAP ORACLE

## How `update` function works

Basically to get the price of the token, the price from the uniswap pool, should be read put two times. However, there is mechanisms in `update` function that protects from stale prices and resets price value if it is outdated.

1. Firstly, function checks if the pair is active, and if not it sets the initial values for `price0CumulativeLast`, `price1CumulativeLast` and `blockTimestampLast`. After it pair is become active but price is 0 till the second call of `update` function that can be performed after `updateIntervalMin` is passed.
2. If the pair is active the functions is retrive cumulative prices form the pool, and checs the elapsed time. If it less then `updateIntervalMin` call getting revert to avoid price manipulations. Otherwise if the timeElapsed is greater than `updateIntervalMax` the function resets the pair to inactive state and priceAverage values to zero.
3. If the pair condition described in (2) is not valid, it means that the timeElapsed since last update call is valid(between `updateIntervalMin` and `updateIntervalMax`).So the new `price0Average` and `price1Average` calculated and other values updated.

## How is script working

The current script is [here](./twapOracle.ts)

The script is working by periodically calling the `update` function. The one moment that should be looked carefully is call of `sync` function on the pool. This function is update the cumulative prices and blockTimestamp. It's normally happening if there are trades on the pool. But on Hedera some of the pools can be updated not quite often and `sync` should be called.

## Further improvements

1. Calling `update` functions only when it's needed by checking the price on other exchanges, centralized or on other chains(more source is better).
