pragma solidity ^0.4.24;

import "./ERC20.sol";
//import "./IERC20.sol";
import "../libraries/SafeMath.sol";

contract TokenManager {

  using SafeMath for uint256;

  modifier isIcoPeriod(uint256 _icoEnd) {
    require(_icoEnd > now, "ICO period already finished");
    _;
  }

  modifier isNotIcoPeriod(uint256 _icoEnd) {
    require(_icoEnd <= now, "Is still ICO period");
    _;
  }

  event tokenCreation(address indexed _tokenAddress, address indexed _creator);

  event tokenOfferPublished(
      address indexed _tokenAddress,
      address indexed _seller,
      uint256 _amount,
      uint256 _price
    );

  struct Offer {
    uint256 amount;
    uint256 price;
  }

  struct Token {
    address creator;
    mapping(address => Offer) resellers;
  }

  mapping(address => Token) tokens;
  mapping(address => uint256) balances;

  function sellOffers(
      address _tokenAddress,
      address _owner
  )
      view
      public
      returns(uint256, uint256)
  {
    uint amount = tokens[_tokenAddress].resellers[_owner].amount;
    uint price = tokens[_tokenAddress].resellers[_owner].price;
    return(amount, price);
  }

  function createToken(
      string _name,
      uint8 _decimals,
      string _symbol,
      uint256 _IcoEnd,
      uint256 _initialPrice,
      uint256 _totalSupply
  )
      public
  {
      address newTokenAddress = new ERC20(
        _name,
        _decimals,
        _symbol,
        _IcoEnd,
        _initialPrice,
        _totalSupply,
        msg.sender
      );

      tokens[newTokenAddress].creator = msg.sender;
      emit tokenCreation(newTokenAddress, msg.sender);
  }

  function buyTokenIcoPeriod(
      ERC20 _tokenAddress,
      uint256 _units
  )
      isIcoPeriod(_tokenAddress.icoEnd())
      public
      payable
  {
      uint initalPrice = _tokenAddress.initialPrice();
      uint totalAmount = initalPrice.mul(_units);
      address creator = _tokenAddress.creator();
      require(msg.value >= totalAmount, "Buyer does not send enough ETH for ICO purchase");
      _tokenAddress.transferFrom(creator, msg.sender, _units);
      balances[creator].add(msg.value);
  }

  function sellTokens(
      ERC20 _tokenAddress,
      uint256 _amount,
      uint256 _price
  )
      public
      isNotIcoPeriod(_tokenAddress.icoEnd())
  {
      tokens[_tokenAddress].resellers[msg.sender].amount = _amount;
      tokens[_tokenAddress].resellers[msg.sender].price = _price;
      _tokenAddress.lockBalance(msg.sender, _amount);

      emit tokenOfferPublished(_tokenAddress, msg.sender, _amount, _price);
  }

  /* function buyTokens(
      address _tokenAddress,
      address _seller
  )
      public
      isNotIcoPeriod(_tokenAddress.icoEnd())
  {
      uint price = tokens[_tokenAddress].resellers[_seller].price;
      uint amount = tokens[_tokenAddress].resellers[_seller].amount;
      require(msg.value >= price.mul(amount));
      _tokenAddress.

      tokens[_tokenAddress].resellers[_seller].price = 0;
      tokens[_tokenAddress].resellers[_seller].amount = 0;

  } */



  /* function withdrawBalance() {

  } */

}
