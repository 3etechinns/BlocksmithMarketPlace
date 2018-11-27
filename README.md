# Requirements and Set up
  * Node.js 10+
  * Truffle 4.1.13
  * Ganache-cli 6.1.6

How to run the Truffle project
  * `$ ganache-cli`
  * `$ truffle test`

# Description
A platform for investment in tangible assets where anyone can
invest, providing existing asset owners with liquidity for the renovation or construction
of properties for subsequent sale.
For each investment opportunity, the investors can buy with ether a certain amount of
tokens from the asset owner. He should later be able to sell them to other parties with
ether whenever he chooses to capitalise gains or reduce losses.

# Architecture
![Architecture](/BlacksmithArchitecture.jpg)

Log in is done by making use of uPort. Database can be used to save user's uPort identities and to cache past Logs, avoiding in this way to make calls via web3.js (JSON-RPC) from old blocks every time. IPFS is used to stored all information related to the tangible asset.

# Smart Contracts
Project consists in two main smart contracts: `ERC20.sol` y `TokenManager.sol`.
In addition, two other contracts has been used to for security, both taken from Zeppelin: `Ownable.sol` and `Pausable.sol`

## ERC20
Modified version of ERC20 standard token. Four new public state variables were added: `creator`, `icoEnd`, `thumbnail`, and `description`.
  * `creator`: Because of token contract being created by `TokenManager.sol`, `msg.sender` can't be identified as the address to initially assign the total supply.  
  * `icoEnd`: Time as seconds since Unix epoch setting when ICO ends.
  * `thumbnail`: Each token is attached to a tangible asset. This state variable is the IPFS hash where an image of the product is stored.
  * `description`: IPFS hash where a HTML document of the product, describing it and its investment conditions, is stored.
  * `lockedBalances`: To avoid token holders to transfer tokens that have been previously placed to be sold in the platform. In this way a potential buyer will never try to purchase tokens that have been already transferred somewhere else.

Also, two new methods with their respective events were added: `unlockBalance()` and `lockBalance()`. Because of selling orders are placed and managed by the platform, only the owner (`TokenManager.sol`) has the privilege of calling this methods.

## TokenManager
This contract handles all market operations, from creating new tokens to selling/buying them between users. There are two periods: **ICO period** where tokens are sold by the tangible asset's owner (`creator`) at a fixed price, and **Post ICO period** where token holders can place selling orders at different prices and trade with them. The current state of the token is controlled by the modifiers `isIcoPeriod` and `isNotIcoPeriod`.

Users will have to call the ERC20 contract `approve()` method to allow `TokenManager.sol` to transfer their tokens. Creator will have to do it once before ICO is launched, and also every user that wants to place a selling order.

Thanks to Logs `tokenOrderPublished`, `tokenOrderCanceled`, and `tokenOrderPurchased` sharing an unique Order ID, it's possible to display in the front-end a list of all Selling Orders without showing outdated information. In any case, if someone tried to call directly the methods, without using the UI, it can be checked if the order whether exist or not. All orders are stored in storage: `mapping(address => Order) resellers;` as a `struct Token` component.

# Enhancements
  * Use a Upgradeability pattern as **Unstructured storage**.
  * Use Security tools and audit the smart contracts.
  * Allow users to place more than one selling order.

This is a 100% decentralized platform which means that is very costly due to numerous storage writings/readings. A hybrid an less decentralized solution might be built, taking out selling orders, and storing them in a common database.   
