//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IBeefyValutV6.sol";

/// @title Beefy Battles Event
/// @author Galmoli
/// @notice First version of the Beefy Battles Event Contract.
contract BeefyBattlesEventV1 is Ownable, ERC721{
    using SafeERC20 for IERC20;

    enum EVENT_STATE{ OPEN, CLOSED, WAITING_REWARDS, FINISHED}

    IERC20 want;
    IBeefyVaultV6 beefyVault;
    EVENT_STATE public eventState;

    address server;
    address[] players;

    uint256 tokenCounter;
    uint256 entranceFee;
    uint256 beefyFee;
    uint256 totalMultipliers;
    uint256 eventRewards;
    uint256[] rewardsBase;

    mapping(address => uint256) public token;
    mapping(uint256 => uint256) public trophies;
    mapping(uint256 => uint256) public multiplier;
    constructor(string memory _name, string memory _symbol, address _wantAddress, address _beefyVaultAddress, address _server) ERC721(_name, _symbol){
        want = IERC20(_wantAddress);
        beefyVault = IBeefyVaultV6(_beefyVaultAddress);
        eventState = EVENT_STATE.CLOSED;
        server = _server;
        
        tokenCounter = 1;

        _giveAllowances();
    }

    /// @notice Deposits the token into the Beefy vault and send a NFT representing a participation in the event
    /// @param _multiplier The multiplier applied to the deposit fee 
    function deposit(uint256 _multiplier) public onlyOpenEvent {
        require(token[msg.sender] == 0, "User already in event");

        token[msg.sender] = tokenCounter;
        multiplier[tokenCounter] = _multiplier;
        totalMultipliers += _multiplier;
        players.push(msg.sender);

        uint256 amountOfWant = (entranceFee + beefyFee) * _multiplier;
        want.safeTransferFrom(msg.sender, address(this), amountOfWant);
        beefyVault.deposit(amountOfWant);

        _safeMint(msg.sender, tokenCounter);
        tokenCounter++;
    }

    /// @notice Withdraws the amount deposited in the Beefy vault.
    /// @param _tokenId Token of the user who want to withdraw.
    function withdraw(uint256 _tokenId) public onlyDeposited onlyOpenEvent {
        require(ownerOf(_tokenId) == msg.sender, "Not the owner");

        token[msg.sender] = 0;
        _burn(_tokenId);

        uint256 amountOfWant = (entranceFee + beefyFee) * multiplier[_tokenId];
        uint256 amountOfShares = amountOfWant / beefyVault.getPricePerFullShare();
        beefyVault.withdraw(amountOfShares);
        want.safeTransfer(msg.sender, amountOfWant);
    }

    /// @notice Withdraws the amount deposited in the Beefy vault and gives the rewards to the user depending on their position in the leaderboard.
    /// @param _tokenId Token of the user who want to withdraw.
    function withdrawAndClaim(uint256 _tokenId) public onlyDeposited onlyFinishedEvent {
        withdraw(_tokenId);
        uint256 rewards = _calculateRewards();
        require(rewards <= want.balanceOf(address(this)));
        want.safeTransfer(msg.sender, _calculateRewards());
    }

    /// @notice Withdraws all the deposited tokens from the Beefy vault and calculates the event rewards.
    function harvestRewards() public {
        require(eventState == EVENT_STATE.WAITING_REWARDS);

        eventState = EVENT_STATE.FINISHED;

        beefyVault.withdrawAll();
        eventRewards = want.balanceOf(address(this)) - entranceFee * totalMultipliers;
    }

    /// @notice Posts the results of the battle. Can only be called by the server
    /// @param _winner Winner's address
    /// @param _loser Loser's address
    /// @param _winnerTrophies Amount of trophies won by the winner
    /// @param _loserTrophies Amount of thropies lost by the loser
    function postResult(address _winner, address _loser, uint256 _winnerTrophies, uint256 _loserTrophies) public onlyServer {
        require(token[_winner] != 0, "Winner doesn't exist in event");
        require(token[_loser] != 0, "Loser doesn't exist in event");

        trophies[token[_winner]] += _winnerTrophies;
        trophies[token[_loser]] -= _loserTrophies;
    }

    /// @notice Opens the event. Now users can deposit.
    /// @dev This should be changed in the future so users can predeposit and it will start earning interest even before the event starts
    function openEvent() public onlyOwner {
        eventState = EVENT_STATE.OPEN;
    }

    function setRewardsBase(uint256[] memory _rewardsBase) public onlyOwner{
        rewardsBase = _rewardsBase;
    }

    function setServer(address _server) public onlyOwner{
        server = _server;
    }

    function _calculateRewards() internal view returns(uint256) {
        uint256 playersAbove = 0;
        for(uint256 i = 0; i < players.length; i++){
            address p = players[i];
            uint256 pt = trophies[token[msg.sender]];
            if(p != msg.sender){
                uint256 t = trophies[token[p]];
                if(t > pt){
                    playersAbove++;
                }
            }
        }
        return eventRewards * rewardsBase[playersAbove];
    }

    function _giveAllowances() internal {
        want.safeApprove(address(beefyVault), type(uint256).max);
    }

    modifier onlyServer {
        require(msg.sender == server, "Not the server");
        _;
    }

    modifier onlyDeposited {
        require(token[msg.sender] != 0, "User not in event");
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