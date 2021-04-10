pragma solidity ^0.7.0;

import {
    AaveLendingPoolProviderInterface,
    AaveDataProviderInterface,
    StateSenderInterface,
    IndexInterface,
    FlashloanInterface
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
     * @dev Polygon State Sync Contract
     */
    StateSenderInterface constant internal stateSender = StateSenderInterface(0x28e4F3a7f651294B9564800b2D01f35189A5bFbE);

    mapping(address => mapping(address => uint)) public deposits;

    // InstaIndex Address.
    IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

}