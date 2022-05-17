//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BeefyBattlesRewardPoolV1.sol";
import "../interfaces/IBeefyValutV6.sol";

/// @title Beefy Battles Event
/// @author Galmoli
/// @notice Entry ticket for Beefy Battles' Events
contract BeefyBattlesEventV1 is Ownable, ERC721Enumerable{
    using SafeERC20 for IERC20;

    enum EVENT_STATE{ OPEN, CLOSED, FINISHED}

    BeefyBattlesRewardPoolV1 rewardPool;
    EVENT_STATE public eventState;

    address public want;
    address public beefyVault;
    address public server;

    uint256 entranceFee;
    uint256 totalMultipliers;
    uint256 tokenCounter;
    uint256 public endEventBlock;

    mapping(uint256 => uint256) public trophies;
    mapping(uint256 => uint256) public multiplier;
    constructor(string memory _name, 
                string memory _symbol, 
                address _want, 
                address _beefyVault, 
                address _server,
                uint256 _entranceFee,
                uint256 _endEventBlock) ERC721(_name, _symbol){
        
        want = _want;
        rewardPool = new BeefyBattlesRewardPoolV1(_want, address(this), owner());
        beefyVault = _beefyVault;
        eventState = EVENT_STATE.CLOSED;
        server = _server;
        entranceFee = _entranceFee;
        endEventBlock = _endEventBlock;
        tokenCounter = 1;

        _giveAllowances();
    }

    /// @notice Deposits the token into the Beefy vault and send a NFT representing a participation in the event
    /// @param _multiplier The multiplier applied to the deposit fee 
    function deposit(uint256 _multiplier) public onlyOpenEvent {
        require(balanceOf(msg.sender) == 0, "User already deposited");

        multiplier[tokenCounter] = _multiplier;
        totalMultipliers += _multiplier;

        uint256 amountOfWant = entranceFee * _multiplier;
        IERC20(want).safeTransferFrom(msg.sender, address(this), amountOfWant);
        IBeefyVaultV6(beefyVault).deposit(amountOfWant);

        _safeMint(msg.sender, tokenCounter);
        tokenCounter++;
    }

    /// @notice Withdraws the amount deposited in the Beefy vault while the event is still open.
    /// @param _tokenId Token of the user who want to withdraw.
    function withdrawEarly(uint256 _tokenId) public onlyDeposited onlyOpenEvent{
        require(ownerOf(_tokenId) == msg.sender, "Not the owner");

        _burn(_tokenId);

        uint256 amountOfWant = entranceFee * multiplier[_tokenId];
        uint256 amountOfShares = (amountOfWant * 1e18) / IBeefyVaultV6(beefyVault).getPricePerFullShare();
        IBeefyVaultV6(beefyVault).withdraw(amountOfShares + 1);
        IERC20(want).safeTransfer(msg.sender, amountOfWant);

        _clearMultiplier(_tokenId);
    }

    /// @notice Withdraws the amount deposited in the Beefy vault and gives the rewards to the user depending on their position in the leaderboard.
    /// @param _tokenId Token of the user who want to withdraw.
    function withdrawAndClaim(uint256 _tokenId) public onlyDeposited onlyFinishedEvent {
        require(ownerOf(_tokenId) == msg.sender, "Not the owner");

        _burn(_tokenId);

        uint256 amountOfWant = entranceFee * multiplier[_tokenId];
        IERC20(want).safeTransfer(msg.sender, amountOfWant);
        rewardPool.claimRewards(msg.sender, 
                                calculateLeaderboardPosition(_tokenId), 
                                multiplier[_tokenId], 
                                _avgMultiplier());

        _clearMultiplier(_tokenId);
    }

    /// @notice Withdraws all the deposited tokens from the Beefy vault and calculates the event rewards.
    function harvestRewards() public onlyOpenEvent{
        require(block.number >= endEventBlock, "EndEventBlock not reached");

        eventState = EVENT_STATE.FINISHED;

        IBeefyVaultV6(beefyVault).withdrawAll();
        uint256 eventRewards = IERC20(want).balanceOf(address(this)) - entranceFee * totalMultipliers;
        IERC20(want).safeTransfer(address(rewardPool), eventRewards);
        rewardPool.notifyRewards();
    }

    /// @notice Posts the results of the battle. Can only be called by the server
    /// @param _winnerToken Winner's tokenId
    /// @param _loserToken Loser's tokenId
    /// @param _winnerTrophies Amount of trophies won by the winner
    /// @param _loserTrophies Amount of thropies lost by the loser
    function postResult(uint256 _winnerToken, uint256 _loserToken, uint256 _winnerTrophies, uint256 _loserTrophies) public onlyServer {
        require(_exists(_winnerToken) && _exists(_loserToken), "Token doesn't exist");

        trophies[_winnerToken] += _winnerTrophies;
        trophies[_loserToken] -= _loserTrophies;
    }

    /// @notice Opens the event. Now users can deposit.
    /// @dev This should be changed in the future so users can predeposit and it will start earning interest even before the event starts
    function openEvent() public onlyOwner {
        eventState = EVENT_STATE.OPEN;
    }

    /// @notice Sets the server address.
    /// @dev The server is used to post battle results via the postResult function.
    function setServer(address _server) public onlyOwner{
        server = _server;
    }

    /// @notice Returns Event's reward pool.
    function getRewardPool() public view returns(address){
        return address(rewardPool);
    }

    /// @notice Calculates the position of the player in the leaderboard.
    /// @dev First position in the leaderboard is 0.
    function calculateLeaderboardPosition(uint256 _tokenId) public view returns(uint256) {
        uint256 playersAbove = 0;
        for(uint256 i = 0; i < totalSupply(); i++){
            uint256 tokenIdThropies = trophies[_tokenId];
            uint256 comparingToTokenId = tokenByIndex(i);
            if(comparingToTokenId != _tokenId){
                uint256 comparingToThropies = trophies[comparingToTokenId];
                if(comparingToThropies > tokenIdThropies){
                    playersAbove++;
                }
            }
        }
        return playersAbove;
    }

    /// @notice Removes the multiplier from _tokenId from totalMultipliers and sets _tokenId multiplier to 0
    function _clearMultiplier(uint256 _tokenId) internal {
        totalMultipliers -= multiplier[_tokenId];
        multiplier[_tokenId] = 0;
    }

    /// @notice Calculates the average multiplier of the event.
    /// @dev Used to avoid giving over 100% of the rewards in the RewardPool.
    function _avgMultiplier() internal view returns(uint256){
        uint256 _mult = totalMultipliers * 1e18;
        uint256 _participants = totalSupply() * 1e18;
        return (_mult / _participants) * 1e18;
    }

    function _giveAllowances() internal {
        IERC20(want).safeApprove(address(beefyVault), type(uint256).max);
    }

    modifier onlyServer {
        require(msg.sender == server, "Caller is not the server");
        _;
    }

    modifier onlyDeposited {
        require(balanceOf(msg.sender) != 0, "User not deposited");
        _;
    }

    modifier onlyOpenEvent {
        require(eventState == EVENT_STATE.OPEN, "Event not open");
        _;
    }

    modifier onlyFinishedEvent {
        require(eventState == EVENT_STATE.FINISHED, "Event not finished");
        _;
    }
}