// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BrandLedgerV1 is Ownable(msg.sender) {
    address public protocolFeeDestination;
    uint256 public protocolFeePercent;

    event Trade(address trader, address brand, string brandName, bool isBuy, uint256 keyAmount, uint256 ethAmount, uint256 protocolEthAmount, uint256 brandEthAmount, uint256 supply);
    event BrandRegistered(address indexed brand, string brandName, uint256 initialSupply, uint256 brandFeePercent);
    event KeysTransferred(address from, address to, address brand, string brandName, uint256 keyAmount);

    // Brands => (Holder => Balance)
    mapping(address => mapping(address => uint256)) public brandKeysBalance;

    // Brands => Supply
    mapping(address => uint256) public brandKeysSupply;

    // Brand => Fee Percent
    mapping(address => uint256) public brandFeePercentages;

    // Brand Address => Brand Name
    mapping(address => string) public brandNames;

    // List of registered brands
    address[] public registeredBrands;

    constructor() {
        protocolFeeDestination = msg.sender;
        protocolFeePercent = 1; // 1% protocol fee
    }

    modifier onlyProtocolFeeDestination() {
        require(msg.sender == protocolFeeDestination, "Not the protocol fee destination");
        _;
    }

    function setFeeDestination(address _feeDestination) public onlyOwner {
        protocolFeeDestination = _feeDestination;
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        protocolFeePercent = _feePercent;
    }

    function registerBrand(address brand, string memory brandName, uint256 initialSupply, uint256 brandFeePercent) public onlyOwner {
        require(brandKeysSupply[brand] == 0, "Brand already registered");
        brandKeysSupply[brand] = initialSupply;
        brandFeePercentages[brand] = brandFeePercent;
        brandNames[brand] = brandName;
        registeredBrands.push(brand);
        emit BrandRegistered(brand, brandName, initialSupply, brandFeePercent);
    }

    function getRegisteredBrands() public view returns (address[] memory) {
        return registeredBrands;
    }

    function getBrandFeePercent(address brand) public view returns (uint256) {
        return brandFeePercentages[brand];
    }

    function getBrandName(address brand) public view returns (string memory) {
        return brandNames[brand];
    }

    function buyBrandKey(address brand, uint256 amount) public payable {
        uint256 supply = brandKeysSupply[brand];
        require(supply > 0 || brand == msg.sender, "Only the brand owner can buy the first key");
        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 brandFee = price * brandFeePercentages[brand] / 1 ether;
        require(msg.value >= price + protocolFee + brandFee, "Insufficient payment");
        brandKeysBalance[brand][msg.sender] = brandKeysBalance[brand][msg.sender] + amount;
        brandKeysSupply[brand] = supply + amount;
        emit Trade(msg.sender, brand, brandNames[brand], true, amount, price, protocolFee, brandFee, supply + amount);
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = brand.call{value: brandFee}("");
        require(success1 && success2, "Unable to send funds");
    }

    function sellBrandKey(address brand, uint256 amount) public payable {
        uint256 supply = brandKeysSupply[brand];
        require(supply > amount, "Cannot sell the last key");
        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 brandFee = price * brandFeePercentages[brand] / 1 ether;
        require(brandKeysBalance[brand][msg.sender] >= amount, "Insufficient keys");
        brandKeysBalance[brand][msg.sender] = brandKeysBalance[brand][msg.sender] - amount;
        brandKeysSupply[brand] = supply - amount;
        emit Trade(msg.sender, brand, brandNames[brand], false, amount, price, protocolFee, brandFee, supply - amount);
        (bool success1, ) = msg.sender.call{value: price - protocolFee - brandFee}("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = brand.call{value: brandFee}("");
        require(success1 && success2 && success3, "Unable to send funds");
    }

    function transferBrandKeys(address to, address brand, uint256 amount) public {
        require(brandKeysBalance[brand][msg.sender] >= amount, "Insufficient keys to transfer");
        brandKeysBalance[brand][msg.sender] -= amount;
        brandKeysBalance[brand][to] += amount;
        emit KeysTransferred(msg.sender, to, brand, brandNames[brand], amount);
    }

    function getPrice(uint256 supply, uint256 amount) internal pure returns (uint256) {
        uint256 sum1 = supply == 0 ? 0 : (supply - 1) * (supply) * (2 * (supply - 1) + 1) / 6;
        uint256 sum2 = supply == 0 && amount == 1 ? 0 : (supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1) / 6;
        uint256 summation = sum2 - sum1;
        return summation * 1 ether / 16000;
    }
}
