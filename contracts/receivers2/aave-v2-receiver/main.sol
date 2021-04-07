pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TokenInterface } from "../../common/interfaces.sol";
import { AccountInterface, AaveData, AaveInterface, IndexInterface } from "./interfaces.sol";
import { Events } from "./events.sol";
import { Helpers } from "./helpers.sol";

contract MigrateResolver is Helpers, Events {
    using SafeERC20 for IERC20;

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

    // TODO: @mubaris Make this similar to L1 migrator. Have to change ETH by MATIC
    function deposit(address[] calldata tokens, uint[] calldata amts) external payable {
        uint _length = tokens.length;
        require(_length == amts.length, "invalid-length");

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        uint[] memory _amts = new uint[](_length);

        for (uint256 i = 0; i < _length; i++) {
            require(isSupportedToken[tokens[i]], "token-not-enabled");
            uint _amt;
            address _token = tokens[i];
            if (_token == maticAddr) {
                require(msg.value == amts[i]);
                _amt = msg.value;
                TokenInterface(wmaticAddr).deposit{value: msg.value}();
                aave.deposit(wmaticAddr, _amt, address(this), 3288);
            } else {
                IERC20 tokenContract = IERC20(_token);
                _amt = amts[i] == uint(-1) ? tokenContract.balanceOf(msg.sender) : amts[i];
                tokenContract.safeTransferFrom(msg.sender, address(this), _amt);
                aave.deposit(_token, _amt, address(this), 3288);
            }

            _amts[i] = _amt;

            deposits[msg.sender][_token] += _amt;
        }

        emit LogDeposit(msg.sender, tokens, _amts);
    }

    // TODO: @mubaris Make this similar to L1 migrator. Have to change ETH by MATIC
    function withdraw(address[] calldata tokens, uint[] calldata amts) external {
        uint _length = tokens.length;
        require(_length == amts.length, "invalid-length");

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        uint[] memory _amts = new uint[](_length);

        for (uint256 i = 0; i < _length; i++) {
            require(isSupportedToken[tokens[i]], "token-not-enabled");
            uint _amt = amts[i];
            address _token = tokens[i];
            uint maxAmt = deposits[msg.sender][_token];

            if (_amt > maxAmt) {
                _amt = maxAmt;
            }

            if (_token == maticAddr) {
                TokenInterface _tokenContract = TokenInterface(wmaticAddr);
                uint _maticBal = address(this).balance;
                uint _tknBal = _tokenContract.balanceOf(address(this));
                if ((_maticBal + _tknBal) < _amt) {
                    aave.withdraw(wmaticAddr, sub(_amt, (_tknBal + _maticBal)), address(this));
                }
                _tokenContract.withdraw((sub(_amt, _maticBal)));
                msg.sender.call{value: _amt}("");
            } else {
                IERC20 _tokenContract = IERC20(_token);
                uint _tknBal = _tokenContract.balanceOf(address(this));
                if (_tknBal < _amt) {
                    aave.withdraw(_token, sub(_amt, _tknBal), address(this));
                }
                _tokenContract.safeTransfer(msg.sender, _amt);
            }

            _amts[i] = _amt;

            deposits[msg.sender][_token] = sub(maxAmt, _amt);
        }

        isPositionSafe();

        emit LogWithdraw(msg.sender, tokens, _amts);
    }

    // TODO: @mubaris Things to factor
    // If there is same token supply and borrow, then close the smaller one
    // If there is ideal token (other than flashAmt) then payback or deposit according to the position
    // Keep flashAmt tokens as ideal
    // Object is the decrease the ratio and pay as less interest
    function settle() external {

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

        AaveInterface aave = AaveInterface(aaveProvider.getLendingPool());

        transferAtokens(aave, dsa, supplyTokens, supplyAmts);

        // Have to borrow from user's account & transfer
        borrowAndTransferSpells(aave, dsa, borrowTokens, borrowAmts);

        isPositionSafe();
    }

    // TODO: @mubaris - Do we need this?
    function canMigrate(AaveData memory data) public view returns (bool can) {

    }

    function onStateReceive(uint256 stateId, bytes calldata receivedData) external {
        require(stateId > lastStateId, "wrong-data");
        lastStateId = stateId;

        // TODO: what's the best way to store user's data to create position later.
        // Can't do it via any address as user can migrate 2 times 
        positions[stateId] = receivedData;

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
