//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBeefyVaultV6 {
    /// @notice Returns an uint256 with 18 decimals of how much underlying asset one vault share represents.
    /// @dev Function for various UIs to display the current value of one of our yield tokens.
    function getPricePerFullShare() external view returns (uint256);

    /// @dev The entrypoint of funds into the system. People deposit with this function into the vault. The vault is then in charge of sending funds into the strategy.
    function deposit(uint _amount) external;

    /// @dev A helper function to call withdraw() with all the sender's funds.
    function withdrawAll() external;

    /// @dev Function to exit the system. The vault will withdraw the required tokens from the strategy and pay up the token holder. A proportional number of IOU tokens are burned in the process.
    function withdraw(uint256 _shares) external;
}