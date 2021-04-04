pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MigrateResolver {
    using SafeERC20 for IERC20;

    struct AaveData {
        bool isFinal;
        address targetDsa;
        uint[] supplyAmts;
        uint[] variableBorrowAmts;
        uint[] stableBorrowAmts;
        address[] supplyTokens;
        address[] borrowTokens;
    }

    uint private lastStateId;
    mapping (address => AaveData) public positions;

    function onStateReceive(uint256 stateId, bytes calldata receivedData) external {
        // require(stateId > lastStateId, "wrong-data");
        lastStateId = stateId;

        (address owner, AaveData memory data) = abi.decode(receivedData, (address, AaveData));
        positions[owner] = data;
    }

    function getPosition(address owner) public view returns (AaveData memory data) {
        data = positions[owner];
    }
}