pragma solidity ^0.7.0;

import {
    TokenMappingInterface,
    AaveLendingPoolProviderInterface,
    AaveDataProviderInterface,
    IndexInterface
} from "./interfaces.sol";

contract Variables {

    // This will be used to have debt/collateral ratio always 20% less than liquidation
    // TODO: Is this number correct for it?
    uint public safeRatioGap = 800000000000000000; // 20%? 2e17

    // TODO: Replace this
    TokenMappingInterface tokenMapping = TokenMappingInterface(address(0xa31442F2607947a88807b2bcD5D4951eEdd4A885)); // TODO: FAKE ADDR, CHANGE THIS

    AaveLendingPoolProviderInterface constant internal aaveProvider = AaveLendingPoolProviderInterface(0xd05e3E715d945B59290df0ae8eF85c1BdB684744);

    /**
     * @dev Aave Data Provider
     */
    AaveDataProviderInterface constant internal aaveData = AaveDataProviderInterface(0x7551b5D2763519d4e37e8B81929D336De671d46d);


    // dsa => position
    mapping(uint => bytes) public positions;

    // InstaIndex Address.
    IndexInterface public constant instaIndex = IndexInterface(0xA9B99766E6C676Cf1975c0D3166F96C0848fF5ad);

    // TODO: Set by construtor?
    mapping(address => bool) public isSupportedToken;
    address[] public supportedTokens; // don't add maticAddr. Only add wmaticAddr?

    // Address which will receive L1 data and post it on L2
    address public maticReceiver = 0x0000000000000000000000000000000000001001;

}