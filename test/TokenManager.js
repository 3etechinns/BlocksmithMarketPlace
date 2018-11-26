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

    const sellOffer = await this.TokenManager.sellOffers(this.newTokenAddress, this.buyerICO);

    assert.deepEqual(
      [sellOffer[0].toNumber(), sellOffer[1].toNumber()],
      [amountToSell, priceToSell],
      "Seller couldn't place a sell action properly - 3"
    )
  });
});
