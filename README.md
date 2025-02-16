# Sirio Finance Protocol

The Sirio Finance Protocol is an Evm compatibale lendinding and borrowing platform deployed on Hedera Hashgraph. Through the SFProtocol contracts, users on the blockchain can either _supply_ assets (such as HBAR or ERC-20/HST tokens) and receive SFP tokens/shares of the platform, or _borrow_ assets while using other assets as collateral. The Sirio Token contracts track these balances and automatically adjust interest rates for borrowers based on supply and demand dynamics.

### Essential Reading

- The [Sirio Hub](https://linktr.ee/sirio.finance), which outlines how Sirio Finance operates.
- The [Sirio Finance Protocol Specification](https://astrid.gitbook.io/sirio), which explains the protocol's mechanics in straightforward terms.

For inquiries or discussions related to Sirio Finance, feel free to join our community on [Discord](https://discord.com/invite/D5WJeGP7Dr).

# Contracts Overview

Here’s a brief overview of the core contracts powering the Sirio Finance protocol:

<dl>
<dt><strong>SFPToken and SFHbar</strong></dt>
  <dd>These are the core Sirio Finance supported tokens (SFPs), handling lending, borrowing, withdraw, liquidation functions. The <strong>SFPToken</strong> and <strong>SFHbar</strong> contracts contain the foundational logic, they provide specific interfaces for ERC-20/HST tokens and HBAR (native), respectively. Each contract represents ownership in the market and is associated with an interest rate model. These tokens allow users to supply, redeem (withdraw capital), borrow, liquidate, and repay borrowed assets. SFPToken contracts adhere to ERC-20/HST standards.</dd>

</dl>

<dl>
  <dt><strong>Market Position Manager</strong></dt>
  <dd>This contract enforces the protocol's risk management parameters, ensuring users maintain sufficient collateral across all tokens. It disallows risky actions that could threaten the stability of the system, such as borrowing/redeeming without sufficient collateral.</dd>

</dl>

<dl>
  <dt><strong>InterestRateModel</strong></dt>
  <dd>Contracts that determine interest rates algorithmically based on the market’s utilization. The higher the demand for borrowing relative to the supply, the higher the interest rates will be.</dd>
</dl>

<dl>
  <dt><strong>Oracle (Supra Oracle Integration) and Time Weighted Average Price Oracle (TWAP)</strong></dt>
  <dd>Sirio Finance integrates with <strong>Supra Oracles</strong> to securely retrieve real-time price data for all assets in the protocol. Supra Oracles provide decentralized price feeds, ensuring reliable and accurate asset valuations across different markets, whether HBAR, ERC-20 tokens, or other assets. In addition we have a TWAP backup oracle in case Supra goes down, so we can get prices for affected assets.</dd>
</dl>

<dl>
  <dt><strong>Oppenzeppelin, SafeToken, Upgradables</strong></dt>
  <dd>libraries designed for secure interaction with ERC-20 tokens, ensuring proper handling of token interactions and security.</dd>
</dl>

# Audit

Here is the [Audit](https://www.quillaudits.com/leaderboard/sirio-finance) from QuillAudits, ensuring proper and safe Smart Contract logic, checking for vulnerabilities and exploits.

# Installation

To set up and run Sirio Finance locally, clone the repository from GitHub and install the required dependencies. Make sure you have [Yarn](https://yarnpkg.com/lang/en/docs/install/) or [npm](https://docs.npmjs.com/cli/install) installed.

# Tests

In order to run Unit and Fuzzing tests follow this guide.

Run tests: `forge test -vvv`

Generate Coverage Report: `forge coverage --ir-minimum --report lcov`

This generates a lcov.info file and that can be used to display code coverage with:
`genhtml --ignore-errors inconsistent,corrupt,category --branch-coverage -o coverage_html lcov.info`

Now head to the coverage_html folder and then open index.html

# Suported Tokens

- [HBAR](https://hashscan.io/mainnet/token/0.0.1456986)
- [HBARX](https://hashscan.io/mainnet/token/0.0.834116)
- [USDC](https://hashscan.io/mainnet/token/0.0.456858)
- [SAUCE](https://hashscan.io/mainnet/token/0.0.731861)
- [XSAUCE](https://hashscan.io/mainnet/token/0.0.1460200)
- [PACK](https://hashscan.io/mainnet/token/0.0.4794920)
- [HSUITE](https://hashscan.io/mainnet/token/0.0.786931)
