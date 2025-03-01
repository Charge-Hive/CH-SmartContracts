// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.9.0;

import "./StringUtils.sol";

library SessionLib {
    struct Session {
        string sessionId;
        uint256 startTimestamp;
        uint256 endTimestamp;
        int64 energyUsed;
        int64 multiplier;
        int64 calculatedReward;
        int64 calculatedUSD;
        bool active;
        bool tokenDistributed;
        address userWallet;
        string location;
    }
    
    /**
     * @dev Generate a session ID
     * @param adapterAddress Adapter address
     * @param userWallet User wallet address
     * @param timestamp Block timestamp
     * @param counter Session counter
     * @return sessionId The generated session ID
     */
    function generateSessionId(
        address adapterAddress, 
        address userWallet,
        uint256 timestamp,
        uint256 counter
    ) internal pure returns (string memory) {
        bytes32 hash = keccak256(abi.encodePacked(
            adapterAddress,
            userWallet,
            timestamp,
            counter
        ));
        
        return StringUtils.bytes32ToString(hash);
    }
    
    /**
     * @dev Find session index in an array of sessions
     * @param sessions Array of sessions
     * @param sessionId Session ID to find
     * @return index of the session
     */
    function findSessionIndex(Session[] storage sessions, string memory sessionId) 
        internal 
        view 
        returns (uint256) 
    {
        for(uint256 i = 0; i < sessions.length; i++) {
            if (keccak256(bytes(sessions[i].sessionId)) == keccak256(bytes(sessionId))) {
                return i;
            }
        }
        
        return sessions.length; // Not found
    }
}