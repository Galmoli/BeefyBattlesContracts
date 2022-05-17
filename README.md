# Beefy Battles Contracts ![license-badge] ![issues]
 
<p align="center">
  <img src="https://imgur.com/y1eKYv1.png" alt="Beefy Battles Logo" width="500" />
</p>

<div align="center">
  Official repository for the BeefyBattles contracts. <strong>Highly experimental</strong>
  <br>
  <br>
  <strong>Beefy Battles</strong> is a play-to-earn game built on top of <strong>Beefy.com</strong> that enables users to participate in
  <br> <strong>tournaments</strong> where the best players get a share of the <strong>reward pool</strong>.
  
</div>

## Installation

Run the following commands in the project root folder:

```jsx
npm install
```
This will install all the required dependencies.

## Unit tests & Code Coverage
Unit tests run on a HardHat network fork of the Fantom chain. Be sure to set the `FTM` key on the enviroment variables. 
To run the unit tests and get a gas report, user the following command: 

```jsx
npx hardhat test --network localhost
```

To get code coverage report, run the following command:

```jsx
npx hardhat coverage
```
This will generate a report to `./coverage`. Open `./coverage/index.html` to check the report with more detail.

## Event Deployment Process

Coming soon :)

[license-badge]: https://img.shields.io/github/license/Galmoli/BeefyBattlesContracts?style=flat-square
[issues]: https://img.shields.io/github/issues/Galmoli/BeefyBattlesContracts?style=flat-square
