pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DSMath } from "../../common/math.sol";
import { AccountInterface } from "./interfaces.sol";
import { Events } from "./events.sol";

contract MigrateResolver is DSMath, Events {
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

    mapping (address => AaveData) public positions;
    mapping(address => mapping(address => uint)) deposits;

    function deposit(address[] calldata tokens, uint[] calldata amts) external {
        uint _length = tokens.length;
        require(_length == amts.length, "invalid-length");

        uint[] memory _amts = new uint[](_length);

        for (uint256 i = 0; i < _length; i++) {
            address _token = tokens[i];
            
            IERC20 tokenContract = IERC20(_token);
            uint _amt = amts[i] == uint(-1) ? tokenContract.balanceOf(msg.sender) : amts[i];
            tokenContract.safeTransferFrom(msg.sender, address(this), _amt);

            deposits[msg.sender][_token] = _amt;
            _amts[i] = _amt;
        }

        emit LogDeposit(msg.sender, tokens, _amts);
    }

    function withdraw(address[] calldata tokens, uint[] calldata amts) external {
        uint _length = tokens.length;
        require(_length == amts.length, "invalid-length");

        uint[] memory _amts = new uint[](_length);

        for (uint256 i = 0; i < _length; i++) {
            uint _amt = amts[i];
            address _token = tokens[i];
            uint maxAmt = deposits[msg.sender][_token];

            if (_amt > maxAmt) {
                _amt = maxAmt;
            }

            IERC20(_token).safeTransfer(msg.sender, _amt);

            deposits[msg.sender][_token] = sub(maxAmt, _amt);

            _amts[i] = _amt;
        }

        emit LogWithdraw(msg.sender, tokens, _amts);
    }
}

contract AaveV2Migrator is MigrateResolver {
    using SafeERC20 for IERC20;

    uint private lastStateId;

    function _migratePosition(address owner) internal {
        AaveData storage data = positions[owner];

        for (uint i = 0; i < data.supplyTokens.length; i++) {
            IERC20(data.supplyTokens[i]).safeTransfer(data.targetDsa, data.supplyAmts[i]);
        }

        AccountInterface(data.targetDsa).migrateAave(owner);
        data.isFinal = true;
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
}