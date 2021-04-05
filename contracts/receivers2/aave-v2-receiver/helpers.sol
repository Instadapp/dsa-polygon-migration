pragma solidity >=0.7.0;

import { DSMath } from "../../common/math.sol";
import { TokenMappingInterface, AaveData } from "./interfaces.sol";

abstract contract Helpers is DSMath {
    // Replace this
    TokenMappingInterface tokenMapping = TokenMappingInterface(address(2));

    function remapTokens(AaveData memory data) internal returns (AaveData memory) {
        for (uint i = 0; i < data.supplyTokens.length; i++) {
            data.supplyTokens[i] = tokenMapping.getMapping(data.supplyTokens[i]);
        }

        for (uint i = 0; i < data.borrowTokens.length; i++) {
            data.borrowTokens[i] = tokenMapping.getMapping(data.borrowTokens[i]);
        }

        return data;
    }
}