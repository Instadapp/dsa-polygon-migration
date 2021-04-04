pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AccountInterface } from "./interfaces.sol";

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

    function _migratePosition(address owner) internal {
        AaveData storage data = positions[owner];

        for (uint i = 0; i < data.supplyTokens.length; i++) {
            IERC20(data.supplyTokens[i]).safeTransfer(data.targetDsa, data.supplyAmts[i]);
        }

        AccountInterface(data.targetDsa).migrateAave(owner);
        data.isFinal = true;
    }

    function onStateReceive(uint256 stateId, bytes calldata receivedData) external {
        // require(stateId > lastStateId, "wrong-data");
        lastStateId = stateId;

        (address owner, AaveData memory data) = abi.decode(receivedData, (address, AaveData));
        positions[owner] = data;

        if (canMigrate(owner)) {
            _migratePosition(owner);
        }
    }

    function migrate(address owner) external {
        require(msg.sender == owner, "not-authorized");
        require(canMigrate(owner), "not-enough-liquidity");

        _migratePosition(owner);
    }

    function getPosition(address owner) public view returns (AaveData memory data) {
        data = positions[owner];
    }

    function canMigrate(address owner) public view returns (bool can) {
        can = true;

        AaveData memory data = getPosition(owner);

        for (uint i = 0; i < data.supplyTokens.length; i++) {
            IERC20 token = IERC20(data.supplyTokens[i]);
            if (token.balanceOf(address(this)) < data.supplyAmts[i]) {
                can = false;
            }
        }
    }
}