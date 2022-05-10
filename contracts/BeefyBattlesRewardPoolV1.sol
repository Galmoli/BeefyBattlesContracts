//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Beefy Battles Reward Pool
/// @author Galmoli
/// @notice First version of the Beefy Battles RewardPool.
contract BeefyBattlesRewardPoolV1 is Ownable{
    using SafeERC20 for IERC20;

    address public want;
    address public eventAddress;

    uint256 public eventRewards;
    uint256[] rewardBase;

    constructor(address _want, address _eventAddress, address _eventOwner){
        want = _want;
        eventAddress = _eventAddress;
        _transferOwnership(_eventOwner);
    }

    /// @notice Notifies the reward pool that it received the rewards.
    function notifyRewards() public {
        eventRewards = IERC20(want).balanceOf(address(this));
    }

    /// @notice Function called from the Beefy Battles Event. It transfers the rewards to the player based on their position and multipliers.
    /// @dev TODO: Add some aditional checks to the rewards amount.
    /// @param _player The address who will recive the rewards.
    /// @param _leaderboardPosition Player's position in the leaderboard.
    /// @param _multiplier Player's multiplier.
    /// @param _avgMultiplier Average multiplier of the event.
    function claimRewards(address _player, uint256 _leaderboardPosition, uint256 _multiplier, uint256 _avgMultiplier) public onlyEventCall{
        uint256 rewards = calculateRewards(_leaderboardPosition, _multiplier, _avgMultiplier);
        IERC20(want).safeTransfer(_player, rewards);
    }

    /// @notice Set the rewards base of the event. 
    /// @dev First position of the array is the first position of the leaderboard.  [10, 8 , 5, ...]
    /// @dev Rewards base is a 2 decimal number. So a reward base of 1 is 100.
    function setRewardBase(uint256[] memory _rewardBase) public onlyOwner{
        rewardBase = _rewardBase;
    }

    function getRewardBase(uint256 _index) public view returns(uint256){
        return rewardBase[_index];
    }

    /// @dev rewardsBase is a 2 decimal number. multiplier 0 decimal. _avgMultiplier 18 decimal.
    function calculateRewards(uint256 _leaderboardPosition, uint256 _multiplier, uint256 _avgMultiplier) public view returns(uint256) {
        uint256 ratio = ((rewardBase[_leaderboardPosition] * 1e14) * _multiplier) / _avgMultiplier;
        return (eventRewards * ratio) / 1e18;
    }

    modifier onlyEventCall {
        require(msg.sender == eventAddress, "Caller: not the event");
        _;
    }
}