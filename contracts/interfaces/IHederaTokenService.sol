// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.25;

interface IHederaTokenService {
    /**
     * @notice Transfers cryptocurrency among two or more accounts by adjusting their balances.
     * @dev Each transfer list can specify up to 10 adjustments. The amounts list must sum to zero.
     * Negative amounts are withdrawn, and positive amounts are added.
     * The transaction must be signed by all sending accounts and receiving accounts if required.
     * @param accountID The Account ID, as a solidity address, that sends/receives cryptocurrency or tokens.
     * @param amount The amount of the lowest denomination of the given token that the account sends (negative)
     * or receives (positive).
     */
    struct AccountAmount {
        address accountID;
        int64 amount;
    }

    /**
     * @notice Transfers NFTs between sender and receiver accounts.
     * @param senderAccountID The address of the sender.
     * @param receiverAccountID The address of the receiver.
     * @param serialNumber The serial number of the NFT.
     */
    struct NftTransfer {
        address senderAccountID;
        address receiverAccountID;
        int64 serialNumber;
    }

    /**
     * @notice List of token transfers for fungible and non-fungible tokens.
     * @param token The ID of the token as a solidity address.
     * @param transfers List of AccountAmounts for fungible token transfers.
     * @param nftTransfers List of NftTransfers for non-fungible token transfers.
     */
    struct TokenTransferList {
        address token;
        AccountAmount[] transfers;
        NftTransfer[] nftTransfers;
    }

    /**
     * @notice Expiry properties of a Hedera token.
     * @param second The epoch second at which the token should expire.
     * @param autoRenewAccount ID of an account automatically charged to renew the token's expiration.
     * @param autoRenewPeriod The interval at which the auto-renew account will be charged.
     */
    struct Expiry {
        uint32 second;
        address autoRenewAccount;
        uint32 autoRenewPeriod;
    }

    /**
     * @notice Defines a key that can either be a public key or a smart contract ID.
     * @param inheritAccountKey If true, the key of the calling Hedera account will be inherited.
     * @param contractId Smart contract instance authorized as if it had signed with a key.
     * @param ed25519 Ed25519 public key bytes.
     * @param ECDSA_secp256k1 Compressed ECDSA(secp256k1) public key bytes.
     * @param delegatableContractId A smart contract ID authorized to perform key actions.
     */
    struct KeyValue {
        bool inheritAccountKey;
        address contractId;
        bytes ed25519;
        bytes ECDSA_secp256k1;
        address delegatableContractId;
    }

    /**
     * @notice Represents a key and its associated type for a token.
     * @param keyType Bit field representing the key type.
     * @param key The key value set for the token.
     */
    struct TokenKey {
        // bit field representing the key type. Keys of all types that have corresponding bits set to 1
        // will be created for the token.
        // 0th bit: adminKey
        // 1st bit: kycKey
        // 2nd bit: freezeKey
        // 3rd bit: wipeKey
        // 4th bit: supplyKey
        // 5th bit: feeScheduleKey
        // 6th bit: pauseKey
        // 7th bit: ignored
        uint keyType;
        KeyValue key;
    }

    /**
     * @notice Basic properties of a Hedera Token.
     * @param name Publicly visible name of the token.
     * @param symbol Publicly visible token symbol.
     * @param treasury The treasury account ID for the token.
     * @param memo Memo associated with the token.
     * @param tokenSupplyType Indicates if the token supply type is infinite.
     * @param maxSupply Maximum number of tokens in circulation (for fungible tokens) or NFTs (for non-fungible tokens).
     * @param freezeDefault Default freeze status of accounts.
     * @param tokenKeys List of keys associated with the token.
     * @param expiry Expiry properties of the token.
     */
    struct HederaToken {
        string name;
        string symbol;
        address treasury;
        string memo;
        bool tokenSupplyType;
        uint32 maxSupply;
        bool freezeDefault;
        TokenKey[] tokenKeys;
        Expiry expiry;
    }

    /**
     * @notice Additional properties of a Hedera Token, including fees and status.
     * @param hedera The underlying Hedera token.
     * @param fixedFees Fixed fees collected during token transfers.
     * @param fractionalFees Fractional fees collected during token transfers.
     * @param royaltyFees Royalty fees collected during NFT transfers.
     * @param defaultKycStatus Indicates if KYC is applicable by default.
     * @param deleted Indicates if the token is deleted.
     * @param ledgerId ID of the network ledger.
     * @param pauseStatus Indicates if the token is paused.
     * @param totalSupply Total supply of the token.
     */
    struct TokenInfo {
        HederaToken hedera;
        FixedFee[] fixedFees;
        FractionalFee[] fractionalFees;
        RoyaltyFee[] royaltyFees;
        bool defaultKycStatus;
        bool deleted;
        string ledgerId;
        bool pauseStatus;
        uint64 totalSupply;
    }

    /**
     * @notice Properties of a fungible Hedera Token.
     * @param tokenInfo Shared token information.
     * @param decimals Number of decimal places a token is divisible by.
     */
    struct FungibleTokenInfo {
        TokenInfo tokenInfo;
        uint32 decimals;
    }

    /**
     * @notice Properties of a non-fungible Hedera Token.
     * @param tokenInfo Shared token information.
     * @param serialNumber Serial number of the NFT.
     * @param ownerId Account ID of the owner.
     * @param creationTime Epoch second at which the token was created.
     * @param metadata Metadata of the NFT.
     * @param spenderId Account ID with spending permissions on the NFT.
     */
    struct NonFungibleTokenInfo {
        TokenInfo tokenInfo;
        int64 serialNumber;
        address ownerId;
        int32 creationTime;
        bytes metadata;
        address spenderId;
    }

    /**
     * @notice A fixed number of units (hbar or token) to assess as a fee during a transfer of units of the token to which this fixed fee is attached.
     * @dev The denomination of the fee depends on the values of tokenId, useHbarsForPayment, and useCurrentTokenForPayment.
     * Exactly one of the values should be set.
     * @param amount The amount of the fee to assess.
     * @param tokenId Specifies ID of token that should be used for fixed fee denomination.
     * @param useHbarsForPayment Specifies this fixed fee should be denominated in Hbar.
     * @param useCurrentTokenForPayment Specifies this fixed fee should be denominated in the Token currently being created.
     * @param feeCollector The ID of the account to receive the custom fee, expressed as a solidity address.
     */
    struct FixedFee {
        uint32 amount;
        address tokenId;
        bool useHbarsForPayment;
        bool useCurrentTokenForPayment;
        address feeCollector;
    }

    /**
     * @notice A fraction of the transferred units of a token to assess as a fee.
     * @dev The amount assessed will never be less than the given minimumAmount, and never greater than the given maximumAmount.
     * The denomination is always units of the token to which this fractional fee is attached.
     * @param numerator A rational number's numerator, used to set the amount of a value transfer to collect as a custom fee.
     * @param denominator A rational number's denominator, used to set the amount of a value transfer to collect as a custom fee.
     * @param minimumAmount The minimum amount to assess.
     * @param maximumAmount The maximum amount to assess (zero implies no maximum).
     * @param netOfTransfers Specifies whether the fee should be calculated net of other transfers.
     * @param feeCollector The ID of the account to receive the custom fee, expressed as a solidity address.
     */
    struct FractionalFee {
        uint32 numerator;
        uint32 denominator;
        uint32 minimumAmount;
        uint32 maximumAmount;
        bool netOfTransfers;
        address feeCollector;
    }

    /**
     * @notice A fee to assess during a transfer that changes ownership of an NFT.
     * @dev Defines the fraction of the fungible value exchanged for an NFT that the ledger should collect as a royalty.
     * When the NFT sender does not receive any fungible value, the ledger will assess the fallback fee, if present, to the new NFT owner.
     * Royalty fees can only be added to tokens of type NON_FUNGIBLE_UNIQUE.
     * @param numerator A fraction's numerator of fungible value exchanged for an NFT to collect as royalty.
     * @param denominator A fraction's denominator of fungible value exchanged for an NFT to collect as royalty.
     * @param amount If present, the fee to assess to the NFT receiver when no fungible value is exchanged with the sender.
     * @param tokenId Specifies ID of token that should be used for fixed fee denomination.
     * @param useHbarsForPayment Specifies this fee should be denominated in Hbar.
     * @param feeCollector The ID of the account to receive the custom fee, expressed as a solidity address.
     */
    struct RoyaltyFee {
        uint32 numerator;
        uint32 denominator;
        uint32 amount;
        address tokenId;
        bool useHbarsForPayment;
        address feeCollector;
    }

    /**********************
     * Direct HTS Calls   *
     **********************/

    /**
     * @notice Initiates a token transfer.
     * @dev Executes a list of token transfers between specified accounts.
     * @param tokenTransfers The list of token transfers to perform.
     * @return responseCode The response code indicating the result of the transfer.
     * A successful transfer returns the status code 22.
     */
    function cryptoTransfer(
        TokenTransferList[] memory tokenTransfers
    ) external returns (int64 responseCode);

    /**
     * @notice Mints a specified amount of tokens to the treasury account.
     * @dev This function can mint fungible or non-fungible tokens (NFTs).
     * @param token The address of the token for which tokens are to be minted.
     * @param amount For fungible tokens, the amount to mint. For NFTs, set this to 0 and use `metadata` for NFT creation.
     * @param metadata The metadata for NFTs, used only when minting non-fungible tokens.
     * @return responseCode The response code indicating the status of the mint operation. SUCCESS is 22.
     * @return newTotalSupply The new total supply of the token.
     * @return serialNumbers Serial numbers of newly minted NFTs (empty for fungible tokens).
     */
    function mintToken(
        address token,
        uint64 amount,
        bytes[] memory metadata
    )
        external
        returns (
            int64 responseCode,
            uint64 newTotalSupply,
            int64[] memory serialNumbers
        );

    /**
     * @notice Burns a specified amount of tokens from the treasury account.
     * @dev This function can burn both fungible tokens and non-fungible tokens (NFTs).
     * @param token The address of the token to burn.
     * @param amount The amount of fungible tokens to burn (ignored for NFTs).
     * @param serialNumbers The serial numbers of NFTs to be burned (ignored for fungible tokens).
     * @return responseCode The response code indicating the status of the burn operation. SUCCESS is 22.
     * @return newTotalSupply The new total supply of the token after the burn operation.
     */
    function burnToken(
        address token,
        uint64 amount,
        int64[] memory serialNumbers
    ) external returns (int64 responseCode, uint64 newTotalSupply);

    /**
     * @notice Associates an account with multiple tokens.
     * @dev Must be signed by the account's key. Each token must be of type NON_FUNGIBLE_UNIQUE or FUNGIBLE_COMMON.
     * @param account The account to be associated with the specified tokens.
     * @param tokens The list of token addresses to associate with the account.
     * @return responseCode The response code indicating the status of the association. SUCCESS is 22.
     */
    function associateTokens(
        address account,
        address[] memory tokens
    ) external returns (int64 responseCode);
    /**
     * @notice Associates an account with a single token.
     * @dev A wrapper around `associateTokens` for associating a single token.
     * @param account The account to associate with the token.
     * @param token The token address to associate with the account.
     * @return responseCode The response code indicating the status of the association. SUCCESS is 22.
     */
    function associateToken(
        address account,
        address token
    ) external returns (int64 responseCode);

    /**
     * @notice Dissociates an account from multiple tokens.
     * @dev The account must have zero balances for the tokens being dissociated.
     * @param account The account to be dissociated from the specified tokens.
     * @param tokens The list of token addresses to dissociate from the account.
     * @return responseCode The response code indicating the status of the dissociation. SUCCESS is 22.
     */
    function dissociateTokens(
        address account,
        address[] memory tokens
    ) external returns (int64 responseCode);

    /**
     * @notice Dissociates an account from a single token.
     * @dev A wrapper around `dissociateTokens` for dissociating a single token.
     * @param account The account to dissociate from the token.
     * @param token The token address to dissociate from the account.
     * @return responseCode The response code indicating the status of the dissociation. SUCCESS is 22.
     */
    function dissociateToken(
        address account,
        address token
    ) external returns (int64 responseCode);

    /**
     * @notice Creates a fungible token with the specified properties.
     * @dev The initial total supply is sent to the treasury account.
     * @param token The basic properties of the token being created.
     * @param initialTotalSupply The initial supply of the token in the lowest denomination.
     * @param decimals The number of decimal places for the token.
     * @return responseCode The response code indicating the status of the token creation. SUCCESS is 22.
     * @return tokenAddress The address of the newly created token.
     */
    function createFungibleToken(
        HederaToken memory token,
        uint initialTotalSupply,
        uint decimals
    ) external payable returns (int64 responseCode, address tokenAddress);

    /**
     * @notice Creates a Fungible Token with the specified properties and custom fees.
     * @dev Mints tokens with fixed and fractional fees and sends the initial supply to the treasury account.
     * @param token The basic properties of the token being created.
     * @param initialTotalSupply Specifies the initial supply of tokens to be put in circulation, in the lowest denomination possible.
     * @param decimals The number of decimal places a token is divisible by.
     * @param fixedFees List of fixed fees to apply to the token.
     * @param fractionalFees List of fractional fees to apply to the token.
     * @return responseCode The response code for the status of the request. SUCCESS is 22.
     * @return tokenAddress The address of the newly created token.
     */
    function createFungibleTokenWithCustomFees(
        HederaToken memory token,
        uint initialTotalSupply,
        uint decimals,
        FixedFee[] memory fixedFees,
        FractionalFee[] memory fractionalFees
    ) external payable returns (int64 responseCode, address tokenAddress);

    /**
     * @notice Creates a Non-Fungible Unique Token with the specified properties.
     * @dev Mints non-fungible tokens with unique serial numbers and sends them to the treasury account.
     * @param token The basic properties of the token being created.
     * @return responseCode The response code for the status of the request. SUCCESS is 22.
     * @return tokenAddress The address of the newly created token.
     */
    function createNonFungibleToken(
        HederaToken memory token
    ) external payable returns (int64 responseCode, address tokenAddress);

    /**
     * @notice Creates a Non-Fungible Unique Token with the specified properties and custom fees.
     * @dev Mints non-fungible tokens with fixed and royalty fees.
     * @param token The basic properties of the token being created.
     * @param fixedFees List of fixed fees to apply to the token.
     * @param royaltyFees List of royalty fees to apply to the token.
     * @return responseCode The response code for the status of the request. SUCCESS is 22.
     * @return tokenAddress The address of the newly created token.
     */
    function createNonFungibleTokenWithCustomFees(
        HederaToken memory token,
        FixedFee[] memory fixedFees,
        RoyaltyFee[] memory royaltyFees
    ) external payable returns (int64 responseCode, address tokenAddress);

    /**********************
     * ABIV1 calls        *
     **********************/

    /**
     * @notice Initiates a Fungible Token Transfer.
     * @param token The ID of the token as a solidity address.
     * @param accountId List of account IDs to transfer to/from.
     * @param amount The amount to transfer from each account at the corresponding index.
     * @return responseCode The response code indicating the result of the transfer. SUCCESS is 22.
     */
    function transferTokens(
        address token,
        address[] memory accountId,
        int64[] memory amount
    ) external returns (int64 responseCode);

    /**
     * @notice Initiates a Non-Fungible Token (NFT) Transfer.
     * @param token The ID of the token as a solidity address.
     * @param sender List of NFT sender addresses.
     * @param receiver List of NFT receiver addresses.
     * @param serialNumber List of NFT serial numbers to transfer.
     * @return responseCode The response code indicating the result of the transfer. SUCCESS is 22.
     */
    function transferNFTs(
        address token,
        address[] memory sender,
        address[] memory receiver,
        int64[] memory serialNumber
    ) external returns (int64 responseCode);

    /**
     * @notice Transfers tokens between two accounts.
     * @param token The token to transfer to/from.
     * @param sender The sender for the transaction.
     * @param recipient The receiver of the transaction.
     * @param amount The amount to transfer. Must be a non-negative value.
     * @return responseCode The response code indicating the result of the transfer. SUCCESS is 22.
     */
    function transferToken(
        address token,
        address sender,
        address recipient,
        int64 amount
    ) external returns (int64 responseCode);

    /**
     * @notice Transfers an NFT between two accounts.
     * @param token The token to transfer to/from.
     * @param sender The sender of the NFT.
     * @param recipient The receiver of the NFT.
     * @param serialNumber The serial number of the NFT to transfer.
     * @return responseCode The response code indicating the result of the transfer. SUCCESS is 22.
     */
    function transferNFT(
        address token,
        address sender,
        address recipient,
        int64 serialNumber
    ) external returns (int64 responseCode);

    /**
     * @notice Allows spender to withdraw tokens from your account multiple times, up to the specified value amount.
     * @dev If this function is called again, it overwrites the current allowance with the new value.
     * Only applicable to fungible tokens.
     * @param token The Hedera token address for which approval is given.
     * @param spender The address authorized to spend tokens from the owner's account.
     * @param amount The maximum amount of tokens that can be spent by the spender.
     * @return responseCode The response code indicating the status of the approval operation. SUCCESS is 22.
     */
    function approve(
        address token,
        address spender,
        uint256 amount
    ) external returns (int64 responseCode);

    /**
     * @notice Returns the amount which spender is still allowed to withdraw from the owner's account.
     * @dev Only applicable to fungible tokens.
     * @param token The Hedera token address for which the allowance is being checked.
     * @param owner The address of the token owner.
     * @param spender The address of the spender.
     * @return responseCode The response code indicating the status of the allowance query. SUCCESS is 22.
     * @return allowance The remaining amount which the spender is still allowed to withdraw from the owner.
     */
    function allowance(
        address token,
        address owner,
        address spender
    ) external returns (int64 responseCode, uint256 allowance);

    /**
     * @notice Allows or reaffirms the approved address to transfer an NFT that the approved address does not own.
     * @dev Only applicable to non-fungible tokens (NFTs).
     * @param token The Hedera NFT token address to approve.
     * @param approved The new approved NFT controller. To revoke approvals, pass the zero address.
     * @param serialNumber The serial number of the NFT to approve.
     * @return responseCode The response code indicating the status of the approval operation. SUCCESS is 22.
     */
    function approveNFT(
        address token,
        address approved,
        int64 serialNumber
    ) external returns (int64 responseCode);

    /**
     * @notice Returns the approved address for a specific NFT.
     * @dev Only applicable to non-fungible tokens (NFTs).
     * @param token The Hedera NFT token address to check.
     * @param serialNumber The serial number of the NFT.
     * @return responseCode The response code indicating the status of the query. SUCCESS is 22.
     * @return approved The address approved for this NFT, or the zero address if no address is approved.
     */
    function getApproved(
        address token,
        int64 serialNumber
    ) external returns (int64 responseCode, address approved);

    /**
     * @notice Enables or disables approval for an operator to manage all of `msg.sender`'s assets.
     * @dev Only applicable to non-fungible tokens (NFTs).
     * @param token The Hedera NFT token address to approve.
     * @param operator The address to add or remove as an authorized operator.
     * @param approved True to approve the operator, false to revoke approval.
     * @return responseCode The response code indicating the status of the approval operation. SUCCESS is 22.
     */
    function setApprovalForAll(
        address token,
        address operator,
        bool approved
    ) external returns (int64 responseCode);

    /**
     * @notice Queries if an address is an authorized operator for another address.
     * @dev Only applicable to non-fungible tokens (NFTs).
     * @param token The Hedera NFT token address to check.
     * @param owner The address of the NFT owner.
     * @param operator The address of the operator.
     * @return responseCode The response code indicating the status of the query. SUCCESS is 22.
     * @return approved True if `operator` is an approved operator for `owner`, false otherwise.
     */
    function isApprovedForAll(
        address token,
        address owner,
        address operator
    ) external returns (int64 responseCode, bool approved);

    /**
     * @notice Queries if a token account is frozen.
     * @param token The address of the token to check.
     * @param account The account address associated with the token.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     * @return frozen True if the account is frozen for the token.
     */
    function isFrozen(
        address token,
        address account
    ) external returns (int64 responseCode, bool frozen);

    /**
     * @notice Queries if a token account has KYC granted.
     * @param token The address of the token to check.
     * @param account The account address associated with the token.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     * @return kycGranted True if the account has KYC granted for the token.
     */
    function isKyc(
        address token,
        address account
    ) external returns (int64 responseCode, bool kycGranted);

    /**
     * @notice Deletes a token.
     * @param token The address of the token to be deleted.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function deleteToken(address token) external returns (int64 responseCode);

    /**
     * @notice Queries the custom fees of a token.
     * @param token The address of the token to check.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     * @return fixedFees A set of fixed fees for the token.
     * @return fractionalFees A set of fractional fees for the token.
     * @return royaltyFees A set of royalty fees for the token.
     */
    function getTokenCustomFees(
        address token
    )
        external
        returns (
            int64 responseCode,
            FixedFee[] memory fixedFees,
            FractionalFee[] memory fractionalFees,
            RoyaltyFee[] memory royaltyFees
        );

    /**
     * @notice Queries the default freeze status of a token.
     * @param token The address of the token to check.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     * @return defaultFreezeStatus True if the token's default freeze status is frozen.
     */
    function getTokenDefaultFreezeStatus(
        address token
    ) external returns (int64 responseCode, bool defaultFreezeStatus);

    /**
     * @notice Queries the default KYC status of a token.
     * @param token The address of the token to check.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     * @return defaultKycStatus True if the token's default KYC status is KycNotApplicable, false if Revoked.
     */
    function getTokenDefaultKycStatus(
        address token
    ) external returns (int64 responseCode, bool defaultKycStatus);

    /**
     * @notice Queries the expiry information of a token.
     * @param token The address of the token to check.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     * @return expiry The expiry information for the token.
     */
    function getTokenExpiryInfo(
        address token
    ) external returns (int64 responseCode, Expiry memory expiry);

    /**
     * @notice Queries information about a fungible token.
     * @param token The address of the token to check.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     * @return fungibleTokenInfo Information about the fungible token.
     */
    function getFungibleTokenInfo(
        address token
    )
        external
        returns (
            int64 responseCode,
            FungibleTokenInfo memory fungibleTokenInfo
        );

    /**
     * @notice Queries general information about a token.
     * @param token The address of the token to check.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     * @return tokenInfo General information about the token.
     */
    function getTokenInfo(
        address token
    ) external returns (int64 responseCode, TokenInfo memory tokenInfo);

    /**
     * @notice Queries the key of a token.
     * @param token The address of the token to check.
     * @param keyType The type of key to retrieve.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     * @return key The key value associated with the key type.
     */
    function getTokenKey(
        address token,
        uint keyType
    ) external returns (int64 responseCode, KeyValue memory key);

    /**
     * @notice Queries information about a non-fungible token (NFT).
     * @param token The address of the token to check.
     * @param serialNumber The serial number of the NFT to check.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     * @return nonFungibleTokenInfo Information about the non-fungible token.
     */
    function getNonFungibleTokenInfo(
        address token,
        int64 serialNumber
    )
        external
        returns (
            int64 responseCode,
            NonFungibleTokenInfo memory nonFungibleTokenInfo
        );

    /**
     * @notice Freezes a token account.
     * @param token The address of the token.
     * @param account The address of the account to freeze.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function freezeToken(
        address token,
        address account
    ) external returns (int64 responseCode);

    /**
     * @notice Unfreezes a token account.
     * @param token The address of the token.
     * @param account The address of the account to unfreeze.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function unfreezeToken(
        address token,
        address account
    ) external returns (int64 responseCode);

    /**
     * @notice Grants KYC to a token account.
     * @param token The address of the token.
     * @param account The account address to grant KYC.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function grantTokenKyc(
        address token,
        address account
    ) external returns (int64 responseCode);

    /**
     * @notice Revokes KYC from a token account.
     * @param token The address of the token.
     * @param account The account address to revoke KYC.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function revokeTokenKyc(
        address token,
        address account
    ) external returns (int64 responseCode);

    /**
     * @notice Pauses a token.
     * @param token The address of the token to be paused.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function pauseToken(address token) external returns (int64 responseCode);

    /**
     * @notice Unpauses a token.
     * @param token The address of the token to be unpaused.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function unpauseToken(address token) external returns (int64 responseCode);

    /**
     * @notice Wipes a fungible token from an account.
     * @param token The address of the token.
     * @param account The address of the account from which to wipe tokens.
     * @param amount The number of tokens to wipe.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function wipeTokenAccount(
        address token,
        address account,
        uint32 amount
    ) external returns (int64 responseCode);

    /**
     * @notice Wipes non-fungible tokens from an account.
     * @param token The address of the token.
     * @param account The address of the account from which to wipe NFTs.
     * @param serialNumbers The serial numbers of the NFTs to wipe.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function wipeTokenAccountNFT(
        address token,
        address account,
        int64[] memory serialNumbers
    ) external returns (int64 responseCode);

    /**
     * @notice Updates information for a token.
     * @param token The address of the token.
     * @param tokenInfo The new token information to be updated.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function updateTokenInfo(
        address token,
        HederaToken memory tokenInfo
    ) external returns (int64 responseCode);

    /**
     * @notice Updates the expiry information of a token.
     * @param token The address of the token.
     * @param expiryInfo The new expiry information for the token.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function updateTokenExpiryInfo(
        address token,
        Expiry memory expiryInfo
    ) external returns (int64 responseCode);

    /**
     * @notice Updates the keys of a token.
     * @param token The address of the token.
     * @param keys The new keys for the token.
     * @return responseCode The response code indicating the status of the request. SUCCESS is 22.
     */
    function updateTokenKeys(
        address token,
        TokenKey[] memory keys
    ) external returns (int64 responseCode);
}
