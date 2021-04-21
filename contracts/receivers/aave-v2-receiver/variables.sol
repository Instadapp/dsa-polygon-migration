pragma solidity ^0.7.0;

import {
    TokenMappingInterface,
    AaveLendingPoolProviderInterface,
    AaveDataProviderInterface,
    IndexInterface,
    InstaListInterface
} from "./interfaces.sol";

contract Variables {
    // Constant Address //

    /**
    * @dev token Mapping contract Provider
    */
    TokenMappingInterface constant public tokenMapping = TokenMappingInterface(address(0xa471D83e526B6b5D6c876088D34834B44D4064ff));
    /**
     * @dev Aave Provider
     */
    AaveLendingPoolProviderInterface constant internal aaveProvider = AaveLendingPoolProviderInterface(0xd05e3E715d945B59290df0ae8eF85c1BdB684744);
    
    /**
     * @dev Aave Data Provider
     */
    AaveDataProviderInterface constant internal aaveData = AaveDataProviderInterface(0x7551b5D2763519d4e37e8B81929D336De671d46d);
    

    /**
     * @dev InstaIndex Polygon contract
     */
    IndexInterface public constant instaIndex = IndexInterface(0xA9B99766E6C676Cf1975c0D3166F96C0848fF5ad);

     /**
     * @dev InstaList Polygon contract
     */
    InstaListInterface public constant instaList = InstaListInterface(0x839c2D3aDe63DF5b0b8F3E57D5e145057Ab41556);

    /**
     * @dev Matic StateReceiver contract
     */
    address public constant maticReceiver = 0x0000000000000000000000000000000000001001;


    // Storage variables //

    /**
     * @dev This will be used to have debt/collateral ratio always 20% less than liquidation
    */
    uint public safeRatioGap = 800000000000000000; // 20%? 2e17

    // mapping stateId => user position
    mapping(uint => bytes) public positions;

    /**
    * @dev Mapping of supported token
    */
    mapping(address => bool) public isSupportedToken;

    /**
    * @dev Array of supported token
    */
    address[] public supportedTokens; // don't add maticAddr. Only add wmaticAddr?

    /**
    * @dev last stateId from the onStateReceive
    */
    uint256 internal lastStateId;
}
