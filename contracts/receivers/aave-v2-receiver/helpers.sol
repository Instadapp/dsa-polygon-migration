pragma solidity >=0.7.0;

import { DSMath } from "../../common/math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Stores } from "../../common/stores-polygon.sol";
import { Variables } from "./variables.sol";

import {
    TokenMappingInterface,
    AaveData,
    AaveDataProviderInterface,
    AaveInterface
} from "./interfaces.sol";

abstract contract Helpers is Stores, DSMath, Variables {
    using SafeERC20 for IERC20;

    function remapTokens(AaveData memory data) internal view returns (AaveData memory) {
        for (uint i = 0; i < data.supplyTokens.length; i++) {
            data.supplyTokens[i] = tokenMapping.getMapping(data.supplyTokens[i]);
        }

        for (uint i = 0; i < data.borrowTokens.length; i++) {
            data.borrowTokens[i] = tokenMapping.getMapping(data.borrowTokens[i]);
        }

        return data;
    }

    function isPositionSafe() internal returns (bool isOk) {
        // TODO: Check the final position health
        require(isOk, "position-at-risk");
    }

    function transferAtokens(AaveInterface aave, address dsa, address[] memory supplyTokens, uint[] memory supplyAmts) internal {
        for (uint i = 0; i < supplyTokens.length; i++) {
            address _token = supplyTokens[i];
            IERC20 _atokenContract = IERC20(_token); // TODO: Fetch atoken from Aave mapping (change _token to atoken address)
            uint _atokenBal = _atokenContract.balanceOf(address(this));
            uint _supplyAmt = supplyAmts[i];
            bool isFlash;
            uint _flashAmt;

            // get Aave liquidity of token
            uint tokenLiq = uint(0);

            if (_atokenBal < _supplyAmt) {
                uint _reqAmt = _supplyAmt - _atokenBal;
                if (tokenLiq < _reqAmt) {
                    _flashAmt = flashAmts[_token];
                    if (_flashAmt > 0) {
                        aave.deposit(_token, _flashAmt, address(this), 3288); // TODO: what is our ID on Polygon?
                        tokenLiq += _flashAmt;
                        isFlash = true;
                    }
                }

                uint num = _reqAmt/tokenLiq + 1; // TODO: Is this right
                uint splitAmt = _reqAmt/num; // TODO: Check decimal
                uint finalSplit = _reqAmt - (splitAmt * (num - 1)); // TODO: to resolve upper decimal error

                for (uint j = 0; j < num; j++) {
                    if (i < num - 1) {
                        aave.borrow(_token, splitAmt, 2, 3288, address(this)); // TODO: is "2" for interest rate mode. Right?
                        aave.deposit(_token, splitAmt, address(this), 3288);
                    } else {
                        aave.borrow(_token, finalSplit, 2, 3288, address(this)); // TODO: is "2" for interest rate mode. Right?
                        aave.deposit(_token, finalSplit, address(this), 3288);
                    }
                }
            }

            if (isFlash) {
                aave.withdraw(_token, _flashAmt, address(this));
            }

            _atokenContract.safeTransfer(dsa, _supplyAmt);
        }
    }

    function borrowAndTransferSpells(AaveInterface aave, address dsa, address[] memory borrowTokens, uint[] memory borrowAmts) internal {
        for (uint i = 0; i < borrowTokens.length; i++) {
            address _token = borrowTokens[i];
            address _atoken = address(0); // TODO: Fetch atoken address
            // get Aave liquidity of token
            uint tokenLiq = uint(0);
            uint _borrowAmt = borrowAmts[i];

            uint _flashAmt;
            bool isFlash;
            if (tokenLiq < _borrowAmt) {
                _flashAmt = flashAmts[_token];
                aave.deposit(_token, _flashAmt, address(this), 3288); // TODO: what is our ID on Polygon?
                isFlash = true;
                tokenLiq += _flashAmt;
            }
            // TODO: Check number of loops needed. Borrow and supply on user's account.
            uint num = _borrowAmt/tokenLiq + 1; // TODO: Is this right
            uint splitAmt = _borrowAmt/num; // TODO: Check decimal
            uint finalSplit = _borrowAmt - (splitAmt * (num - 1)); // TODO: to resolve upper decimal error

            uint spellsAmt = (2 * num) + 1;
            string[] memory targets = new string[](spellsAmt);
            bytes[] memory castData = new bytes[](spellsAmt);
            for (uint j = 0; j < num; j++) {
                uint k = j * 2;
                if (i < num - 1) {
                    targets[k] = "AAVE-V2-A";
                    castData[k] = abi.encodeWithSignature("borrow(address,uint256,uint256,uint256,uint256)", _token, splitAmt, 2, 0, 0);
                    targets[k+1] = "AAVE-V2-A";
                    castData[k+1] = abi.encodeWithSignature("deposit(address,uint256,uint256,uint256,uint256)", _token, splitAmt, 2, 0, 0);
                } else {
                    targets[k] = "AAVE-V2-A";
                    castData[k] = abi.encodeWithSignature("borrow(address,uint256,uint256,uint256,uint256)", _token, finalSplit, 2, 0, 0);
                    targets[k+1] = "AAVE-V2-A";
                    castData[k+1] = abi.encodeWithSignature("deposit(address,uint256,uint256,uint256,uint256)", _token, finalSplit, 2, 0, 0);
                }
            }

            if (isFlash) {
                aave.withdraw(_token, _flashAmt, address(this));
            }

            targets[spellsAmt] = "BASIC-A"; // TODO: right spell?
            castData[spellsAmt] = abi.encode("withdraw(address,uint256,address,uint256,uint256)", _atoken, _borrowAmt, address(this), 0, 0); // encode the data of atoken withdrawal
            // TODO: Call DSAs cast and borrow (maybe create a new implementation which only this contract can run?)
        }

    }

}