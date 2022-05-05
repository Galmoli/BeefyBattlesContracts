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

    IERC20 want;

    address eventAddress;

    uint256 eventRewards;
    uint256[] rewardsBase;

    constructor(address _wantAddress, address _eventAddress){
        want = IERC20(_wantAddress);
        eventAddress = _eventAddress;
    }

    /// @notice Function called from the Beefy Battles Event. It transfers the rewards to the player based on their position and multipliers.
    /// @dev TODO: Add some aditional checks to the rewards amount.
    /// @param _player The address who will recive the rewards.
    /// @param _leaderboardPosition Player's position in the leaderboard.
    /// @param _multiplier Player's multiplier.
    /// @param _avgMultiplier Average multiplier of the event.
    function claimRewards(address _player, uint256 _leaderboardPosition, uint256 _multiplier, uint256 _avgMultiplier) public onlyEventCall{
        uint256 rewards = _calculateRewards(_leaderboardPosition, _multiplier, _avgMultiplier);
        want.safeTransfer(_player, rewards);
    }

    /// @notice Set the rewards base of the event. 
    /// @dev First position of the array is the first position of the leaderboard.  [10, 8 , 5, ...]
    function setRewardsBase(uint256[] memory _rewardsBase) public onlyOwner{
        rewardsBase = _rewardsBase;
    }

    function _calculateRewards(uint256 _leaderboardPosition, uint256 _multiplier, uint256 _avgMultiplier) internal view returns(uint256) {
        return (eventRewards * rewardsBase[_leaderboardPosition] * _multiplier) / _avgMultiplier;
    }

    modifier onlyEventCall {
        require(msg.sender == eventAddress, "Not called from the event");
        _;
    }
}