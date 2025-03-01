// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./HederaTokenService.sol";
import "./ExpiryHelper.sol";
import "./KeyHelper.sol";

contract CHTokenManager is HederaTokenService, ExpiryHelper, KeyHelper {
    // Token details
    string name = "ChargeHive";
    string symbol = "CHT";
    string memo = "ChargeHive Token";
    int64 initialTotalSupply = 1000000;
    int64 maxSupply = 1000000000;
    int32 decimals = 0;
    bool freezeDefaultStatus = false;
    bool finiteTotalSupplyType = true;
    
    // Authorized contract addresses that can transfer tokens
    mapping(address => bool) public authorizedContracts;
    
    // Events
    event ResponseCode(int responseCode);
    event CreatedToken(address tokenAddress);
    event MintedToken(int64 newTotalSupply, int64[] serialNumbers);
    event ContractAuthorized(address contractAddress);
    event ContractDeauthorized(address contractAddress);
    event TransferredByAuthorizedContract(address authorizedContract, address to, int64 amount);
    
    // Token address stored after creation
    address public tokenAddress;
    
    // Owner of the contract
    address public owner;
    
    // Modifier to restrict functions to owner only
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    // Modifier to restrict functions to authorized contracts only
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender], "Not authorized to call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Create the custom token with the contract as treasury but operator account keys
     * @param operatorAccount The account that will hold ADMIN and SUPPLY key privileges
     */
    function createToken(address operatorAccount) public onlyOwner payable {
        require(operatorAccount != address(0), "Invalid operator account address");
        
        // Setup token keys - ADMIN and SUPPLY keys set to operator account
        // Other keys inherited from contract account
        IHederaTokenService.TokenKey[] memory keys = new IHederaTokenService.TokenKey[](5);
        
        // Set ADMIN key to operatorAccount (external account)
        keys[0] = getSingleKey(KeyType.ADMIN, KeyType.PAUSE, KeyValueType.INHERIT_ACCOUNT_KEY, abi.encodePacked(operatorAccount));
        
        // Set FREEZE key to contract
        keys[1] = getSingleKey(KeyType.FREEZE, KeyValueType.INHERIT_ACCOUNT_KEY, bytes(""));
        
        // Set WIPE key to contract
        keys[2] = getSingleKey(KeyType.WIPE, KeyValueType.INHERIT_ACCOUNT_KEY, bytes(""));
        
        // Set SUPPLY key to operatorAccount (external account)
        keys[3] = getSingleKey(KeyType.SUPPLY, KeyValueType.INHERIT_ACCOUNT_KEY, abi.encodePacked(operatorAccount));
        
        // Set FEE key to contract
        keys[4] = getSingleKey(KeyType.FEE, KeyValueType.INHERIT_ACCOUNT_KEY, bytes(""));
        
        // Set expiry information
        IHederaTokenService.Expiry memory expiry = IHederaTokenService.Expiry(
            0, address(this), 8000000
        );
        
        // Create token object with contract as treasury
        IHederaTokenService.HederaToken memory token = IHederaTokenService.HederaToken(
            name, symbol, address(this), memo, finiteTotalSupplyType, maxSupply, 
            freezeDefaultStatus, keys, expiry
        );
        
        // Create the fungible token
        (int responseCode, address createdTokenAddress) = 
            HederaTokenService.createFungibleToken(token, initialTotalSupply, decimals);
            
        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert();
        }
        
        // Store the token address
        tokenAddress = createdTokenAddress;
        
        emit CreatedToken(tokenAddress);
    }
    
    /**
     * @dev Authorize a contract to transfer tokens from this contract
     * @param contractAddress The address of the contract to authorize
     */
    function authorizeContract(address contractAddress) public onlyOwner {
        require(contractAddress != address(0), "Invalid contract address");
        authorizedContracts[contractAddress] = true;
        emit ContractAuthorized(contractAddress);
    }
    
    /**
     * @dev Deauthorize a contract from transferring tokens
     * @param contractAddress The address of the contract to deauthorize
     */
    function deauthorizeContract(address contractAddress) public onlyOwner {
        authorizedContracts[contractAddress] = false;
        emit ContractDeauthorized(contractAddress);
    }
    
    /**
     * @dev Check if a contract is authorized
     * @param contractAddress The address to check
     * @return bool True if the contract is authorized
     */
    function isContractAuthorized(address contractAddress) public view returns (bool) {
        return authorizedContracts[contractAddress];
    }
    
    /**
     * @dev Allow authorized contracts to transfer tokens from this contract
     * @param to The recipient of the tokens
     * @param amount The amount of tokens to transfer
     */
    function transferTokensFromTreasury(address to, int64 amount) public onlyAuthorized returns (int responseCode) {
        require(tokenAddress != address(0), "Token not created yet");
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than zero");
        
        // Transfer tokens from this contract to the recipient
        responseCode = HederaTokenService.transferToken(tokenAddress, address(this), to, amount);
        
        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert();
        }
        
        emit TransferredByAuthorizedContract(msg.sender, to, amount);
        
        return responseCode;
    }
    
    /**
     * @dev Associate token to an account (required before transferring)
     * @param account The account to associate with the token
     */
    function associateTokenToAccount(address account) public returns (int responseCode) {
        require(tokenAddress != address(0), "Token not created yet");
        
        responseCode = HederaTokenService.associateToken(account, tokenAddress);
        
        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert();
        }
        
        return responseCode;
    }
    
    /**
     * @dev Grant KYC to an account (if KYC is required for the token)
     * @param account The account to grant KYC to
     */
    function grantKyc(address account) public onlyOwner returns (int responseCode) {
        require(tokenAddress != address(0), "Token not created yet");
        
        responseCode = HederaTokenService.grantTokenKyc(tokenAddress, account);
        
        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert();
        }
        
        return responseCode;
    }
    
    /**
     * @dev Transfer token as owner
     * @param to The recipient address
     * @param amount The amount to transfer
     */
    function transferToken(address to, int64 amount) public onlyOwner returns (int responseCode) {
        require(tokenAddress != address(0), "Token not created yet");
        require(to != address(0), "Invalid recipient address");
        require(amount > 0, "Amount must be greater than zero");
        
        responseCode = HederaTokenService.transferToken(tokenAddress, address(this), to, amount);
        
        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert();
        }
        
        return responseCode;
    }
    
    /**
     * @dev Pauses token transactions (only owner)
     */
    function pauseToken() public onlyOwner returns (int responseCode) {
        require(tokenAddress != address(0), "Token not created yet");
        
        responseCode = HederaTokenService.pauseToken(tokenAddress);
        
        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert();
        }
        
        return responseCode;
    }
    
    /**
     * @dev Unpauses token transactions (only owner)
     */
    function unpauseToken() public onlyOwner returns (int responseCode) {
        require(tokenAddress != address(0), "Token not created yet");
        
        responseCode = HederaTokenService.unpauseToken(tokenAddress);
        
        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert();
        }
        
        return responseCode;
    }
    
    /**
     * @dev Change contract owner (only current owner)
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid owner address");
        owner = newOwner;
    }
}