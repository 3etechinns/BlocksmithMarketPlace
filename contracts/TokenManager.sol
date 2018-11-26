pragma solidity ^0.4.24;

import "./ERC20.sol";
import "./Pausable.sol";
import "../libraries/SafeMath.sol";

/** @title BlacksmithMarket. */
contract TokenManager is Pausable{

    using SafeMath for uint256;

    /** @dev Check if the ICO period is still open
      * @param _icoEnd as seconds since unix epoch
      */
    modifier isIcoPeriod(uint256 _icoEnd) {
        require(_icoEnd > now, "ICO period already finished");
        _;
    }

    /** @dev Check if the ICO period is still open
      * @param _icoEnd as seconds since unix epoch
      */
    modifier isNotIcoPeriod(uint256 _icoEnd) {
        require(_icoEnd <= now, "Is still ICO period");
        _;
    }

    /** @dev Event afer new Token has been created
      * @param _tokenAddress deployed contract address
      * @param _creator address of the token's creator
      */
    event tokenCreation(address indexed _tokenAddress, address indexed _creator);

    /** @dev Event afer some tokens has been purchased during ICO period
      * @param _tokenAddress deployed contract address
      * @param _buyer address of the token's buyer
      * @param _amount number of purchased tokens
      */
    event tokenICOPurchased(
        address indexed _tokenAddress,
        address indexed _buyer,
        uint256 _amount
    );

    /** @dev Event when a selling order has been placed
      * @param _tokenAddress deployed contract address
      * @param _seller address of the token's seller
      * @param _orderId unique ID
      * @param _amount number of offered tokens
      * @param _price price per offered token
      */
    event tokenOrderPublished(
        address indexed _tokenAddress,
        address indexed _seller,
        uint256 indexed _orderId,
        uint256 _amount,
        uint256 _price
    );

    /** @dev Event when a selling order has been canceled
      * @param _tokenAddress deployed contract address
      * @param _seller address of the token's seller
      * @param _orderId unique ID
      */
    event tokenOrderCanceled(
        address indexed _tokenAddress,
        address indexed _seller,
        uint256 indexed _orderId
    );

    /** @dev Event afer some tokens has been purchased after ICO period
      * @param _tokenAddress deployed contract address
      * @param _buyer address of the token's buyer
      * @param _orderId unique ID
      */
    event tokenOrderPurchased(
        address indexed _tokenAddress,
        address indexed _buyer,
        uint256 indexed _orderId
    );

    struct Order {
        uint256 amount;
        uint256 price;
        uint256 id;
    }

    uint256 public orderId = 1;

    struct Token {
        address creator;
        mapping(address => Order) resellers;
    }

    mapping(address => Token) public tokens;
    mapping(address => uint256) public balances;

    /** @dev Get the details of a selling order (amount, price, id)
      * @param _tokenAddress deployed contract address
      * @param _owner user that placed the order
      */
    function sellOrders(
        address _tokenAddress,
        address _owner
    )
        view
        public
        returns(uint256, uint256, uint256)
    {
        uint amount = tokens[_tokenAddress].resellers[_owner].amount;
        uint price = tokens[_tokenAddress].resellers[_owner].price;
        uint id = tokens[_tokenAddress].resellers[_owner].id;
        return(amount, price, id);
    }

    /** @dev Get the details of a selling order (amount, price, id)
      * @param _name Name of the token
      * @param _decimals Number of decimals of the token
      * @param _symbol Symbol of the token
      * @param _IcoEnd Time as seconds since unix epoch when ICO period ends
      * @param _initialPrice Token price for the ICO
      * @param _totalSupply Total number of tokens
      * @param _thumbnail IPFS hash for thumbnail
      * @param _description IPFS hash for HTML description
      */
    function createToken(
        string _name,
        uint8 _decimals,
        string _symbol,
        uint256 _IcoEnd,
        uint256 _initialPrice,
        uint256 _totalSupply,
        string _thumbnail,
        string _description
    )
        public
        whenNotPaused
    {
        address newTokenAddress = new ERC20(
          _name,
          _decimals,
          _symbol,
          _IcoEnd,
          _initialPrice,
          _totalSupply,
          msg.sender,
          _thumbnail,
          _description
        );

        tokens[newTokenAddress].creator = msg.sender;
        emit tokenCreation(newTokenAddress, msg.sender);
    }

    /** @dev Tokens are purchased during ICO period
      * @param _tokenAddress address od the deployed Token
      * @param _amount number of tokens to be purchased
      */
    function buyTokenIcoPeriod(
        ERC20 _tokenAddress,
        uint256 _amount
    )
        public
        payable
        whenNotPaused
        isIcoPeriod(_tokenAddress.icoEnd())
    {
        uint initalPrice = _tokenAddress.initialPrice();
        uint totalAmount = initalPrice.mul(_amount);
        address creator = _tokenAddress.creator();
        require(
          msg.value >= totalAmount,
          "Buyer does not send enough ETH for ICO purchase"
        );
        _tokenAddress.transferFrom(creator, msg.sender, _amount);
        balances[creator] += msg.value;
        emit tokenICOPurchased(_tokenAddress, msg.sender, _amount);
    }

    /** @dev An order is placed to resell tokens previosly purchased durig ICO period
      * @param _tokenAddress address od the deployed Token
      * @param _amount number of tokens to be sold
      * @param _price price set buy the user
      */
    function sellTokens(
        ERC20 _tokenAddress,
        uint256 _amount,
        uint256 _price
    )
        public
        isNotIcoPeriod(_tokenAddress.icoEnd())
        whenNotPaused
    {
        tokens[_tokenAddress].resellers[msg.sender].amount = _amount;
        tokens[_tokenAddress].resellers[msg.sender].price = _price;
        tokens[_tokenAddress].resellers[msg.sender].id = orderId;
        _tokenAddress.lockBalance(msg.sender, _amount);
        emit tokenOrderPublished(_tokenAddress, msg.sender, orderId, _amount, _price);
        orderId.add(1);
    }

    /** @dev Cancel a selling order
      * @param _tokenAddress address od the deployed Token
      */
    function cancelSellOrder(ERC20 _tokenAddress) public whenNotPaused {
        (uint256 amount, uint256 price, uint256 id) = sellOrders(_tokenAddress, msg.sender);
        require(id != 0, "Selling order does not exist and can not be canceled");
        delete tokens[_tokenAddress].resellers[msg.sender];
        _tokenAddress.unlockBalance(msg.sender, amount);
        emit tokenOrderCanceled(_tokenAddress, msg.sender, id);
    }

    /** @dev Buy tokens from a selling order after ICO period
      * @param _tokenAddress address od the deployed Token
      * @param _seller address of the user who placed the selling order
      */
    function buyTokens(
        ERC20 _tokenAddress,
        address _seller
    )
        public
        payable
        whenNotPaused
        isNotIcoPeriod(_tokenAddress.icoEnd())
    {
        (uint256 amount, uint256 price, uint256 id) = sellOrders(_tokenAddress, _seller);
        require(id != 0, "Selling order does not exist and can not be purchased");
        require(
          msg.value >= price.mul(amount),
          "Buyer does not send enough ETH for selling order purchase"
        );
        _tokenAddress.transferFrom(_seller, msg.sender, amount);
        _tokenAddress.unlockBalance(_seller, amount);
        delete tokens[_tokenAddress].resellers[_seller];
        balances[_seller] += msg.value;
        emit tokenOrderPurchased(_tokenAddress, msg.sender, id);
    }

    /** @dev User withdraws his balance.
      * @param _amount Amount to withdraw.
      */
    function withdrawBalance(uint _amount) external whenNotPaused {
        require(
          balances[msg.sender] >= _amount,
          "User does not have enough funds to withdraw"
        );
        balances[msg.sender] -= _amount;
        msg.sender.transfer(_amount);
    }
}
