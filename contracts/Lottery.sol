// SPDX-License-Identifier: MIT

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

pragma solidity ^0.8.11;

contract Lottery is VRFConsumerBase, Ownable {
    address[] public players;
    address public recentWinner;
    uint256 public usdEntryFee;

    AggregatorV3Interface public ethUsdPriceFeed;
    uint256 public randomness;

    // VRF Consumer Base
    bytes32 internal keyHash;
    uint256 internal fee;

    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    LOTTERY_STATE public lotteryState;

    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyHash
    ) VRFConsumerBase(_vrfCoordinator, _link) {
        usdEntryFee = 50 * 10**18;
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lotteryState = LOTTERY_STATE.CLOSED;
        fee = _fee;
        keyHash = _keyHash;
    }

    function enter() public payable {
        require(lotteryState == LOTTERY_STATE.OPEN, "Lottery isn't opened yet");
        // Minimum 50 usd
        require(msg.value >= getEntranceFee(), "Need more ETH!");
        players.push(msg.sender);
    }

    function getEthPrice() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        return uint256(price) * 10**10;
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10; // 18 decimals
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
    }

    function startLottery() public onlyOwner {
        require(
            lotteryState == LOTTERY_STATE.CLOSED,
            "Can't start a new lottery yet!"
        );
        lotteryState = LOTTERY_STATE.OPEN;
    }

    function endLottery() public onlyOwner {
        lotteryState = LOTTERY_STATE.CALCULATING_WINNER;
        requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        require(
            lotteryState == LOTTERY_STATE.CALCULATING_WINNER,
            "Still calculating winner."
        );
        require(_randomness > 0, "random-not-found");
        uint256 winnerIndex = _randomness % players.length;
        recentWinner = players[winnerIndex];
        payable(recentWinner).transfer(address(this).balance);
        // Reset lottery
        players = new address[](0);
        lotteryState = LOTTERY_STATE.CLOSED;
        randomness = _randomness;
    }
}
