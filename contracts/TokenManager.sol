pragma solidity ^0.4.24;

import "./ERC20.sol";
//import "./IERC20.sol";
import "../libraries/SafeMath.sol";

contract TokenManager {

  using SafeMath for uint256;

  modifier isIcoPeriod(uint256 _icoEnd) { require(_icoEnd >= now); _; }

  event tokenCreation(address indexed tokenAddress);

  struct Offer {
    uint256 amount;
    uint256 price;
  }

  struct Token {
    address creator;
    mapping(address => Offer) resellers;
  }

  mapping(address => Token) tokens;
  mapping(address => uint256) creatorsBalances;

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
      emit tokenCreation(newTokenAddress);
  }

  function approveManager(ERC20 _tokenAddress) public {
    uint totalSupply = _tokenAddress.totalSupply();
    _tokenAddress.approve(address(this), totalSupply);
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
      require(msg.value >= totalAmount);
      _tokenAddress.transferFrom(creator, msg.sender, _units);
      creatorsBalances[creator].add(msg.value);
  }

  /* function withdrawCreatorBalance() {

  } */

}
