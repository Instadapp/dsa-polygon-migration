pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Helpers } from "./helpers.sol";
import { AaveInterface, ATokenInterface } from "./interfaces.sol";

contract LiquidityResolver is Helpers {
    using SafeERC20 for IERC20;

    mapping(address => mapping(address => uint)) deposits;

    function deposit(address[] calldata tokens, uint[] calldata amts) external payable {
        uint _length = tokens.length;
        require(_length == amts.length, "invalid-length");

        for (uint256 i = 0; i < _length; i++) {
            uint _amt;
            address _token = tokens[i];
            if (_token == ethAddr) {
                require(msg.value == amts[i]);
                _amt = msg.value;
            } else {
                IERC20 tokenContract = IERC20(_token);
                _amt = amts[i] == uint(-1) ? tokenContract.balanceOf(msg.sender) : amts[i];
                tokenContract.safeTransferFrom(msg.sender, address(this), _amt);
            }

            deposits[_token][msg.sender] = _amt;
        }
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

    function migrate(
        address owner,
        address targetDsa,
        address[] calldata supplyTokens,
        address[] calldata borrowTokens
    ) external {
        require(supplyTokens.length > 0, "0-length-not-allowed");
        require(targetDsa != address(0), "invalid-address");

        address sourceDsa = msg.sender;

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        AaveData memory data;

        (,,,,,uint healthFactor) = aave.getUserAccountData(sourceDsa);
        require(healthFactor > 1e18, "position-not-safe");

        data.supplyAmts = new uint[](supplyTokens.length);
        data.supplyTokens = new address[](supplyTokens.length);
        data.targetDsa = targetDsa;

        for (uint i = 0; i < supplyTokens.length; i++) {
            address _token = supplyTokens[i] == ethAddr ? wethAddr : supplyTokens[i];
            (address _aToken, ,) = aaveData.getReserveTokensAddresses(_token);

            ATokenInterface aTokenContract = ATokenInterface(_aToken);

            data.supplyTokens[i] = _token;
            data.supplyAmts[i] = aTokenContract.balanceOf(sourceDsa);

            aTokenContract.transferFrom(msg.sender, address(this), data.supplyAmts[i]);
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
                ) = aaveData.getUserReserveData(_token, sourceDsa);

                uint totalBorrowAmt = add(data.stableBorrowAmts[i], data.variableBorrowAmts[i]);

                if (totalBorrowAmt > 0) {
                    IERC20(_token).safeApprove(address(aave), totalBorrowAmt);
                }
            }

            _PaybackStable(borrowTokens.length, aave, data.borrowTokens, data.stableBorrowAmts, sourceDsa);
            _PaybackVariable(borrowTokens.length, aave, data.borrowTokens, data.variableBorrowAmts, sourceDsa);
        }

        _Withdraw(supplyTokens.length, aave, data.supplyTokens, data.supplyAmts);

        positions[owner] = data;
        bytes memory positionData = abi.encode(owner, data);
        stateSender.syncState(polygonReceiver, positionData);
    }
}