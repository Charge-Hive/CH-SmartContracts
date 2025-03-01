// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./HederaTokenService.sol";
import "./CHUtils/StringUtils.sol";
import "./CHUtils/WordList.sol";
import "./CHUtils/SessionLib.sol";

interface ICustomTokenContract {
    function transferTokensFromTreasury(address to, int64 amount) external returns (int responseCode);
    function tokenAddress() external view returns (address);
}

contract CHAdapter is HederaTokenService {
    using StringUtils for bytes32;
    using SessionLib for SessionLib.Session[];
    
    // Adapter structure
    struct Adapter {
        address wallet;
        string DID;
        string nftId;
        SessionLib.Session[] sessions;
        string details;
        bool authorized;
        bool registered;
        uint256 createdAt;
    }
    
    // Contract owner and token info
    address public customTokenContract;
    address public tokenAddress;
    address public owner;
    
    // Configuration
    int64 public rewardRatePerKwh;
    int64 public minimumKwh;
    int64 public pricePerKwhUsd;
    
    // Session tracking
    uint256 public totalSessionCount;
    
    // Mappings
    mapping(address => Adapter) public adapters;
    mapping(string => address) public didToAdapter;
    mapping(address => address[]) public userAdapters;
    mapping(string => bool) public activeSessions;
    mapping(string => address) public sessionToAdapter;
    
    // Events
    event AdapterInitialized(address adapter);
    event AdapterRegistered(address adapter, string DID, address wallet);
    event AdapterAuthorized(address adapter, bool authorized);
    event AdapterNFTSet(address adapter, string nftId);  // Changed from address to string
    event SessionStarted(address adapter, string sessionId, address userWallet, uint256 timestamp);
    event SessionEnded(address adapter, string sessionId, int64 energyUsed, int64 reward, int64 usdCost, uint256 timestamp);
    event RewardDistributed(address adapter, address userWallet, int64 reward, string sessionId);
    event RewardRateUpdated(int64 newRate);
    event MinimumKwhUpdated(int64 newMinimum);
    event PricePerKwhUpdated(int64 newPrice);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    modifier onlyAuthorizedAdapter() {
        require(adapters[msg.sender].authorized, "Not authorized");
        _;
    }
    
    modifier adapterExists(address adapter) {
        require(adapters[adapter].registered, "Adapter not found");
        _;
    }
    
    modifier onlySelf() {
        require(msg.sender == address(this), "Only self");
        _;
    }
    
    constructor(
        address _customTokenContract,
        int64 _initialRewardRate,
        int64 _minimumKwh,
        int64 _initialPricePerKwhUsd
    ) {
        require(_customTokenContract != address(0), "Invalid token address");
        require(_initialRewardRate > 0, "Invalid reward rate");
        require(_minimumKwh >= 0, "Invalid min kWh");
        require(_initialPricePerKwhUsd > 0, "Invalid price");
        
        customTokenContract = _customTokenContract;
        tokenAddress = ICustomTokenContract(customTokenContract).tokenAddress();
        require(tokenAddress != address(0), "Token not created");
        
        owner = msg.sender;
        rewardRatePerKwh = _initialRewardRate;
        minimumKwh = _minimumKwh;
        pricePerKwhUsd = _initialPricePerKwhUsd;
    }
    
    function generateDID(address adapterAddress, address userWallet) internal view returns (string memory) {
        bytes32 hash = keccak256(abi.encodePacked(
            adapterAddress, 
            userWallet, 
            block.timestamp
        ));
        
        uint8 word1Index = uint8(hash[0]) % 50;
        uint8 word2Index = uint8(hash[15]) % 50; 
        uint8 word3Index = uint8(hash[31]) % 50;
        
        return string(abi.encodePacked(
            "did:hedera:", 
            WordList.getWord(word1Index), 
            "-", 
            WordList.getWord(word2Index), 
            "-", 
            WordList.getWord(word3Index)
        ));
    }
    
    function updatePricePerKwhUsd(int64 newPrice) external onlyOwner {
        require(newPrice > 0, "Price must be positive");
        pricePerKwhUsd = newPrice;
        emit PricePerKwhUpdated(newPrice);
    }
    
    // Owner initializes adapter (without DID and wallet)
    function initializeAdapter(address adapterAddress) 
        external 
        onlyOwner 
    {
        require(adapterAddress != address(0), "Invalid adapter");
        require(!adapters[adapterAddress].registered, "Already registered");
        
        Adapter storage newAdapter = adapters[adapterAddress];
        newAdapter.registered = true;
        newAdapter.createdAt = block.timestamp;
        
        emit AdapterInitialized(adapterAddress);
    }
    
    // Owner authorizes or deauthorizes an adapter
    function setAdapterAuthorization(address adapterAddress, bool authorized) 
        external 
        onlyOwner 
        adapterExists(adapterAddress) 
    {
        adapters[adapterAddress].authorized = authorized;
        emit AdapterAuthorized(adapterAddress, authorized);
    }
    
    // Adapter completes its own registration by setting wallet and generating DID
    function completeRegistration(address userWallet, string calldata details) 
        external 
        adapterExists(msg.sender)
        returns (string memory did)
    {
        require(userWallet != address(0), "Invalid wallet");
        require(bytes(adapters[msg.sender].DID).length == 0, "Already completed");
        require(bytes(details).length > 0, "Details required");
        
        did = generateDID(msg.sender, userWallet);
        
        adapters[msg.sender].wallet = userWallet;
        adapters[msg.sender].DID = did;
        adapters[msg.sender].details = details;
        
        didToAdapter[did] = msg.sender;
        userAdapters[userWallet].push(msg.sender);
        
        emit AdapterRegistered(msg.sender, did, userWallet);
        
        return did;
    }
    
    // Adapter sets its own NFT ID - changed from address to string
    function setAdapterNFT(string calldata nftId) 
        external 
        adapterExists(msg.sender)
    {
        require(bytes(nftId).length > 0, "Invalid NFT ID");
        adapters[msg.sender].nftId = nftId;
        emit AdapterNFTSet(msg.sender, nftId);
    }
    
    function updateRewardRate(int64 newRate) external onlyOwner {
        require(newRate > 0, "Rate must be positive");
        rewardRatePerKwh = newRate;
        emit RewardRateUpdated(newRate);
    }
    
    function updateMinimumKwh(int64 newMinimum) external onlyOwner {
        require(newMinimum >= 0, "Cannot be negative");
        minimumKwh = newMinimum;
        emit MinimumKwhUpdated(newMinimum);
    }
    
    function startSession(address userWallet, string calldata location) 
        external 
        onlyAuthorizedAdapter 
        returns (string memory sessionId) 
    {
        require(userWallet != address(0), "Invalid wallet");
        
        sessionId = SessionLib.generateSessionId(msg.sender, userWallet, block.timestamp, totalSessionCount);
        require(!activeSessions[sessionId], "ID collision");
        
        SessionLib.Session memory newSession = SessionLib.Session({
            sessionId: sessionId,
            startTimestamp: block.timestamp,
            endTimestamp: 0,
            energyUsed: 0,
            multiplier: 1,
            calculatedReward: 0,
            calculatedUSD: 0,
            active: true,
            tokenDistributed: false,
            userWallet: userWallet,
            location: location
        });
        
        adapters[msg.sender].sessions.push(newSession);
        activeSessions[sessionId] = true;
        sessionToAdapter[sessionId] = msg.sender;
        totalSessionCount++;
        
        emit SessionStarted(msg.sender, sessionId, userWallet, block.timestamp);
        return sessionId;
    }
    
    function endSession(string calldata sessionId, int64 energyUsed, int64 multiplier) 
        external 
        onlyAuthorizedAdapter 
        returns (int64 reward, int64 usdCost) 
    {
        require(activeSessions[sessionId], "Not active");
        require(sessionToAdapter[sessionId] == msg.sender, "Not your session");
        require(energyUsed > 0, "Energy must be positive");
        require(multiplier > 0, "Multiplier must be positive");
        
        uint256 sessionIndex = adapters[msg.sender].sessions.findSessionIndex(sessionId);
        require(sessionIndex < adapters[msg.sender].sessions.length, "Session not found");
        
        adapters[msg.sender].sessions[sessionIndex].endTimestamp = block.timestamp;
        adapters[msg.sender].sessions[sessionIndex].energyUsed = energyUsed;
        adapters[msg.sender].sessions[sessionIndex].multiplier = multiplier;
        adapters[msg.sender].sessions[sessionIndex].active = false;
        
        if (energyUsed >= minimumKwh) {
            reward = energyUsed * rewardRatePerKwh * multiplier;
            adapters[msg.sender].sessions[sessionIndex].calculatedReward = reward;
        } else {
            reward = 0;
            adapters[msg.sender].sessions[sessionIndex].calculatedReward = 0;
        }
        
        usdCost = (energyUsed * pricePerKwhUsd) / 10;
        adapters[msg.sender].sessions[sessionIndex].calculatedUSD = usdCost;
        
        activeSessions[sessionId] = false;
        
        emit SessionEnded(msg.sender, sessionId, energyUsed, reward, usdCost, block.timestamp);
        return (reward, usdCost);
    }
    
    function distributeRewards(string calldata sessionId) 
        external 
        onlyAuthorizedAdapter 
        returns (bool success) 
    {
        require(!activeSessions[sessionId], "Still active");
        require(sessionToAdapter[sessionId] == msg.sender, "Not your session");
        
        uint256 sessionIndex = adapters[msg.sender].sessions.findSessionIndex(sessionId);
        require(sessionIndex < adapters[msg.sender].sessions.length, "Session not found");
        
        SessionLib.Session storage session = adapters[msg.sender].sessions[sessionIndex];
        require(session.tokenDistributed == false, "Already distributed");
        
        int responseCode = ICustomTokenContract(customTokenContract).transferTokensFromTreasury(
            session.userWallet, 
            session.calculatedReward
        );
        
        if (responseCode != HederaResponseCodes.SUCCESS) {
            return false;
        }
        
        session.tokenDistributed = true;

        int64 distributedReward = session.calculatedReward;
        
        emit RewardDistributed(msg.sender, session.userWallet, distributedReward, sessionId);
        return true;
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }
    
    function associateWithToken() external onlyOwner returns (int responseCode) {
        responseCode = HederaTokenService.associateToken(address(this), tokenAddress);
        require(responseCode == HederaResponseCodes.SUCCESS, "Association failed");
        return responseCode;
    }

    function getAdapterInfo(address adapterAddr)
        external
        view
        returns (
            address wallet,
            string memory DID,
            string memory nftId,
            string memory details,
            bool authorized,
            bool registered,
            uint256 createdAt
        )
    {
        return (
            adapters[adapterAddr].wallet,
            adapters[adapterAddr].DID,
            adapters[adapterAddr].nftId,
            adapters[adapterAddr].details,
            adapters[adapterAddr].authorized,
            adapters[adapterAddr].registered,
            adapters[adapterAddr].createdAt
        );
    }

    function getAdaptersByUser(address userWallet) 
        external 
        view 
        returns (address[] memory) 
    {
        return userAdapters[userWallet];
    }

    function getAdapterByUser(address userWallet) 
        external 
        view 
        returns (address) 
    {
        if (userAdapters[userWallet].length > 0) {
            return userAdapters[userWallet][0];
        }
        return address(0);
    }

    // Function to get session details using session ID
    function getSessionDetails(string calldata sessionId) 
        external 
        view 
        returns (
            string memory sessionIdOut,
            uint256 startTimestamp,
            uint256 endTimestamp,
            int64 energyUsed,
            int64 multiplier,
            int64 calculatedReward,
            int64 calculatedUSD,
            bool active,
            bool tokenDistributed,
            address userWallet,
            address adapterAddress
        ) 
    {
        require(sessionToAdapter[sessionId] != address(0), "Session not found");
        address adapterAddr = sessionToAdapter[sessionId];
        
        uint256 sessionIndex = adapters[adapterAddr].sessions.findSessionIndex(sessionId);
        require(sessionIndex < adapters[adapterAddr].sessions.length, "Session index not found");
        
        SessionLib.Session memory session = adapters[adapterAddr].sessions[sessionIndex];
        
        return (
            session.sessionId,
            session.startTimestamp,
            session.endTimestamp,
            session.energyUsed,
            session.multiplier,
            session.calculatedReward,
            session.calculatedUSD,
            session.active,
            session.tokenDistributed,
            session.userWallet,
            adapterAddr
        );
    }
}