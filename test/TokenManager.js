const TokenManagerArtifact = artifacts.require("TokenManager");
const ERC20 = artifacts.require("ERC20");

contract('TokenManager', function(accounts) {

  before("Initialization and Token creation", async () => {
    this.TokenManager = await TokenManagerArtifact.deployed();

    this.creator = accounts[0];
    this.buyer1 = accounts[1];
    this.buyer2 = accounts[2];

    const icoPeriodTime = 60;
    this.tokenValues = {
      name: 'Blocksmith',
      decimals: 18,
      symbol: 'BS',
      icoEnd: Date.now() + icoPeriodTime,
      initialPrice: 1000000000000000000, //1 ETH
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
  });


  it("User creates a Token", async () =>{

    const tokenCreationFilter = web3.eth.filter({
      fromBlock: 0,
      toBlock: 'latest',
      address: this.TokenManager.address,
      topics: [web3.sha3('tokenCreation(address)')]
    });

    tokenCreationFilter.get(async (error, result) => {
      const newTokenAddress = "0x" + result[0].topics[1].substr(26,64);
      const Token = ERC20.at(newTokenAddress);

      const name = await Token.name();
      const decimals = await Token.decimals();
      const symbol = await Token.symbol();
      const icoEnd = await Token.icoEnd();
      const initialPrice = await Token.initialPrice();
      const totalSupply = await Token.totalSupply();

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
  });

  it("User buy some tokens", async () =>{

  });

});
