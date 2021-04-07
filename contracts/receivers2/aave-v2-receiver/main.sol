pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AccountInterface, AaveData, IndexInterface } from "./interfaces.sol";
import { Events } from "./events.sol";
import { Helpers } from "./helpers.sol";

contract MigrateResolver is Helpers, Events {
    using SafeERC20 for IERC20;

    // This will be used to have debt/collateral ratio always 20% less than liquidation
    // TODO: Is this number correct for it?
    uint public safeRatioGap = 200000000000000000; // 20%? 2e17

    // dsa => position
    mapping(uint => bytes) public positions;
    mapping(address => mapping(address => uint)) deposits;

    // InstaIndex Address.
    IndexInterface public constant instaIndex = IndexInterface(0x2971AdFa57b20E5a416aE5a708A8655A9c74f723);

    function spell(address _target, bytes memory _data) external {
        require(msg.sender == instaIndex.master(), "not-master");
        require(_target != address(0), "target-invalid");
        assembly {
            let succeeded := delegatecall(gas(), _target, add(_data, 0x20), mload(_data), 0, 0)

            switch iszero(succeeded)
                case 1 {
                    // throw if delegatecall failed
                    let size := returndatasize()
                    returndatacopy(0x00, 0x00, size)
                    revert(0x00, size)
                }
        }
    }

    // TODO: Deposit in Aave
    function deposit(address[] calldata tokens, uint[] calldata amts) external {
        uint _length = tokens.length;
        require(_length == amts.length, "invalid-length");

        uint[] memory _amts = new uint[](_length);

        for (uint256 i = 0; i < _length; i++) {
            address _token = tokens[i];
            
            IERC20 tokenContract = IERC20(_token);
            uint _amt = amts[i] == uint(-1) ? tokenContract.balanceOf(msg.sender) : amts[i];
            tokenContract.safeTransferFrom(msg.sender, address(this), _amt);

            deposits[msg.sender][_token] += _amt;
            _amts[i] = _amt;
        }

        emit LogDeposit(msg.sender, tokens, _amts);
    }

    // TODO: Withdraw from Aave
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

    function _migratePosition(AaveData memory _data) internal {
        AaveData memory data = remapTokens(_data); // converting L1 token addresses to L2 addresses

        address dsa = _data.targetDsa;
        uint[] memory supplyAmts = _data.supplyAmts;
        uint[] memory borrowAmts = _data.borrowAmts;
        address[] memory supplyTokens = _data.supplyTokens;
        address[] memory borrowTokens = _data.borrowTokens;

        transferAtokens(dsa, supplyTokens, supplyAmts);

        // Have to borrow from user's account
        borrowAndTransferSpells(dsa, borrowTokens, borrowAmts);

        // TODO: Final position should be 20% less than liquidation (use 'safeRatioGap', Also should we check this at start?)
    }

    // function getPosition(address owner) public view returns (AaveData memory data) {
    //     data = positions[owner];
    // }

    // TODO: have to add more conditions
    function canMigrate(AaveData memory data) public view returns (bool can) {
        // can = true;

        // AaveData memory data = getPosition(owner);

        // for (uint i = 0; i < data.supplyTokens.length; i++) {
        //     IERC20 token = IERC20(data.supplyTokens[i]);
        //     if (token.balanceOf(address(this)) < data.supplyAmts[i]) {
        //         can = false;
        //     }
        // }
    }

    function onStateReceive(uint256 stateId, bytes calldata receivedData) external {
        require(stateId > lastStateId, "wrong-data");
        lastStateId = stateId;

        // (AaveData memory data) = abi.decode(receivedData, (AaveData));
        positions[stateId] = receivedData; // TODO: what's the best way to store user's data to create position later

    }

    function migrate(uint _id) external {
        bytes memory _data = positions[_id];
        require(_data != bytes(0), "already-migrated"); // TODO: How to resolve this
        
        AaveData memory data = abi.decode(_data, (AaveData));

        require(canMigrate(data), "not-enough-liquidity"); // TODO: do we need this? as we can see if transaction will go through or not from our bot

        _migratePosition(data);

        delete positions[_id];
    }
}
