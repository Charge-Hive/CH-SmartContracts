// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./HederaResponseCodes.sol";
import "./IHederaTokenService.sol";
import "./HederaTokenService.sol";
import "./ExpiryHelper.sol";
import "./KeyHelper.sol";

/**
 * @title ChargeHive NFT Collection
 * @dev NFT collection for ChargeHive parking spots with location data
 */
contract CHParkNFT is ExpiryHelper, KeyHelper, HederaTokenService {
    // Contract owner
    address public owner;
    
    // NFT collection address
    address public chargeHiveCollection;
    
    // Counter for token IDs
    uint256 private tokenIdCounter;
    
    // Mapping to store authorized contracts that can mint/transfer
    mapping(address => bool) public authorizedContracts;
    
    // Events
    event NFTCollectionCreated(address tokenAddress, string name, string symbol);
    event NFTMinted(address tokenAddress, int64 serialNumber, bytes metadata);
    event NFTTransferred(address tokenAddress, int64 serialNumber, address from, address to);
    event ContractAuthorized(address contractAddress, bool status);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyAuthorized() {
        require(
            msg.sender == owner || 
            authorizedContracts[msg.sender], 
            "Not authorized to perform this action"
        );
        _;
    }
    
    constructor() {
        owner = msg.sender;
        tokenIdCounter = 1;
    }
    
    /**
     * @dev Convert uint to string
     * @param _i The uint to convert
     */
    function uint2str(uint _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
    
    /**
     * @dev Creates the ChargeHive NFT collection with infinite supply
     * @param autoRenewPeriod The period after which the token will auto-renew
     */
    function createChargeHiveCollection(int64 autoRenewPeriod, address operatorAccount) external payable onlyOwner returns (address) {
        require(chargeHiveCollection == address(0), "Collection already created");
        
        IHederaTokenService.TokenKey[] memory keys = new IHederaTokenService.TokenKey[](5);
        // Set this contract as supply for the token
        keys[0] = getSingleKey(KeyType.ADMIN, KeyValueType.INHERIT_ACCOUNT_KEY, abi.encodePacked(operatorAccount));
        
        // Supply key
        keys[1] = getSingleKey(KeyType.SUPPLY, KeyValueType.CONTRACT_ID, address(this));
        
        // Freeze key
        keys[2] = getSingleKey(KeyType.FREEZE, KeyValueType.INHERIT_ACCOUNT_KEY,  abi.encodePacked(operatorAccount));
        
        // Wipe key
        keys[3] = getSingleKey(KeyType.WIPE, KeyValueType.INHERIT_ACCOUNT_KEY,  abi.encodePacked(operatorAccount));
        
        keys[4] = getSingleKey(KeyType.FEE, KeyValueType.INHERIT_ACCOUNT_KEY, bytes(""));
        
        IHederaTokenService.HederaToken memory token;
        token.name = "ChargeHive Testing";
        token.symbol = "CHTEST";
        token.memo = "ChargeHive Parking NFT Collection";
        token.treasury = address(this);
        token.tokenSupplyType = false;
        token.tokenKeys = keys;
        token.freezeDefault = false;
        token.expiry = createAutoRenewExpiry(address(this), autoRenewPeriod);
        
        (int responseCode, address createdToken) = HederaTokenService.createNonFungibleToken(token);
        
        if(responseCode != HederaResponseCodes.SUCCESS){
            revert("Failed to create ChargeHive NFT collection");
        }
        
        // Store the token address
        chargeHiveCollection = createdToken;
        
        // Emit event
        emit NFTCollectionCreated(createdToken, "ChargeHive", "CHIVE");
        
        return createdToken;
    }
    
    /**
     * @dev Mints a new parking NFT with provided metadata
     * @param metadata Bytes array containing the NFT metadata
     * @return serial number of the minted NFT
     */
    function mintParkingNFT(
        bytes[] memory metadata
    ) public onlyAuthorized returns (int64) {
        require(chargeHiveCollection != address(0), "Collection not created yet");
        
        // Mint the NFT
        (int response, , int64[] memory serial) = HederaTokenService.mintToken(chargeHiveCollection, 0, metadata);
        
        if(response != HederaResponseCodes.SUCCESS){
            revert("Failed to mint ChargeHive NFT");
        }
        
        // Emit event
        emit NFTMinted(
            chargeHiveCollection, 
            serial[0], 
            metadata[0]
        );
        
        return serial[0];
    }
    
    /**
     * @dev Mints and transfers in one operation (convenience function)
     * @param metadata Bytes array containing the NFT metadata
     * @param receiver Address to receive the minted NFT
     * @return serial number of the minted NFT
     */
    function mintAndTransferNFT(
        bytes[] memory metadata,
        address receiver
    ) external onlyAuthorized returns (int64) {
        // First mint the NFT
        int64 serial = mintParkingNFT(metadata);
        
        // Then transfer it
        transferNft(receiver, serial);
        
        return serial;
    }
    
    /**
     * @dev Transfers an NFT from this contract to a receiver
     * @param receiver The address to receive the NFT
     * @param serial The serial number of the NFT
     * @return response code from Hedera
     */
    function transferNft(
        address receiver, 
        int64 serial
    ) public onlyAuthorized returns (int) {
        require(chargeHiveCollection != address(0), "Collection not created yet");
        
        int response = HederaTokenService.transferNFT(chargeHiveCollection, address(this), receiver, serial);
        
        if(response != HederaResponseCodes.SUCCESS) {
            revert("Failed to transfer ChargeHive NFT");
        }
        
        // Emit event
        emit NFTTransferred(chargeHiveCollection, serial, address(this), receiver);
        
        return response;
    }
    
    /**
     * @dev Transfers an NFT from one address to another (authorized only)
     * @param from The address sending the NFT
     * @param to The address receiving the NFT
     * @param serial The serial number of the NFT
     * @return response code from Hedera
     */
    function transferNftBetweenAccounts(
        address from,
        address to, 
        int64 serial
    ) external onlyAuthorized returns (int) {
        require(chargeHiveCollection != address(0), "Collection not created yet");
        
        int response = HederaTokenService.transferNFT(chargeHiveCollection, from, to, serial);
        
        if(response != HederaResponseCodes.SUCCESS) {
            revert("Failed to transfer ChargeHive NFT between accounts");
        }
        
        // Emit event
        emit NFTTransferred(chargeHiveCollection, serial, from, to);
        
        return response;
    }
    
    /**
     * @dev Authorizes a contract to mint and transfer NFTs
     * @param contractAddress The address of the contract to authorize
     */
    function authorizeContract(
        address contractAddress
    ) public onlyOwner {
        authorizedContracts[contractAddress] = true;
        
        // Emit event
        emit ContractAuthorized(contractAddress, true);
    }
    
    /**
     * @dev Transfers ownership of the contract
     * @param newOwner The address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be the zero address");
        owner = newOwner;
    }
    
    /**
     * @dev Checks if a contract is authorized
     * @param contractAddress The address of the contract to check
     */
    function isContractAuthorized(
        address contractAddress
    ) external view returns (bool) {
        return authorizedContracts[contractAddress];
    }
    
    /**
     * @dev Gets the address of the ChargeHive collection
     */
    function getCollectionAddress() external view returns (address) {
        return chargeHiveCollection;
    }
    
    /**
     * @dev Gets the current token ID counter
     */
    function getCurrentTokenId() external view returns (uint256) {
        return tokenIdCounter;
    }
}