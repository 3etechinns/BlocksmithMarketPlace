pragma solidity ^0.4.24;

import "./ERC20.sol";
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

    event tokenICOPurchased(
        address indexed _tokenAddress,
        address indexed _buyer,
        uint256 _amount
    );

    event tokenOrderPublished(
        address indexed _tokenAddress,
        address indexed _seller,
        uint256 indexed _orderId,
        uint256 _amount,
        uint256 _price
    );

    event tokenOrderCanceled(
        address indexed _tokenAddress,
        address indexed _seller,
        uint256 indexed _orderId
    );

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

    uint256 orderId = 1;

    struct Token {
        address creator;
        mapping(address => Order) resellers;
    }

    mapping(address => Token) tokens;
    mapping(address => uint256) balances;


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
        uint256 _amount
    )
        isIcoPeriod(_tokenAddress.icoEnd())
        public
        payable
    {
        uint initalPrice = _tokenAddress.initialPrice();
        uint totalAmount = initalPrice.mul(_amount);
        address creator = _tokenAddress.creator();
        require(
          msg.value >= totalAmount,
          "Buyer does not send enough ETH for ICO purchase"
        );
        _tokenAddress.transferFrom(creator, msg.sender, _amount);
        balances[creator].add(msg.value);
        emit tokenICOPurchased(_tokenAddress, msg.sender, _amount);
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
        tokens[_tokenAddress].resellers[msg.sender].id = orderId;
        _tokenAddress.lockBalance(msg.sender, _amount);
        emit tokenOrderPublished(_tokenAddress, msg.sender, orderId, _amount, _price);
        orderId.add(1);
    }

    function cancelSellOrder(ERC20 _tokenAddress) public {
        (uint256 amount, uint256 price, uint256 id) = sellOrders(_tokenAddress, msg.sender);
        require(id != 0, "Selling order does not exist and can not be canceled");
        delete tokens[_tokenAddress].resellers[msg.sender];
        _tokenAddress.unlockBalance(msg.sender, amount);
        emit tokenOrderCanceled(_tokenAddress, msg.sender, id);
    }

    function buyTokens(
        ERC20 _tokenAddress,
        address _seller
    )
        public
        isNotIcoPeriod(_tokenAddress.icoEnd())
        payable
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
        balances[msg.sender].add(msg.value);
        emit tokenOrderPurchased(_tokenAddress, msg.sender, id);
    }

    /** @dev User withdraws his balance.
      * @param _amount Amount to withdraw.
      */
    function withdrawBalance(uint _amount) external {
        require(
          balances[msg.sender] >= _amount,
          "User does not have enough funds to withdraw"
        );
        balances[msg.sender] -= _amount;
        msg.sender.transfer(_amount);
    }
}
