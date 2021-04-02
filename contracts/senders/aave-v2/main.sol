pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { TokenInterface, AccountInterface } from "../../common/interfaces.sol";
import { AaveInterface, ATokenInterface } from "./interfaces.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";

abstract contract AaveResolver is Helpers, Events {
    function _paybackBehalfOne(AaveInterface aave, address token, uint amt, uint rateMode, address user) private {
        aave.repay(token, amt, rateMode, user);
    }

    function _PaybackStable(
        uint _length,
        AaveInterface aave,
        address[] memory tokens,
        uint256[] memory amts,
        address user
    ) internal {
        for (uint i = 0; i < _length; i++) {
            if (amts[i] > 0) {
                _paybackBehalfOne(aave, tokens[i], amts[i], 1, user);
            }
        }
    }

    function _PaybackVariable(
        uint _length,
        AaveInterface aave,
        address[] memory tokens,
        uint256[] memory amts,
        address user
    ) internal {
        for (uint i = 0; i < _length; i++) {
            if (amts[i] > 0) {
                _paybackBehalfOne(aave, tokens[i], amts[i], 2, user);
            }
        }
    }

    function _Withdraw(
        uint _length,
        AaveInterface aave,
        address[] memory tokens,
        uint256[] memory amts
    ) internal {
        for (uint i = 0; i < _length; i++) {
            if (amts[i] > 0) {
                aave.withdraw(tokens[i], amts[i], fundLocker);
            }
        }
    }
}

contract AaveImportResolver is AaveResolver {
    struct AaveData {
        bool isFinal;
        address targetDsa;
        uint[] supplyAmts;
        uint[] variableBorrowAmts;
        uint[] stableBorrowAmts;
        address[] supplyTokens;
        address[] borrowTokens;
    }

    // TODO - Move state syncing to Migrator
    // mapping (address => AaveData) public positions;

    function migrate(
        address targetDsa,
        address[] calldata supplyTokens,
        address[] calldata borrowTokens
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        require(AccountInterface(address(this)).isAuth(msg.sender), "user-account-not-auth");
        require(supplyTokens.length > 0, "0-length-not-allowed");
        require(targetDsa != address(0), "invalid-address");

        AaveData memory data;

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        (,,,,,uint healthFactor) = aave.getUserAccountData(address(this));
        require(healthFactor > 1e18, "position-not-safe");

        data.supplyAmts = new uint[](supplyTokens.length);
        data.supplyTokens = new address[](supplyTokens.length);
        data.targetDsa = targetDsa;

        for (uint i = 0; i < supplyTokens.length; i++) {
            address _token = supplyTokens[i] == ethAddr ? wethAddr : supplyTokens[i];
            (address _aToken, ,) = aaveData.getReserveTokensAddresses(_token);
            data.supplyTokens[i] = _token;
            data.supplyAmts[i] = ATokenInterface(_aToken).balanceOf(address(this));
        }

        if (borrowTokens.length > 0) {
            data.variableBorrowAmts = new uint[](borrowTokens.length);
            data.stableBorrowAmts = new uint[](borrowTokens.length);

            for (uint i = 0; i < borrowTokens.length; i++) {
                address _token = borrowTokens[i] == ethAddr ? wethAddr : borrowTokens[i];
                data.borrowTokens[i] = _token;

                (
                    ,
                    data.stableBorrowAmts[i],
                    data.variableBorrowAmts[i],
                    ,,,,,
                ) = aaveData.getUserReserveData(_token, address(this));

                uint totalBorrowAmt = add(data.stableBorrowAmts[i], data.variableBorrowAmts[i]);

                if (totalBorrowAmt > 0) {
                    TokenInterface(_token).approve(address(aave), totalBorrowAmt);
                }
            }

            // TODO - Request liquidity from Migrator

            _PaybackStable(borrowTokens.length, aave, data.borrowTokens, data.stableBorrowAmts, address(this));
            _PaybackVariable(borrowTokens.length, aave, data.borrowTokens, data.variableBorrowAmts, address(this));
        }

        _Withdraw(supplyTokens.length, aave, data.supplyTokens, data.supplyAmts);

        // TODO - Move state syncing to Migrator
        // positions[msg.sender] = data;
        // bytes memory positionData = abi.encode(msg.sender, data);
        // stateSender.syncState(polygonReceiver, positionData);

        _eventName = "LogAaveV2Migrate(address,address[],address[],uint256[],uint256[],uint256[])";
        _eventParam = abi.encode(
            msg.sender,
            supplyTokens,
            borrowTokens,
            data.supplyAmts,
            data.stableBorrowAmts,
            data.variableBorrowAmts
        );
    }
}