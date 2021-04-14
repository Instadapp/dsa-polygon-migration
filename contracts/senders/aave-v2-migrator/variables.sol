pragma solidity ^0.7.0;

import {
    AaveLendingPoolProviderInterface,
    AaveDataProviderInterface,
    AaveOracleInterface,
    StateSenderInterface,
    IndexInterface,
    FlashloanInterface,
    RootChainManagerInterface
} from "./interfaces.sol";

contract Variables {

    struct AaveDataRaw {
        address targetDsa;
        uint[] supplyAmts;
        uint[] variableBorrowAmts;
        uint[] stableBorrowAmts;
        address[] supplyTokens;
        address[] borrowTokens;
    }

    struct AaveData {
        address targetDsa;
        uint[] supplyAmts;
        uint[] borrowAmts;
        address[] supplyTokens;
        address[] borrowTokens;
    }

    struct TokenPrice {
        uint priceInEth;
        uint priceInUsd;
    }

    /**
     * @dev Aave referal code
     */
    uint16 constant internal referralCode = 3228;

    address constant internal polygonReceiver = address(0); // TODO: Replace this
    FlashloanInterface constant internal flashloanContract = FlashloanInterface(address(0)); // TODO: Replace this
    address constant internal erc20Predicate = 0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf;

    // This will be used to have debt/collateral ratio always 20% less than liquidation
    // TODO: Is this number correct for it?
    uint public safeRatioGap = 800000000000000000; // 20%?
    uint public fee = 998000000000000000; // 0.2% (99.8%) on collateral? TODO: Is this right?
    // TODO: Set by construtor?
    mapping(address => bool) public isSupportedToken;
    address[] public supportedTokens;

    /**
     * @dev Aave Provider
     */
    AaveLendingPoolProviderInterface constant internal aaveProvider = AaveLendingPoolProviderInterface(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);

    /**
     * @dev Aave Data Provider
     */
    AaveDataProviderInterface constant internal aaveData = AaveDataProviderInterface(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);

    /**
     * @dev Aave Price Oracle
     */
    AaveOracleInterface constant internal aaveOracle = AaveOracleInterface(0xA50ba011c48153De246E5192C8f9258A2ba79Ca9);

    /**
     * @dev Polygon State Sync Contract
     */
    StateSenderInterface constant internal stateSender = StateSenderInterface(0x28e4F3a7f651294B9564800b2D01f35189A5bFbE);

    mapping(address => mapping(address => uint)) public deposits;
    bool public isDepositsEnabled;

    // InstaIndex Address.
    IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

    /**
     * Polygon deposit bridge
     */
    RootChainManagerInterface public constant rootChainManager = RootChainManagerInterface(0xA0c68C638235ee32657e8f720a23ceC1bFc77C77);

}