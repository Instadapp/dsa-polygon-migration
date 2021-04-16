pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;

interface TokenInterface {
    function approve(address, uint256) external;
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external;
    function deposit() external payable;
    function withdraw(uint) external;
    function balanceOf(address) external view returns (uint);
    function decimals() external view returns (uint);
}

interface MemoryInterface {
    function getUint(uint id) external returns (uint num);
    function setUint(uint id, uint val) external;
}
