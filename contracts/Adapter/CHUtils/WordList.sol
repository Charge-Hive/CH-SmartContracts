// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.0 <0.9.0;

library WordList {
    /**
     * @dev Returns a list of words to use for DID generation
     * @param index Word index to retrieve (0-49)
     * @return word The word at the given index
     */
    function getWord(uint8 index) internal pure returns (string memory word) {
        // Reduced list to 50 words instead of 100
        if (index == 0) return "apple";
        if (index == 1) return "banana";
        if (index == 2) return "cherry";
        if (index == 3) return "dragon";
        if (index == 4) return "elephant";
        if (index == 5) return "falcon";
        if (index == 6) return "giraffe";
        if (index == 7) return "harmony";
        if (index == 8) return "island";
        if (index == 9) return "jungle";
        if (index == 10) return "kangaroo";
        if (index == 11) return "lemon";
        if (index == 12) return "mountain";
        if (index == 13) return "nebula";
        if (index == 14) return "ocean";
        if (index == 15) return "penguin";
        if (index == 16) return "quasar";
        if (index == 17) return "rainbow";
        if (index == 18) return "strawberry";
        if (index == 19) return "tiger";
        if (index == 20) return "umbrella";
        if (index == 21) return "volcano";
        if (index == 22) return "whisper";
        if (index == 23) return "xylophone";
        if (index == 24) return "yellow";
        if (index == 25) return "zephyr";
        if (index == 26) return "aurora";
        if (index == 27) return "breeze";
        if (index == 28) return "crystal";
        if (index == 29) return "diamond";
        if (index == 30) return "eclipse";
        if (index == 31) return "feather";
        if (index == 32) return "galaxy";
        if (index == 33) return "horizon";
        if (index == 34) return "infinity";
        if (index == 35) return "jasmine";
        if (index == 36) return "kaleidoscope";
        if (index == 37) return "lunar";
        if (index == 38) return "monarch";
        if (index == 39) return "nautical";
        if (index == 40) return "orbital";
        if (index == 41) return "pinnacle";
        if (index == 42) return "quantum";
        if (index == 43) return "radiance";
        if (index == 44) return "sapphire";
        if (index == 45) return "twilight";
        if (index == 46) return "utopia";
        if (index == 47) return "vibrant";
        if (index == 48) return "whiskey";
        if (index == 49) return "xenon";
        return "default";
    }
}