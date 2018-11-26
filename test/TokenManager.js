const TokenManagerArtifact = artifacts.require("TokenManager");
const ERC20 = artifacts.require("ERC20");

contract('TokenManager', function(accounts) {

  before("Initialization and Token creation", async () => {
    return new Promise(async (resolve) => {

      this.timeTravel = function(time) {
        return new Promise((resolve, reject) => {
            web3.currentProvider.sendAsync({
            jsonrpc: "2.0",
            method: "evm_increaseTime",
            params: [time],
            id: new Date().getSeconds()
          }, (err, result) => {
            if(err){ return reject(err) }
            return resolve(result)
          });
        });
      };

      this.TokenManager = await TokenManagerArtifact.deployed();

      this.creator = accounts[0];
      this.buyerICO = accounts[1];
      this.buyerPostICO = accounts[2];

      const icoPeriodTime = 60;
      this.icoStart = Date.now()/1000;

      this.tokenValues = {
        name: 'Blocksmith',
        decimals: 18,
        symbol: 'BS',
        icoEnd: Math.floor(icoStart + icoPeriodTime),
        initialPrice: 100000000000000000, //0.1 ETH
        totalSupply: 100
      }

      this.TokenManager.createToken(
        this.tokenValues.name,
        this.tokenValues.decimals,
        this.tokenValues.symbol,
        this.tokenValues.icoEnd,
        this.tokenValues.initialPrice,
        this.tokenValues.totalSupply,
        { from: this.creator }
      );

      const tokenCreationFilter = web3.eth.filter({
        fromBlock: 0,
        toBlock: 'latest',
        address: this.TokenManager.address,
        topics: [web3.sha3('tokenCreation(address,address)')]
      });

      await tokenCreationFilter.get((error, result) => {
        this.newTokenAddress = "0x" + result[0].topics[1].substr(26,64);
        this.Token = ERC20.at(this.newTokenAddress);
        resolve();
      });
    });
  });

  // after("Time travel back to the past before ICO starts", async () => {
  //   await this.timeTravel(this.icoStart);
  //
  //   this.mineBlock = function(time) {
  //     return new Promise((resolve, reject) => {
  //         web3.currentProvider.sendAsync({
  //         jsonrpc: "2.0",
  //         method: "evm_mine",
  //         params: [],
  //         id: new Date().getSeconds()
  //       }, (err, result) => {
  //         if(err){ return reject(err) }
  //         return resolve(result)
  //       });
  //     });
  //   };
  //   console.log("Ejecuto en after");
  //   await this.mineBlock();
  // });


  it("User creates a Token", async () => {

    const name = await this.Token.name();
    const decimals = await this.Token.decimals();
    const symbol = await this.Token.symbol();
    const icoEnd = await this.Token.icoEnd();
    const initialPrice = await this.Token.initialPrice();
    const totalSupply = await this.Token.totalSupply();

    const tokenValues = {
      name: name,
      decimals: decimals.toNumber(),
      symbol: symbol,
      icoEnd: icoEnd.toNumber(),
      initialPrice: initialPrice.toNumber(),
      totalSupply: totalSupply.toNumber()
    }

    assert.deepEqual(this.tokenValues, tokenValues, "User couldn't create a Token properly");
  });


  it("Token creator approves TokenManager to send tokens on his behalf", async () => {

    await this.Token.approve(
      this.TokenManager.address,
      this.tokenValues.totalSupply,
      {from: this.creator}
    );

    const allowance = await this.Token.allowance(this.creator, this.TokenManager.address);

    assert.equal(allowance, this.tokenValues.totalSupply, "Creator couldn't approve the TokenManager");
  });


  it("User buys some tokens during the ICO period", async () => {

    const amountToBuy = 50;
    await this.TokenManager.buyTokenIcoPeriod(
      this.newTokenAddress,
      amountToBuy,
      {from: this.buyerICO, value: amountToBuy * this.tokenValues.initialPrice}
    );

    const buyerICOBalance = await this.Token.balanceOf(this.buyerICO);
    const creatorBalance = await this.Token.balanceOf(this.creator);

    assert.equal(
      buyerICOBalance,
      amountToBuy,
      "Buyer couldn't buy tokens during ICO period - 1"
    );

    assert.equal(
      creatorBalance,
      this.tokenValues.totalSupply - amountToBuy,
      "Buyer couldn't buy tokens during ICO period - 2"
    );
  });


  it("ICO token buyer place a sell action some tokens when ICO has ended", async () => {

    const amountToSell = 10;
    const priceToSell = this.tokenValues.initialPrice * 2;

    const buyerICOBalance = await this.Token.balances(this.buyerICO);
    const buyerICOlockedBalance = await this.Token.lockedBalances(this.buyerICO);

    await this.timeTravel(this.tokenValues.icoEnd);

    await this.TokenManager.sellTokens(
      this.newTokenAddress,
      amountToSell,
      priceToSell,
      {from: this.buyerICO}
    );

    const newBuyerICOBalance = await this.Token.balances(this.buyerICO);
    const newBuyerICOlockedBalance = await this.Token.lockedBalances(this.buyerICO);

    assert.equal(
      newBuyerICOBalance.toNumber(),
      buyerICOBalance - amountToSell,
      "Seller couldn't place a sell action properly - 1"
    );

    assert.equal(
      newBuyerICOlockedBalance.toNumber(),
      buyerICOlockedBalance + amountToSell,
      "Seller couldn't place a sell action properly - 2"
    );

    const sellOrder = await this.TokenManager.sellOrders(this.newTokenAddress, this.buyerICO);

    assert.deepEqual(
      [sellOrder[0].toNumber(), sellOrder[1].toNumber()],
      [amountToSell, priceToSell],
      "Seller couldn't place a sell action properly - 3"
    )
  });

  it("User cancel a selling order", async () => {

    const buyerICOBalance = await this.Token.balances(this.buyerICO);
    const buyerICOlockedBalance = await this.Token.lockedBalances(this.buyerICO);
    const sellOrder = await this.TokenManager.sellOrders(this.newTokenAddress, this.buyerICO);

    await this.TokenManager.cancelSellOrder(this.newTokenAddress, {from: this.buyerICO});

    const newBuyerICOBalance = await this.Token.balances(this.buyerICO);
    const newBuyerICOlockedBalance = await this.Token.lockedBalances(this.buyerICO);
    const removedSellOrder = await this.TokenManager.sellOrders(this.newTokenAddress, this.buyerICO);

    assert.deepEqual(
      [0, 0],
      [removedSellOrder[0].toNumber(), removedSellOrder[1].toNumber()],
      "Sell order has not been removed properly - 1"
    )

    assert.deepEqual(
      {balance: newBuyerICOBalance.toNumber(), locked: newBuyerICOlockedBalance.toNumber()},
      {
        balance: buyerICOBalance.toNumber() + sellOrder[0].toNumber(),
        locked: buyerICOlockedBalance.toNumber() - sellOrder[0].toNumber()
      },
      "Sell order has not been removed properly - 2"
    )
  });


  it("User buys tokens from a selling order", async () => {
    //Seller has to place the selling order again because it had been canceled
    const amountToSell = 10;
    const priceToSell = this.tokenValues.initialPrice * 2;

    const buyerICOBalance = await this.Token.balances(this.buyerICO);
    const buyerICOlockedBalance = await this.Token.lockedBalances(this.buyerICO);

    await this.TokenManager.sellTokens(
      this.newTokenAddress,
      amountToSell,
      priceToSell,
      {from: this.buyerICO}
    );

    //Seller has to approve first to Manager to sell his tokens for ETH
    await this.Token.approve(
      this.TokenManager.address,
      this.tokenValues.totalSupply,
      {from: this.buyerICO}
    );

    //Other user accept the selling order and buy the tokens
    const buyerPostICOBalance = await this.Token.balances(this.buyerPostICO);

    await this.TokenManager.buyTokens(
      this.newTokenAddress,
      this.buyerICO,
      {from: this.buyerPostICO, value: amountToSell * priceToSell}
    );

    const newBuyerICOBalance = await this.Token.balances(this.buyerICO);
    const newBuyerICOlockedBalance = await this.Token.lockedBalances(this.buyerICO);
    const newBuyerPostICOBalance = await this.Token.balances(this.buyerPostICO);

    assert.equal(
      buyerPostICOBalance.toNumber() + amountToSell,
      newBuyerPostICOBalance.toNumber(),
      "User could not buy tokens from a selling offer - 1"
    );

    assert.equal(
      buyerICOBalance.toNumber() - amountToSell,
      newBuyerICOBalance.toNumber(),
      "User could not buy tokens from a selling offer - 2"
    );

    assert.equal(
      0,
      newBuyerICOlockedBalance.toNumber(),
      "User could not buy tokens from a selling offer - 3"
    );
  });

  it("Token creator withdraw ICO benefits (ETH)", async () => {
    const marketBalance = await this.TokenManager.balances(this.creator);
    console.log(marketBalance.toNumber());
    await this.TokenManager.withdrawBalance(marketBalance, {from: this.creator});
  });

  it("Reseller withdraw token sales benefits (ETH)", async () => {
    const marketBalance = await this.TokenManager.balances(this.buyerICO);
    console.log(marketBalance.toNumber());
    await this.TokenManager.withdrawBalance(marketBalance, {from: this.buyerICO});
  });
});
