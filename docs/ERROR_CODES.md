onlineTool: https://emn178.github.io/online-tools/keccak_256.html

## FileName: IBaseProtocol

| ErrorMethods                     | Sign       | Hash                                                             | Used in                                       |
| -------------------------------- | ---------- | ---------------------------------------------------------------- | --------------------------------------------- |
| InvaildSupplyAmount()            | 0x2595efce | 2595efceb4431b1f7d5a813d230c352209efcca8214753a23463ff26774b03dc | HBARProtocol,SFProtocolToken                  |
| LowShareAmount()                 | 0xc66b1466 | c66b1466f8f85c0c9e96f3069d3a3194bda95e3eeac2fed4dbe827ffb37b7efb | HBARProtocol,SFProtocolToken                  |
| InsuficientPoolAmountToBorrow()  | 0x35209a84 | 35209a8439d634f91c77c1ad72091f102c48e896f29a3bae98773cf004b7028a | HBARProtocol,SFProtocolToken                  |
| NotEnoughClaimableInterest()     | 0xc6ed40cc | c6ed40cc865c363efdba6a39fe9981ef8efef64e8f65a31328e5f0359bcba10c | HBARProtocol,SFProtocolToken                  |
| InsuficientBalanceForInterests() | 0xcd40ad2c | cd40ad2c5ac94d7e290ce3b3727906cca1613b707691b95aee8ed0cd41484256 | HBARProtocol,SFProtocolToken                  |
| InvalidRepayAmount()             | 0x3d56fe34 | 3d56fe34303941965edd824673d667627726005c8579d62475e06fbc1484c1d6 | HBARProtocol                                  |
| FailedWithdrawFunds()            | 0x69b00267 | 69b00267745ee835dc007be7f4f24aac1fe3f69fcc7949b7ca878c170e11c0fd | HBARProtocol                                  |
| FailedSendExcessBack()           | 0x871922c0 | 871922c0bb59c5d4a1b90afae3cd2626679d00f107f5fe6e190b9fb7813a5591 | HBARProtocol                                  |
| InvalidRedeemShareAmount()       | 0x75a2292c | 75a2292ce288a2e9dba8547161c5846ea35654f48b31e618276f9bbf6e8229f2 | HBARProtocol,SFProtocolToken                  |
| InsufficientShares()             | 0x39996567 | 399965675cfec4301cbe5ec24fb407575c5a7e4f40d219532068c8e5b35040f9 | HBARProtocol,SFProtocolToken                  |
| InsufficientPool()               | 0x785eab37 | 785eab37c1d893c0b57bae46ba9a8c0c7d4709cdc6d2778f72df5de153c5634d | HBARProtocol,SFProtocolToken                  |
| InvalidAddress()                 | 0xe6c4247b | e6c4247b90bd06996a32d386bb770af9c0018dd1b0ebbb2df2c4499f1eda7b16 | BaseProtocol                                  |
| InvalidExchangeRateMantissa()    | 0x6a01045c | 6a01045cc7ecddf94f0894fa15dc51c7139bc44933c52d4449a0958ce0678f26 | BaseProtocol                                  |
| NotManager()                     | 0xc0fc8a8a | c0fc8a8a97b11b6850e7a210e354944a44a112c976450af0c12088806c8aedcb | BaseProtocol                                  |
| FailedAssociate()                | 0x95ec770c | 95ec770c8917070a34438b7c3f1a50e1732d5ac6cc51937f472be087c6fbcdda | BaseProtocol                                  |
| NoBorrowsToRepay()               | 0xd571ce27 | d571ce274db6d189db02e1c697fd6687f357b98e2f8898105e36d491906b040f | HBARProtocol,SFProtocolToken                  |
| InvalidBalance()                 | 0xc52e3eff | c52e3eff4a3de9692f7e189a77038a4e22e9151cd663cc84107aa4e5e2143e44 | BaseProtocol                                  |
| InvalidFeeAmount()               | 0x52338c80 | 52338c8095c46688a8729f193ed39f9806f6c5d8798f2e4a0604cf836c012c57 | BaseProtocol,HbatProtocol,SFProtocolToken     |
| CannotLiquidateSelf()            | 0x1b4e5afc | 1b4e5afc8f45f0a6563f5c5de3b8decd6bcdce0a496a67949c316d2c1342c5f3 | MarketPositionManager,MarketPositionManagerV2 |
| MaxProtocolBorrowCap()           | 0xc3afc8b6 | c3afc8b6f923fad28170d7cacb9ee1d93f5866aa7706b54e1cf778751c580217 | HBARProtocol,SFProtocolToken                  |
| MaxProtocolSupplyCap()           | 0x47c703a2 | 47c703a21c769eb091f66fe2732b25087966ab1992c3c39ddb7067a07d01395b | HBARProtocol,SFProtocolToken                  |
| NotEnoughTokens()                | 0x22bbb43c | 22bbb43c53322872938cab4136ea7eb16fa3469d6152feda44cc0d18114b7eac | BaseProtocol                                  |

## FileName: IMarketPositionManager

| ErrorMethods                                  | Sign       | Hash                                                             | Used in                                       |
| --------------------------------------------- | ---------- | ---------------------------------------------------------------- | --------------------------------------------- |
| InvalidCaller()                               | 0x48f5c3ed | 48f5c3ed50241a1b6c87d204a25d9d01339cd768de9a714ffbb53a5bb6ad572a | MarketPositionManager,MarketPositionManegerV2 |
| NotListedToken()                              | 0xc76d27fe | c76d27fedb8515267b97c73300dbbd01ed52780d18d5e595dfeed00787480584 | MarketPositionManager,MarketPositionManegerV2 |
| InvalidOracleAddress()                        | 0x55210681 | 552106811589a177428928f9c80309d9a42a932c92eda9a6b328ff41a8ccbf59 | MarketPositionManager,MarketPositionManegerV2 |
| InvalidArrayLength()                          | 0x9d89020a | 9d89020a6060554f8d3c07bb4acf95ad63f2cb33ae7b5a091502e13286ffcdd2 | MarketPositionManager,MarketPositionManegerV2 |
| InvalidMaxLiquidityRate()                     | 0x7d97efe3 | 7d97efe39b2b5194c6543388d0990126f1470aa1453b9f84f1ad4a6bf060d456 | MarketPositionManager,MarketPositionManegerV2 |
| AlreadyAddedToMarket()                        | 0xf9689804 | f968980412253e0a53ed37d24b8b470466007dae804b621ce1d55abaa35a6f31 | MarketPositionManager,MarketPositionManegerV2 |
| AlreadyRemovedFromMarket()                    | 0x4cf0dbdd | 4cf0dbdde15816492431a44a06569a0b8e0b182879514687a117e2bc834eafac | MarketPositionManager,MarketPositionManegerV2 |
| MarketAlreadyFroozen()                        | 0x4d5d5281 | 4d5d5281d7cff88701f048e28c6f2fe60bbd19f43a50631473addbea5aa558ce | MarketPositionManager,MarketPositionManegerV2 |
| SupplyPaused()                                | 0xf803d884 | f803d884f1d3bdf040d2cb64f76bcb5d81f6827eba181c5df785c1429afd1527 | MarketPositionManager,MarketPositionManegerV2 |
| BorrowPaused()                                | 0x12b0cb46 | 12b0cb46009c1abb88941570c13a79b411a671896ef81e3466562ee994383101 | MarketPositionManager,MarketPositionManegerV2 |
| UnderCollaterlized()                          | 0x8ddedcf0 | 8ddedcf0dd407d041a27ecfe41bce96070bd45d3787c069062d232628430ea59 | MarketPositionManager,MarketPositionManegerV2 |
| PriceError()                                  | 0x91f53656 | 91f5365662bc759589ed526e87633f58edfc1b60ea4fbc7eda3aca1fc3f9a405 | MarketPositionManager,MarketPositionManegerV2 |
| UserDoesNotHaveAssets()                       | 0xcbe920f5 | cbe920f589139ff9131aca74eb455a4ae1a21b237dc5d010295e0700d29703c1 | MarketPositionManager,MarketPositionManegerV2 |
| UserDoesNotHaveBorrow()                       | 0xc22fd271 | c22fd271926063f072f9a306373bf27bfb20a7fa264a5654a052debef6058d3d | MarketPositionManager,MarketPositionManegerV2 |
| PositionIsNotLiquidatable()                   | 0x8fa51ba2 | 8fa51ba22dec52adb856618ff8643103b4aa906bcd5b6b02df1c468716c041dc | MarketPositionManager,MarketPositionManegerV2 |
| PositionIsNotHaveBadDebt()                    | 0xe55551f5 | e55551f5f90a448cf43624b707c9faa5a44ccda84e7d68a4fb4731db364ec068 | MarketPositionManager,MarketPositionManegerV2 |
| NotEnoughTotalReservesToLiquidate(address)    | 0xbb7097f7 | bb7097f72c949cf2d36bfa14213544f5600c0fd34a4e64dddb92ce3785b3bcb7 | MarketPositionManager,MarketPositionManegerV2 |
| LiquidatorDoesNotHaveEnoughFundsToLiquidate() | 0xcd3d569e | cd3d569e78961c98e55ed70c5fccae1dde0ec25b457413e31af2898198ad4de6 | MarketPositionManager,MarketPositionManegerV2 |
| LiquidationAmountShouldBeMoreThanZero()       | 0xee9bb39f | ee9bb39f547ca154cdfdafb517d4c7b3d5a3d37ab90e301227631a35e12404ae | MarketPositionManager,MarketPositionManegerV2 |
| CannotLiquidateSelf()                         | 0x1b4e5afc | 1b4e5afc8f45f0a6563f5c5de3b8decd6bcdce0a496a67949c316d2c1342c5f3 | MarketPositionManager,MarketPositionManegerV2 |
| InvalidLiquidationIncentive()                 | 0x33987daf | 33987dafebcbf957930a6b027bb9a41e690ba286837a32919752c6cec24d46b6 | MarketPositionManager,MarketPositionManegerV2 |
| LiquidatorHealthFactorIsLessThanThreshold()   | 0xe85f1d3f | e85f1d3ff0c61badddbbf45b569fb821b2f2d06b4b77ca9840bb77915fb396e3 | MarketPositionManager,MarketPositionManegerV2 |
| InvalidLiquidationRisk()                      | 0x0d86b4f6 | 0d86b4f6eb564cef71026c7a46164d5dd16c9424a02ca77f8e58c16791be9c12 | MarketPositionManager,MarketPositionManegerV2 |

## FileName: IPriceOracle

| ErrorMethods              | Sign       | Hash                                                             | Used in               |
| ------------------------- | ---------- | ---------------------------------------------------------------- | --------------------- |
| InvalidBaseTokenAddress() | 0xe05e1060 | e05e1060d342d757db757e39fd29df3b63e4d27bae99fe4369f692ada57bdd3f | MarketPositionManager |
