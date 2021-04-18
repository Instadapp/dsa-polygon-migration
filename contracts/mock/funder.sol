pragma solidity ^0.7.0;

contract Funder {
    receive() external payable {}

    function kill() external {
        selfdestruct(0x0000000000000000000000000000000000001001);
    }
}