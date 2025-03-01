// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./HederaResponseCodes.sol";
import "./HederaTokenService.sol";

// Interface for custom token contract
interface ICustomTokenContract {
    function transferTokensFromTreasury(address to, int64 amount) external returns (int responseCode);
    function tokenAddress() external view returns (address);
}

// Interface for NFT contract
interface ICustomNFTContract {
    function mintAndTransferNFT(
        bytes[] memory metadata,
        address receiver
    ) external returns (int64);
    function getCollectionAddress() external view returns (address);
}

/**
 * @title CHParking
 * @dev Contract to manage parking sessions with rewards using ChargeHive NFTs and CHT tokens
 */
contract CHParking is HederaTokenService {
    // Contracts
    ICustomNFTContract public nftContract;
    ICustomTokenContract public chtTokenContract;
    
    // Contract owner
    address public owner;
    
    // Authorized administrators who can call functions
    mapping(address => bool) public admins;
    
    // User account details - simplified structure
    struct UserAccount {
        int64 serialNumber;      // NFT serial number
        bool isRegistered;       // User registration status
        string evmAddress;       // EVM address
    }
    
    // Parking session details
    struct ParkingSession {
        uint256 id;              // Unique session ID
        uint256 startTime;       // Session start timestamp
        uint256 endTime;         // Session end timestamp
        address userWallet;      // User's wallet address
        address spotBookerWallet; // Parking spot booker's wallet
        bool isActive;           // Session status
        bool isRewarded;         // Reward status
    }
    
    // Mapping wallet address to user accounts
    mapping(address => UserAccount) public userAccounts;
    
    // All parking sessions
    ParkingSession[] public parkingSessions;
    
    // Mapping wallet address to user's session IDs
    mapping(address => uint256[]) public userSessions;
    
    // Counter for session IDs
    uint256 private sessionIdCounter;
    
    // Events
    event AdminAdded(address adminAddress);
    event AdminRemoved(address adminAddress);
    event AccountCreated(address userWallet, int64 serialNumber);
    event ParkingSessionCreated(uint256 sessionId, address userWallet, address spotBookerWallet, uint256 startTime, uint256 endTime);
    event ParkingSessionEnded(uint256 sessionId, uint256 actualEndTime);
    event RewardDistributed(address userWallet, int64 rewardAmount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyAdmin() {
        require(admins[msg.sender] || msg.sender == owner, "Only admins can call this function");
        _;
    }
    
    /**
     * @dev Constructor to initialize the contract with NFT and token contract addresses
     * @param _nftContractAddress The ChargeHive NFT contract address
     * @param _chtTokenContractAddress The CHT token contract address
     */
    constructor(address _nftContractAddress, address _chtTokenContractAddress) {
        require(_nftContractAddress != address(0), "Invalid NFT contract address");
        require(_chtTokenContractAddress != address(0), "Invalid CHT token contract address");
        
        nftContract = ICustomNFTContract(_nftContractAddress);
        chtTokenContract = ICustomTokenContract(_chtTokenContractAddress);
        owner = msg.sender;
        admins[msg.sender] = true; // Owner is also an admin
        sessionIdCounter = 1; // Start with session ID 1
    }
    
    /**
     * @dev Add a new admin
     * @param adminAddress The address to add as admin
     */
    function addAdmin(address adminAddress) external onlyOwner {
        require(adminAddress != address(0), "Invalid admin address");
        require(!admins[adminAddress], "Address is already an admin");
        
        admins[adminAddress] = true;
        emit AdminAdded(adminAddress);
    }
    
    /**
     * @dev Remove an admin
     * @param adminAddress The address to remove as admin
     */
    function removeAdmin(address adminAddress) external onlyOwner {
        require(admins[adminAddress], "Address is not an admin");
        require(adminAddress != owner, "Cannot remove owner from admins");
        
        admins[adminAddress] = false;
        emit AdminRemoved(adminAddress);
    }
    
    /**
     * @dev Create user account and mint NFT
     * @param userWallet User's wallet address
     * @param metadata Link to the profile/parking space image
     */
    function createAccount(
        address userWallet,
        string memory accountid,
        bytes[] memory metadata
    ) external onlyAdmin {
        require(userWallet != address(0), "Invalid user wallet address");
        require(!userAccounts[userWallet].isRegistered, "User already registered");
        
        // Mint and transfer NFT to user wallet using NFT contract
        int64 serialNumber = nftContract.mintAndTransferNFT(metadata, userWallet);
        
        // Store simplified user account details
        userAccounts[userWallet] = UserAccount({
            serialNumber: serialNumber,
            isRegistered: true,
            evmAddress: accountid
        });
        
        emit AccountCreated(userWallet, serialNumber);
    }
    
    /**
     * @dev Get user's NFT serial number
     * @param userWallet User's wallet address
     * @return serialNumber NFT serial number
     */
    function getUserSerialNumber(address userWallet) external view returns (int64) {
        require(userAccounts[userWallet].isRegistered, "User not registered");
        return userAccounts[userWallet].serialNumber;
    }
    
    /**
     * @dev Check if user is registered
     * @param userWallet User's wallet address
     * @return isRegistered Registration status
     */
    function isUserRegistered(address userWallet) external view returns (bool) {
        return userAccounts[userWallet].isRegistered;
    }
    
    /**
     * @dev Get user account details
     * @param userWallet User's wallet address
     * @return User account details
     */
    function getUserAccount(address userWallet) external view returns (UserAccount memory) {
        require(userAccounts[userWallet].isRegistered, "User not registered");
        return userAccounts[userWallet];
    }
    
    /**
     * @dev Create a new parking session
     * @param startTime Session start time (UNIX timestamp)
     * @param endTime Session end time (UNIX timestamp)
     * @param userWallet User's wallet address
     * @param spotBookerWallet Parking spot booker's wallet address
     * @return sessionId Unique session ID
     */
    function createParkingSession(
        uint256 startTime,
        uint256 endTime,
        address userWallet,
        address spotBookerWallet
    ) external onlyAdmin returns (uint256) {
        require(userAccounts[userWallet].isRegistered, "User not registered");
        require(startTime < endTime, "End time must be after start time");
        require(startTime >= block.timestamp, "Start time must be in the future");
        
        // Create new parking session
        uint256 sessionId = sessionIdCounter++;
        
        ParkingSession memory newSession = ParkingSession({
            id: sessionId,
            startTime: startTime,
            endTime: endTime,
            userWallet: userWallet,
            spotBookerWallet: spotBookerWallet,
            isActive: true,
            isRewarded: false
        });
        
        // Add to parking sessions array
        parkingSessions.push(newSession);
        
        // Add to user's sessions
        userSessions[userWallet].push(sessionId);
        
        emit ParkingSessionCreated(sessionId, userWallet, spotBookerWallet, startTime, endTime);
        
        return sessionId;
    }
    
    /**
     * @dev End an active parking session
     * @param sessionId Session ID to end
     */
    function endParkingSession(uint256 sessionId) external onlyAdmin {
        require(sessionId > 0 && sessionId < sessionIdCounter, "Invalid session ID");
        
        ParkingSession storage session = parkingSessions[sessionId - 1];
        require(session.isActive, "Session is not active");
        
        session.isActive = false;
        session.endTime = block.timestamp; // Update end time to current time
        
        emit ParkingSessionEnded(sessionId, block.timestamp);
    }
    
    /**
     * @dev Calculate and distribute rewards for a parking session
     * @param sessionId Session ID to reward
     * @param multiplier Reward multiplier
     */
    function calculateAndDistributeRewards(
        uint256 sessionId,
        uint256 multiplier
    ) external onlyAdmin {
        require(sessionId > 0 && sessionId < sessionIdCounter, "Invalid session ID");
        
        ParkingSession storage session = parkingSessions[sessionId - 1];
        require(!session.isActive, "Session is still active");
        require(!session.isRewarded, "Session already rewarded");
        
        // Calculate duration in minutes
        uint256 duration = (session.endTime - session.startTime) / 60;
        
        // Calculate reward amount (1 token per minute * multiplier)
        // Convert to int64 for the token contract
        int64 rewardAmount = int64(int256(duration * multiplier));
        
        // Make sure we don't exceed max token value
        require(rewardAmount > 0, "Reward amount must be positive");
        
        // Mark session as rewarded
        session.isRewarded = true;
        
        // Transfer tokens to user using the custom token contract
        int responseCode = chtTokenContract.transferTokensFromTreasury(session.userWallet, rewardAmount);
        
        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert("Failed to transfer reward tokens");
        }
        
        emit RewardDistributed(session.userWallet, rewardAmount);
    }
    
    /**
     * @dev Associate token to user if needed
     * @param userWallet User's wallet address
     * @param tokenAddress The token to associate
     */
    function associateTokenToUser(address userWallet, address tokenAddress) external onlyAdmin {
        int response = HederaTokenService.associateToken(userWallet, tokenAddress);
        
        // It's acceptable if the token is already associated
        require(
            response == HederaResponseCodes.SUCCESS || 
            response == HederaResponseCodes.TOKEN_ALREADY_ASSOCIATED_TO_ACCOUNT,
            "Failed to associate token"
        );
    }
    
    /**
     * @dev Get the CHT token address from the token contract
     * @return The CHT token address
     */
    function getCHTTokenAddress() external view returns (address) {
        return chtTokenContract.tokenAddress();
    }
    
    /**
     * @dev Get the NFT collection address from the NFT contract
     * @return The NFT collection address
     */
    function getNFTCollectionAddress() external view returns (address) {
        return nftContract.getCollectionAddress();
    }
    
    /**
     * @dev Get all sessions for a user
     * @param userWallet User's wallet address
     * @return sessionIds Array of user's session IDs
     */
    function getUserSessions(address userWallet) external view returns (uint256[] memory) {
        return userSessions[userWallet];
    }
    
    /**
     * @dev Get session details by ID
     * @param sessionId Session ID
     * @return Session details
     */
    function getSessionDetails(uint256 sessionId) external view returns (ParkingSession memory) {
        require(sessionId > 0 && sessionId < sessionIdCounter, "Invalid session ID");
        return parkingSessions[sessionId - 1];
    }
    
    /**
     * @dev Get active sessions for a user
     * @param userWallet User's wallet address
     * @return sessionIds Array of user's active session IDs
     */
    function getActiveUserSessions(address userWallet) external view returns (uint256[] memory) {
        uint256[] memory allSessions = userSessions[userWallet];
        
        // First count active sessions
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allSessions.length; i++) {
            if (parkingSessions[allSessions[i] - 1].isActive) {
                activeCount++;
            }
        }
        
        // Create array of active sessions
        uint256[] memory activeSessions = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < allSessions.length; i++) {
            if (parkingSessions[allSessions[i] - 1].isActive) {
                activeSessions[index++] = allSessions[i];
            }
        }
        
        return activeSessions;
    }
    
    /**
     * @dev Transfer contract ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner address");
        owner = newOwner;
        admins[newOwner] = true;
    }
}