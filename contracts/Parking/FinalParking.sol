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

/**
 * @title CHParking
 * @dev Contract to manage parking sessions with rewards using CHT tokens
 */
contract CHParking is HederaTokenService {
    // Contracts
    address public customTokenContract; // The address of the custom token contract
    address public tokenAddress;       // The actual token address
    
    // Contract owner
    address public owner;
    
    // Authorized administrators who can call functions
    mapping(address => bool) public admins;
    
    // User account details - simplified structure
    struct UserAccount {
        string nftId;           // NFT ID as string
        bool isRegistered;      // User registration status
        string evmAddress;      // EVM address
    }
    
    // Parking session details
    struct ParkingSession {
        uint256 id;              // Unique session ID
        int64 startTime;       // Session start timestamp
        int64 endTime;         // Session end timestamp
        address userWallet;      // User's wallet address
        address spotBookerWallet; // Parking spot booker's wallet
        bool isActive;           // Session status
        bool isRewarded;         // Reward status
        int64 calculatedReward;  // Calculated reward amount
    }
    
    // Configuration
    int64 public rewardRatePerMinute;  // Base reward rate per minute
    
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
    event AccountCreated(address userWallet, string nftId);
    event ParkingSessionCreated(uint256 sessionId, address userWallet, address spotBookerWallet, int64 startTime, int64 endTime);
    event ParkingSessionEnded(uint256 sessionId, uint256 actualEndTime);
    event RewardDistributed(address userWallet, int64 rewardAmount, uint256 sessionId);
    event RewardRateUpdated(int64 newRate);
    
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
     * @dev Constructor to initialize the contract with token contract address and reward rate
     * @param _customTokenContractAddress The custom token contract address
     * @param _initialRewardRate Initial reward rate per minute
     */
    constructor(
        address _customTokenContractAddress,
        int64 _initialRewardRate
    ) {
        require(_customTokenContractAddress != address(0), "Invalid custom token contract address");
        require(_initialRewardRate > 0, "Invalid reward rate");
        
        customTokenContract = _customTokenContractAddress;
        tokenAddress = ICustomTokenContract(_customTokenContractAddress).tokenAddress();
        require(tokenAddress != address(0), "Token address not available");
        
        rewardRatePerMinute = _initialRewardRate;
        
        owner = msg.sender;
        admins[msg.sender] = true; // Owner is also an admin
        sessionIdCounter = 1; // Start with session ID 1
    }
    
    /**
     * @dev Update reward rate per minute
     * @param newRate New reward rate
     */
    function updateRewardRate(int64 newRate) external onlyOwner {
        require(newRate > 0, "Rate must be positive");
        rewardRatePerMinute = newRate;
        emit RewardRateUpdated(newRate);
    }
    
    /**
     * @dev Add a new admin
     * @param adminAddress The address to add as admin
     */
    function addAdmin(address adminAddress) public onlyOwner {
        require(adminAddress != address(0), "Invalid admin address");
        require(!admins[adminAddress], "Address is already an admin");
        
        admins[adminAddress] = true;
        emit AdminAdded(adminAddress);
    }
    
    /**
     * @dev Remove an admin
     * @param adminAddress The address to remove as admin
     */
    function removeAdmin(address adminAddress) public onlyOwner {
        require(admins[adminAddress], "Address is not an admin");
        require(adminAddress != owner, "Cannot remove owner from admins");
        
        admins[adminAddress] = false;
        emit AdminRemoved(adminAddress);
    }
    
    /**
     * @dev Create user account with existing NFT ID
     * @param userWallet User's wallet address
     * @param nftId User's NFT ID as string
     * @param accountId User's account ID
     */
    function createAccount(
        address userWallet,
        string memory nftId,
        string memory accountId
    ) public onlyAdmin {
        require(userWallet != address(0), "Invalid user wallet address");
        require(!userAccounts[userWallet].isRegistered, "User already registered");
        require(bytes(nftId).length > 0, "NFT ID cannot be empty");

        userAccounts[userWallet] = UserAccount({
            nftId: nftId,
            isRegistered: true,
            evmAddress: accountId
        });
        
        emit AccountCreated(userWallet, nftId);
    }
    
    /**
     * @dev Get user's NFT ID
     * @param userWallet User's wallet address
     * @return nftId NFT ID as string
     */
    function getUserNftId(address userWallet) public view returns (string memory) {
        require(userAccounts[userWallet].isRegistered, "User not registered");
        return userAccounts[userWallet].nftId;
    }
    
    /**
     * @dev Check if user is registered
     * @param userWallet User's wallet address
     * @return isRegistered Registration status
     */
    function isUserRegistered(address userWallet) public view returns (bool) {
        return userAccounts[userWallet].isRegistered;
    }
    
    /**
     * @dev Get user account details
     * @param userWallet User's wallet address
     * @return User account details
     */
    function getUserAccount(address userWallet) public view returns (UserAccount memory) {
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
        int64 startTime,
        int64 endTime,
        address userWallet,
        address spotBookerWallet
    ) public onlyAdmin returns (uint256) {
        require(userAccounts[userWallet].isRegistered, "User not registered");

        // Create new parking session
        uint256 sessionId = sessionIdCounter++;
        
        ParkingSession memory newSession = ParkingSession({
            id: sessionId,
            startTime: startTime,
            endTime: endTime,
            userWallet: userWallet,
            spotBookerWallet: spotBookerWallet,
            isActive: true,
            isRewarded: false,
            calculatedReward: 0
        });
        
        // Add to parking sessions array
        parkingSessions.push(newSession);
        
        // Add to user's sessions
        userSessions[userWallet].push(sessionId);
        
        emit ParkingSessionCreated(sessionId, userWallet, spotBookerWallet, startTime, endTime);
        
        return sessionId;
    }
    
    /**
     * @dev End an active parking session and calculate rewards
     * @param sessionId Session ID to end
     * @param multiplier Reward multiplier
     * @return calculatedReward The calculated reward amount
     */
    function endParkingSession(
        uint256 sessionId,
        int64 multiplier
    ) public onlyAdmin returns (int64 calculatedReward) {
        require(sessionId > 0 && sessionId < sessionIdCounter, "Invalid session ID");
        require(multiplier > 0, "Multiplier must be positive");
        
        ParkingSession storage session = parkingSessions[sessionId - 1];
        require(session.isActive, "Session is not active");
        
        session.isActive = false;
        
        // Calculate duration in minutes
        int64 duration = (session.endTime - session.startTime) / 60;
        require(duration > 0, "Duration must be positive");
        
        // Calculate reward
        calculatedReward = duration * rewardRatePerMinute * multiplier;
        session.calculatedReward = calculatedReward;
        
        emit ParkingSessionEnded(sessionId, block.timestamp);
        
        return calculatedReward;
    }
    
    /**
     * @dev Distribute rewards for a completed parking session
     * @param sessionId Session ID to reward
     * @return success Whether the reward distribution was successful
     */
    function distributeRewards(uint256 sessionId) 
        external 
        onlyAdmin 
        returns (bool success) 
    {
        require(sessionId > 0 && sessionId < sessionIdCounter, "Invalid session ID");
        
        ParkingSession storage session = parkingSessions[sessionId - 1];
        require(!session.isActive, "Session is still active");
        require(!session.isRewarded, "Session already rewarded");
        require(session.calculatedReward > 0, "No rewards calculated");
        
        int responseCode = ICustomTokenContract(customTokenContract).transferTokensFromTreasury(
            session.userWallet, 
            session.calculatedReward
        );
        
        if (responseCode != HederaResponseCodes.SUCCESS) {
            return false;
        }
        
        session.isRewarded = true;
        
        emit RewardDistributed(session.userWallet, session.calculatedReward, sessionId);
        return true;
    }
    
    /**
     * @dev Associate token to user if needed
     * @param userWallet User's wallet address
     * @return responseCode The Hedera response code
     */
    function associateTokenToUser(address userWallet) public onlyAdmin returns (int responseCode) {
        responseCode = HederaTokenService.associateToken(userWallet, tokenAddress);
        return responseCode;
    }
    
    /**
     * @dev Get the CHT token address
     * @return The CHT token address
     */
    function getCHTTokenAddress() public view returns (address) {
        return tokenAddress;
    }
    
    function getSessionDetails(uint256 sessionId) 
        external 
        view 
        returns (
            uint256 id,
            int64 startTime,
            int64 endTime,
            address userWallet,
            address spotBookerWallet,
            bool isActive,
            bool isRewarded,
            int64 calculatedReward
        ) 
    {
        require(sessionId > 0 && sessionId < sessionIdCounter, "Invalid session ID");
        ParkingSession memory session = parkingSessions[sessionId - 1];
        
        return (
            session.id,
            session.startTime,
            session.endTime,
            session.userWallet,
            session.spotBookerWallet,
            session.isActive,
            session.isRewarded,
            session.calculatedReward
        );
    }
    
    /**
     * @dev Associate the contract with the token
     * @return responseCode The Hedera response code
     */
    function associateWithToken() external onlyOwner returns (int responseCode) {
        responseCode = HederaTokenService.associateToken(address(this), tokenAddress);
        return responseCode;
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