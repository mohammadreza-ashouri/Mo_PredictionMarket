//SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;

/*
Author: Mo Ashouri
Contract: ashourics@protonmail.com
Twitter: @ahourics
YouTube: https://www.youtube.com/c/Heapzip/videos
GitHub: https://github.com/mohammadreza-ashouri/
Web: https://ashoury.net
Security Analysis: https://bytescan.net/
*/

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
 
contract PredictionMarket {
    address public d_owner;
    address payable[] public d_players;
    uint256 public d_usdEntryFee;

    AggregatorV3Interface internal ethUsdPriceFeed;


    struct Result {
        Side winner;
        Side loser;
    }
    enum Side {
        Alice,
        Bob
    }

    Result public d_result;

    enum MARKET_STATE {
        CLOSED,
        OPEN,
        CALCULATING_WINNER,
        CLOSED_FOREVER
    }
    MARKET_STATE public market_state;

    // maps each side to the total amount of eth bet on each candidate
    mapping(Side => uint256) public bets;

    // maps the gambler's address to the side he/she has bet on
    // which maps to amount betted by the gambler
    mapping(address => mapping(Side => uint256)) public betsPerGambler;

    constructor(address owner, address priceFeedAddress) public {
        d_owner = owner;
        d_usdEntryFee = 50 * (10**18);
        ethUsdPriceFeed = AggregatorV3Interface(priceFeedAddress);
        market_state = MARKET_STATE.CLOSED;
    }

    function placeBet(Side side) external payable {
        require(market_state == MARKET_STATE.OPEN, "Market not open!");
        require(msg.sender != d_owner, "Owner cannot place bet!");
        // $50 minimum
        require(msg.value >= getEntranceFee(), "Not enough ETH");
        bets[side] += msg.value;
        betsPerGambler[msg.sender][side] += msg.value;
        d_players.push(msg.sender);
    }

    function startMarket() public {
        require(msg.sender == d_owner, "Only owner can call this function!");
        require(market_state == MARKET_STATE.CLOSED, "Market already open!");
        market_state = MARKET_STATE.OPEN;
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10; //18 Decimals
        uint256 costToEnter = (d_usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
    }

    function sendWinnings() internal {
        require(
            market_state == MARKET_STATE.CALCULATING_WINNER,
            "Market is still open!"
        );
        for (
            uint256 playerIndex = 0;
            playerIndex < d_players.length;
            playerIndex++
        ) {
            uint256 gamblerBet = betsPerGambler[d_players[playerIndex]][
                d_result.winner
            ];
            if (gamblerBet > 0) {
                uint256 totalWin = gamblerBet +
                    (bets[d_result.loser] * gamblerBet) /
                    bets[d_result.winner];

                betsPerGambler[msg.sender][Side.Alice] = 0;
                betsPerGambler[msg.sender][Side.Bob] = 0;
                d_players[playerIndex].transfer(totalWin);

                market_state = MARKET_STATE.CLOSED_FOREVER;
            }
        }
    }

    function reportResult(Side winner, Side loser) external {
        require(msg.sender == d_owner, "Only owner can call this function!");
        require(market_state == MARKET_STATE.OPEN, "Market is closed forever!");
        market_state = MARKET_STATE.CALCULATING_WINNER;
        d_result.winner = winner;
        d_result.loser = loser;
        sendWinnings();
    }
}
