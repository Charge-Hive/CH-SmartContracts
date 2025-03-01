// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.9.0;

library StringUtils {
    /**
     * @dev Utility function to convert bytes32 to string
     */
    function bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        bytes memory bytesArray = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            bytesArray[i*2] = toHexChar(uint8(_bytes32[i] >> 4));
            bytesArray[i*2+1] = toHexChar(uint8(_bytes32[i] & 0x0f));
        }
        return string(bytesArray);
    }
    
    /**
     * @dev Helper function for bytes32ToString
     */
    function toHexChar(uint8 _i) internal pure returns (bytes1) {
        if (_i < 10) {
            return bytes1(uint8(bytes1('0')) + _i);
        } else {
            return bytes1(uint8(bytes1('a')) + _i - 10);
        }
    }
}