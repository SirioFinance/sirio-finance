export const contractAbi = [
  {
    type: "function",
    name: "TIME_DELTA_ALLOWANCE",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "acceptOwnership",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "checkSupraSValueFeed",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "checkSupraSValueVerifier",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "initialize",
    inputs: [
      {
        name: "_supraSValueFeedStorage",
        type: "address",
        internalType: "address",
      },
      {
        name: "_supraSValueVerifier",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "owner",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "pendingOwner",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "proxiableUUID",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "bytes32",
        internalType: "bytes32",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "removeOldMerkleRoot",
    inputs: [
      {
        name: "timestamp",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "renounceOwnership",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "transferOwnership",
    inputs: [
      {
        name: "newOwner",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "updateSupraSValueFeed",
    inputs: [
      {
        name: "supraSValueFeed",
        type: "address",
        internalType: "contract ISupraSValueFeed",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "updateSupraSValueVerifier",
    inputs: [
      {
        name: "supraSvalueVerifier",
        type: "address",
        internalType: "contract ISupraSValueFeedVerifier",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "upgradeTo",
    inputs: [
      {
        name: "newImplementation",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "upgradeToAndCall",
    inputs: [
      {
        name: "newImplementation",
        type: "address",
        internalType: "address",
      },
      {
        name: "data",
        type: "bytes",
        internalType: "bytes",
      },
    ],
    outputs: [],
    stateMutability: "payable",
  },
  {
    type: "function",
    name: "verifyOracleProof",
    inputs: [
      {
        name: "_bytesProof",
        type: "bytes",
        internalType: "bytes",
      },
    ],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct SupraOraclePull.PriceData",
        components: [
          {
            name: "pairs",
            type: "uint256[]",
            internalType: "uint256[]",
          },
          {
            name: "prices",
            type: "uint256[]",
            internalType: "uint256[]",
          },
          {
            name: "decimal",
            type: "uint256[]",
            internalType: "uint256[]",
          },
        ],
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "verifyOracleProofV2",
    inputs: [
      {
        name: "_bytesProof",
        type: "bytes",
        internalType: "bytes",
      },
    ],
    outputs: [
      {
        name: "",
        type: "tuple",
        internalType: "struct SupraOraclePull.PriceInfo",
        components: [
          {
            name: "pairs",
            type: "uint256[]",
            internalType: "uint256[]",
          },
          {
            name: "prices",
            type: "uint256[]",
            internalType: "uint256[]",
          },
          {
            name: "timestamp",
            type: "uint256[]",
            internalType: "uint256[]",
          },
          {
            name: "decimal",
            type: "uint256[]",
            internalType: "uint256[]",
          },
          {
            name: "round",
            type: "uint256[]",
            internalType: "uint256[]",
          },
        ],
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "AdminChanged",
    inputs: [
      {
        name: "previousAdmin",
        type: "address",
        indexed: false,
        internalType: "address",
      },
      {
        name: "newAdmin",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "BeaconUpgraded",
    inputs: [
      {
        name: "beacon",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Initialized",
    inputs: [
      {
        name: "version",
        type: "uint8",
        indexed: false,
        internalType: "uint8",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "OwnershipTransferStarted",
    inputs: [
      {
        name: "previousOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "newOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "OwnershipTransferred",
    inputs: [
      {
        name: "previousOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "newOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "PriceUpdate",
    inputs: [
      {
        name: "pairs",
        type: "uint256[]",
        indexed: false,
        internalType: "uint256[]",
      },
      {
        name: "prices",
        type: "uint256[]",
        indexed: false,
        internalType: "uint256[]",
      },
      {
        name: "updateMask",
        type: "uint256[]",
        indexed: false,
        internalType: "uint256[]",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "SupraSValueFeedUpdated",
    inputs: [
      {
        name: "supraSValueFeedStorage",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "SupraSValueVerifierUpdated",
    inputs: [
      {
        name: "supraSValueVerifier",
        type: "address",
        indexed: false,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "Upgraded",
    inputs: [
      {
        name: "implementation",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "error",
    name: "DataNotVerified",
    inputs: [],
  },
  {
    type: "error",
    name: "IncorrectFutureUpdate",
    inputs: [
      {
        name: "FutureLengthInMsecs",
        type: "uint256",
        internalType: "uint256",
      },
    ],
  },
  {
    type: "error",
    name: "InvalidProof",
    inputs: [],
  },
  {
    type: "error",
    name: "RootIsSentinal",
    inputs: [],
  },
  {
    type: "error",
    name: "SentinalAlreadySet",
    inputs: [],
  },
  {
    type: "error",
    name: "ZeroAddress",
    inputs: [],
  },
];

export const oracleProof = [
  {
    type: "tuple",
    name: "OracleProofV2",
    components: [
      {
        type: "tuple[]",
        name: "data",
        components: [
          {
            type: "uint64",
            name: "committee_id",
          },
          {
            type: "bytes32",
            name: "root",
          },
          {
            type: "uint256[2]",
            name: "sigs",
          },
          {
            type: "tuple",
            name: "committee_data",
            components: [
              {
                type: "tuple[]",
                name: "committee_feed",
                components: [
                  {
                    type: "uint32",
                    name: "pair",
                  },
                  {
                    type: "uint128",
                    name: "price",
                  },
                  {
                    type: "uint64",
                    name: "timestamp",
                  },
                  {
                    type: "uint16",
                    name: "decimals",
                  },
                  {
                    type: "uint64",
                    name: "round",
                  },
                ],
              },
              {
                type: "bytes32[]",
                name: "proof",
              },
              {
                type: "bool[]",
                name: "flags",
              },
            ],
          },
        ],
      },
    ],
  },
];

export const OracleProofV2Inputs = [
  {
    type: "tuple",
    name: "OracleProofV2",
    components: [
      {
        type: "tuple[]",
        name: "data",
        components: [
          {
            type: "uint64",
            name: "committee_id",
          },
          {
            type: "bytes32",
            name: "root",
          },
          {
            type: "uint256[2]",
            name: "sigs",
          },
          {
            type: "tuple",
            name: "committee_data",
            components: [
              {
                type: "tuple[]",
                name: "committee_feed",
                components: [
                  {
                    type: "uint32",
                    name: "pair",
                  },
                  {
                    type: "uint128",
                    name: "price",
                  },
                  {
                    type: "uint64",
                    name: "timestamp",
                  },
                  {
                    type: "uint16",
                    name: "decimals",
                  },
                  {
                    type: "uint64",
                    name: "round",
                  },
                ],
              },
              {
                type: "bytes32[]",
                name: "proof",
              },
              {
                type: "bool[]",
                name: "flags",
              },
            ],
          },
        ],
      },
    ],
  },
];
