pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TokenInterface } from "../../common/interfaces.sol";
import { Helpers } from "./helpers.sol";
import { AaveInterface, ATokenInterface } from "./interfaces.sol";
import { Events } from "./events.sol";

contract LiquidityResolver is Helpers, Events {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => uint)) deposits;

    function deposit(address[] calldata tokens, uint[] calldata amts) external payable {
        uint _length = tokens.length;
        require(_length == amts.length, "invalid-length");

        uint[] memory _amts = new uint[](_length);

        for (uint256 i = 0; i < _length; i++) {
            uint _amt;
            address _token = tokens[i];
            if (_token == ethAddr) {
                require(msg.value == amts[i]);
                _amt = msg.value;

                TokenInterface(wethAddr).deposit{value: msg.value}();
            } else {
                IERC20 tokenContract = IERC20(_token);
                _amt = amts[i] == uint(-1) ? tokenContract.balanceOf(msg.sender) : amts[i];
                tokenContract.safeTransferFrom(msg.sender, address(this), _amt);
            }

            _amts[i] = _amt;

            deposits[msg.sender][_token] = _amt;
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

            if (_token == ethAddr) {
                TokenInterface(wethAddr).withdraw(_amt);
                msg.sender.call{value: _amt}("");
            } else {
                IERC20(_token).safeTransfer(msg.sender, _amt);
            }

            _amts[i] = _amt;

            deposits[msg.sender][_token] = sub(maxAmt, _amt);
        }

        emit LogWithdraw(msg.sender, tokens, _amts);
    }
}

contract MigrateResolver is LiquidityResolver {
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

    function migrate(address owner, AaveData calldata _data) external {
        require(_data.supplyTokens.length > 0, "0-length-not-allowed");
        require(_data.targetDsa != address(0), "invalid-address");
        require(_data.supplyTokens.length == _data.supplyAmts.length, "invalid-length");
        require(
            _data.borrowTokens.length == _data.variableBorrowAmts.length &&
            _data.borrowTokens.length == _data.stableBorrowAmts.length,
            "invalid-length"
        );

        AaveData memory data;

        data.borrowTokens = _data.borrowTokens;
        data.isFinal = _data.isFinal;
        data.stableBorrowAmts = _data.stableBorrowAmts;
        data.supplyAmts = _data.supplyAmts;
        data.supplyTokens = _data.supplyTokens;
        data.targetDsa = _data.targetDsa;
        data.variableBorrowAmts = _data.variableBorrowAmts;

        address sourceDsa = msg.sender;

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        (,,,,,uint healthFactor) = aave.getUserAccountData(sourceDsa);
        require(healthFactor > 1e18, "position-not-safe");

        for (uint i = 0; i < data.supplyTokens.length; i++) {
            (address _aToken, ,) = aaveData.getReserveTokensAddresses(data.supplyTokens[i]);
            ATokenInterface aTokenContract = ATokenInterface(_aToken);

            aTokenContract.transferFrom(msg.sender, address(this), data.supplyAmts[i]);
        }

        for (uint i = 0; i < data.borrowTokens.length; i++) {
            address _token = data.borrowTokens[i] == ethAddr ? wethAddr : data.borrowTokens[i];
            data.borrowTokens[i] = _token;

            (
                ,
                uint stableDebt,
                uint variableDebt,
                ,,,,,
            ) = aaveData.getUserReserveData(_token, sourceDsa);

            data.stableBorrowAmts[i] = data.stableBorrowAmts[i] == uint(-1) ? stableDebt : data.stableBorrowAmts[i];
            data.variableBorrowAmts[i] = data.variableBorrowAmts[i] == uint(-1) ? variableDebt : data.variableBorrowAmts[i];


            uint totalBorrowAmt = add(data.stableBorrowAmts[i], data.variableBorrowAmts[i]);
            if (totalBorrowAmt > 0) {
                IERC20(_token).safeApprove(address(aave), totalBorrowAmt);
            }
        }

        _PaybackStable(data.borrowTokens.length, aave, data.borrowTokens, data.stableBorrowAmts, sourceDsa);
        _PaybackVariable(data.borrowTokens.length, aave, data.borrowTokens, data.variableBorrowAmts, sourceDsa);
        _Withdraw(data.supplyTokens.length, aave, data.supplyTokens, data.supplyAmts);

        positions[owner] = data;
        bytes memory positionData = abi.encode(owner, data);
        stateSender.syncState(polygonReceiver, positionData);

        emit LogAaveV2Migrate(
            msg.sender,
            data.targetDsa,
            data.supplyTokens,
            data.borrowTokens,
            data.supplyAmts,
            data.variableBorrowAmts,
            data.stableBorrowAmts
        );
    }

    // function migrate(
    //     address owner,
    //     address targetDsa,
    //     address[] calldata supplyTokens,
    //     address[] calldata borrowTokens
    // ) external {
    //     require(supplyTokens.length > 0, "0-length-not-allowed");
    //     require(targetDsa != address(0), "invalid-address");

    //     address sourceDsa = msg.sender;

    //     AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

    //     AaveData memory data;

    //     (,,,,,uint healthFactor) = aave.getUserAccountData(sourceDsa);
    //     require(healthFactor > 1e18, "position-not-safe");

    //     data.supplyAmts = new uint[](supplyTokens.length);
    //     data.supplyTokens = new address[](supplyTokens.length);
    //     data.targetDsa = targetDsa;

    //     for (uint i = 0; i < supplyTokens.length; i++) {
    //         address _token = supplyTokens[i] == ethAddr ? wethAddr : supplyTokens[i];
    //         (address _aToken, ,) = aaveData.getReserveTokensAddresses(_token);

    //         ATokenInterface aTokenContract = ATokenInterface(_aToken);

    //         data.supplyTokens[i] = _token;
    //         data.supplyAmts[i] = aTokenContract.balanceOf(sourceDsa);

    //         aTokenContract.transferFrom(msg.sender, address(this), data.supplyAmts[i]);
    //     }

    //     if (borrowTokens.length > 0) {
    //         data.variableBorrowAmts = new uint[](borrowTokens.length);
    //         data.stableBorrowAmts = new uint[](borrowTokens.length);

    //         for (uint i = 0; i < borrowTokens.length; i++) {
    //             address _token = borrowTokens[i] == ethAddr ? wethAddr : borrowTokens[i];
    //             data.borrowTokens[i] = _token;

    //             (
    //                 ,
    //                 data.stableBorrowAmts[i],
    //                 data.variableBorrowAmts[i],
    //                 ,,,,,
    //             ) = aaveData.getUserReserveData(_token, sourceDsa);

    //             uint totalBorrowAmt = add(data.stableBorrowAmts[i], data.variableBorrowAmts[i]);

    //             if (totalBorrowAmt > 0) {
    //                 IERC20(_token).safeApprove(address(aave), totalBorrowAmt);
    //             }
    //         }

    //         _PaybackStable(borrowTokens.length, aave, data.borrowTokens, data.stableBorrowAmts, sourceDsa);
    //         _PaybackVariable(borrowTokens.length, aave, data.borrowTokens, data.variableBorrowAmts, sourceDsa);
    //     }

    //     _Withdraw(supplyTokens.length, aave, data.supplyTokens, data.supplyAmts);

    //     positions[owner] = data;
    //     bytes memory positionData = abi.encode(owner, data);
    //     stateSender.syncState(polygonReceiver, positionData);

    //     emit LogAaveV2Migrate(
    //         msg.sender,
    //         targetDsa,
    //         supplyTokens,
    //         borrowTokens,
    //         data.supplyAmts,
    //         data.variableBorrowAmts,
    //         data.stableBorrowAmts
    //     );
    // }
}