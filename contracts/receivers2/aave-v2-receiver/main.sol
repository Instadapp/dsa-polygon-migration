pragma solidity >=0.7.0;
pragma experimental ABIEncoderV2;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { AccountInterface, AaveData } from "./interfaces.sol";
import { Events } from "./events.sol";
import { Helpers } from "./helpers.sol";

contract MigrateResolver is Helpers, Events {
    using SafeERC20 for IERC20;

    // This will be used to have debt/collateral ratio always 20% less than liquidation
    // TODO: Is this number correct for it?
    uint public safeRatioGap = 20000000000000000; // 20%?

    // dsa => position
    mapping(uint => AaveData) public positions;
    mapping(address => mapping(address => uint)) deposits;
    // TODO: Add function for flash deposits and withdraw
    mapping(address => mapping(address => uint)) flashDeposits; // Flash deposits of particular token
    mapping(address => uint) flashAmts; // token amount for flashloan usage (these token will always stay raw in this contract)
    // TODO: need to add function to add this mapping
    mapping(address => address) tokensL1L2; // L1 tokens mapping to L2 tokens. Eg:- L1 DAI to L2 DAI

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
        AaveData storage data = _data;

        address dsa = _data.targetDsa;
        address[] memory supplyAmts = _data.supplyAmts;
        address[] memory borrowAmts = _data.borrowAmts;
        address[] memory supplyTokens = _data.supplyTokens;
        address[] memory borrowTokens = _data.borrowTokens;

        for (uint i = 0; i < supplyTokens.length; i++) {
            address _token = tokensL1L2[supplyTokens[i]];
            IERC20 _atokenContract = IERC20(_token); // TODO: Fetch atoken from Aave mapping (change _token to atoken address)
            uint _atokenBal = _atokenContract.balanceOf(address(this));
            uint _supplyAmt = supplyAmts[i];
            if (_atokenBal < _supplyAmt) {
                // TODO: Loop in the token. by borrow & supply to desirable amount
                // Things to take into consideration:
                // number of loops (have to check from liquidity available in Aave & accounts borrowing limit with every loop it'll decrease)
            }
            _atokenContract.safeTransfer(dsa, _supplyAmt);
        }

        // Have to borrow from user's account
        for (uint i = 0; i < borrowTokens.length; i++) {
            address _token = tokensL1L2[borrowTokens[i]];
            // get Aave liquidity of token
            uint tokenLiq = uint(0);
            uint _borrowAmt = borrowAmts[i];
            if (tokenLiq < _borrowAmt) {
                // deposit flash amt in Aave
                uint _flashAmt = flashAmts[_token];
                // TODO: deposit in Aave
                tokenLiq += _flashAmt;
            }
            // TODO: Check number of loops needed. Borrow and supply on user's account.
            uint num = _borrowAmt/tokenLiq + 1; // TODO: Is this right
            uint splitAmt = _borrowAmt/num; // TODO: Check decimal
            uint finalSplit = _borrowAmt - (splitAmt * (num - 1)); // TODO: to resolve upper decimal error

            uint spellsAmt = num + 1;
            string[] memory targets = string[](spellsAmt);
            bytes[] memory castData = bytes[](spellsAmt);
            for (uint j = 0; j < num; j++) {
                targets[j] = "AAVE-A";
                if (i < num - 1) {
                    castData[j] = bytes(0); // encode the cast data & use splitAmt
                } else {
                    castData[j] = bytes(0); // encode the cast data & use finalSplit
                }
            }
            targets[spellsAmt] = "BASIC-A"; // TODO: right spell?
            castData[spellsAmt] = bytes(0); // encode the data of atoken withdrawal
            // TODO: Call DSAs cast and borrow (maybe create a new implementation which only this contract can run?)
        }

        // TODO: Final position should be 20% less than liquidation (use 'safeRatioGap', Also should we check this at start?)
    }

    function getPosition(address owner) public view returns (AaveData memory data) {
        data = positions[owner];
    }

    // have to add more conditions
    function canMigrate(AaveData calldata data) public view returns (bool can) {
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
        require(stateId > lastStateId, "wrong-data");
        lastStateId = stateId;

        (AaveData memory data) = abi.decode(receivedData, (AaveData));
        positions[stateId] = data; // TODO: what's the best way to store user's data to create position later

    }

    function migrate(uint _id) external {
        AaveData memory data = positions[_id];

        require(data != AaveData(0), "already-migrated");

        require(canMigrate(data), "not-enough-liquidity"); // TODO: do we need this? as we can see if transaction will go through or not from our bot

        _migratePosition(data);

        delete positions[_id];
    }
}