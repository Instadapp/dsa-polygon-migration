pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

interface IndexInterface {
    function master() external view returns (address);
}

abstract contract Helpers {

    event LogTokenMapAdded(address indexed L1_token, address indexed L2_token);
    event LogTokenMapUpdated(address indexed L1_token, address indexed L2_token_new, address indexed L2_token_old);

    // InstaIndex Address.
    IndexInterface public constant instaIndex = IndexInterface(0xA9B99766E6C676Cf1975c0D3166F96C0848fF5ad);

    address public constant ethAddr = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    mapping (address => address) public tokenMapping;

    modifier isMaster {
        require(msg.sender == instaIndex.master(), "not-a-master");
        _;
    }

    function _addTokenMaps(address[] memory L1, address[] memory L2) internal {
        uint len = L1.length;
        require(len == L2.length, "addTokenMaps: Length not same");
        for (uint256 i = 0; i < len; i++) {
            require(tokenMapping[L1[i]] == address(0), "addTokenMaps: Token map already added");
            tokenMapping[L1[i]] = L2[i];
            emit LogTokenMapAdded(L1[i], L2[i]);
        }
    }

    function addTokenMaps(address[] memory L1, address[] memory L2) external isMaster {
        _addTokenMaps(L1, L2);
    }

    function updateTokenMaps(address[] memory L1, address[] memory L2) external isMaster {
        uint len = L1.length;
        require(len == L2.length, "updateTokenMaps: Length not same");
        for (uint256 i = 0; i < len; i++) {
            require(tokenMapping[L1[i]] != address(0), "updateTokenMaps: Token map already added");
            require(tokenMapping[L1[i]] != L2[i], "updateTokenMaps: L1 Token is mapped to same L2 Token");
            emit LogTokenMapUpdated(L1[i], tokenMapping[L1[i]], L2[i]);
            tokenMapping[L1[i]] = L2[i];
        }
    }

    function getMapping(address L1Address) external view returns (address) {
        return tokenMapping[L1Address];
    }

}

contract InstaPolygonTokenMapping is Helpers {
    constructor(address[] memory L1, address[] memory L2) {
        _addTokenMaps(L1, L2);
    }
}