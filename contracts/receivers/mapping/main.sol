pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

interface IndexInterface {
    function master() external view returns (address);
}

interface ConnectorsInterface {
    function chief(address) external view returns (bool);
}

interface CTokenInterface {
    function isCToken() external view returns (bool);
    function underlying() external view returns (address);
}

abstract contract Helpers {

    // struct TokenMap {
    //     address ctoken;
    //     address token;
    // }

    // event LogCTokenAdded(string indexed name, address indexed token, address indexed ctoken);
    // event LogCTokenUpdated(string indexed name, address indexed token, address indexed ctoken);

    // ConnectorsInterface public immutable connectors;

    // InstaIndex Address.
    IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

    address public constant ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping (address => address) public tokenMapping;

    // modifier isChief {
    //     require(msg.sender == instaIndex.master() || connectors.chief(msg.sender), "not-an-chief");
    //     _;
    // }

    // constructor(address _connectors) {
    //     connectors = ConnectorsInterface(_connectors);
    // }

    function getMapping(address L1Address) external view returns (address) {
        return tokenMapping[L1Address];
    }

}

contract InstaPolygonTokenMapping is Helpers {

    constructor(address[] memory L1, address[] memory L2) {
        for (uint256 i = 0; i < L1.length; i++) {
            tokenMapping[L1[i]] = L2[i];
        }
    }
}