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

    enum EVENT_STATE{ OPEN, CLOSED, WAITING_REWARDS, FINISHED}

    IERC20 want;
    BeefyBattlesRewardPoolV1 rewardPool;
    IBeefyVaultV6 beefyVault;
    EVENT_STATE public eventState;

    address public server;

    uint256 entranceFee;
    uint256 totalMultipliers;

    mapping(uint256 => uint256) public trophies;
    mapping(uint256 => uint256) public multiplier;
    constructor(string memory _name, 
                string memory _symbol, 
                address _wantAddress, 
                address _beefyVaultAddress, 
                address _server,
                uint256 _entranceFee) ERC721(_name, _symbol){
        
        want = IERC20(_wantAddress);
        rewardPool = new BeefyBattlesRewardPoolV1(_wantAddress, address(this));
        beefyVault = IBeefyVaultV6(_beefyVaultAddress);
        eventState = EVENT_STATE.CLOSED;
        server = _server;
        entranceFee = _entranceFee;

        _giveAllowances();
    }

    /// @notice Deposits the token into the Beefy vault and send a NFT representing a participation in the event
    /// @param _multiplier The multiplier applied to the deposit fee 
    function deposit(uint256 _multiplier) public onlyOpenEvent {
        require(balanceOf(msg.sender) == 0, "User already deposited");

        multiplier[totalSupply() + 1] = _multiplier;
        totalMultipliers += _multiplier;

        uint256 amountOfWant = entranceFee * _multiplier;
        want.safeTransferFrom(msg.sender, address(this), amountOfWant);
        beefyVault.deposit(amountOfWant);

        _safeMint(msg.sender, totalSupply() + 1);
    }

    /// @notice Withdraws the amount deposited in the Beefy vault.
    /// @param _tokenId Token of the user who want to withdraw.
    function withdraw(uint256 _tokenId) public onlyDeposited onlyOpenEvent {
        require(ownerOf(_tokenId) == msg.sender, "Not the owner");

        _burn(_tokenId);

        uint256 amountOfWant = entranceFee * multiplier[_tokenId];
        uint256 amountOfShares = (amountOfWant * 1e18) / beefyVault.getPricePerFullShare();
        beefyVault.withdraw(amountOfShares);
        want.safeTransfer(msg.sender, amountOfWant);
    }

    /// @notice Withdraws the amount deposited in the Beefy vault and gives the rewards to the user depending on their position in the leaderboard.
    /// @param _tokenId Token of the user who want to withdraw.
    function withdrawAndClaim(uint256 _tokenId) public onlyDeposited onlyFinishedEvent {
        withdraw(_tokenId);
        rewardPool.claimRewards(msg.sender, 
                                _calculateLeaderboardPosition(_tokenId), 
                                multiplier[_tokenId], 
                                _avgMultiplier());
    }

    /// @notice Withdraws all the deposited tokens from the Beefy vault and calculates the event rewards.
    function harvestRewards() public {
        require(eventState == EVENT_STATE.WAITING_REWARDS);

        eventState = EVENT_STATE.FINISHED;

        beefyVault.withdrawAll();
        uint256 eventRewards = want.balanceOf(address(this)) - entranceFee * totalMultipliers;
        want.safeTransfer(address(rewardPool), eventRewards);
    }

    /// @notice Posts the results of the battle. Can only be called by the server
    /// @param _winnerToken Winner's address
    /// @param _loserToken Loser's address
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

    /// @notice Calculates the position of the player in the leaderboard.
    /// @dev First position in the leaderboard is 0.
    function _calculateLeaderboardPosition(uint256 _tokenId) internal view returns(uint256) {
        uint256 playersAbove = 0;
        for(uint256 i = 1; i <= totalSupply(); i++){
            uint256 pt = trophies[_tokenId];
            if(i != _tokenId){
                uint256 t = trophies[i];
                if(t > pt){
                    playersAbove++;
                }
            }
        }
        return playersAbove;
    }

    /// @notice Calculates the average multiplier of the event.
    /// @dev Used to avoid giving over 100% of the rewards in the RewardPool.

    function _avgMultiplier() internal view returns(uint256){
        uint256 _mult = totalMultipliers * 1e18;
        uint256 _participants = totalSupply() * 1e18;
        return _mult / _participants;
    }

    function _giveAllowances() internal {
        want.safeApprove(address(beefyVault), type(uint256).max);
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