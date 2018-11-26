pragma solidity ^0.4.24;

import "./Ownable.sol";
import "../libraries/SafeMath.sol";

contract ERC20 is Ownable {
    using SafeMath for uint256;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event BalanceLocked(address indexed _owner, uint256 _value);
    event BalanceUnlocked(address indexed _owner, uint256 _value);

    uint256 constant private MAX_UINT256 = 2**256 - 1;

    mapping (address => uint256) public balances;

    mapping (address => uint256) public lockedBalances;

    mapping (address => mapping (address => uint256)) public allowed;

    uint256 public totalSupply;

    string public name;

    uint8 public decimals;

    string public symbol;

    uint256 public icoEnd;

    uint256 public initialPrice;

    address public creator;

    constructor (
        string _name,
        uint8 _decimals,
        string _symbol,
        uint256 _icoEnd,
        uint256 _initialPrice,
        uint256 _totalSupply,
        address _creator
    )
    {
      name = _name;
      decimals = _decimals;
      symbol = _symbol;
      icoEnd = _icoEnd;
      initialPrice = _initialPrice;
      totalSupply = _totalSupply;
      creator = _creator;
      balances[creator] = _totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    function lockedBalanceOf(address _owner) public view returns (uint256) {
        return lockedBalances[_owner];
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value);
        balances[msg.sender].sub(_value);
        balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        uint256 allowance = allowed[_from][msg.sender];
        require(balances[_from] >= _value && allowance >= _value);
        balances[_to] += _value;
        balances[_from] -= _value;
        if (allowance < MAX_UINT256) {
            allowed[_from][msg.sender].sub(_value);
        }
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function lockBalance(address _owner, uint256 _value) public onlyOwner returns (bool success) {
        require(balances[_owner] >= _value);
        lockedBalances[_owner] += _value;
        balances[_owner] -= _value;
        emit BalanceLocked(_owner, _value);
        return true;
    }

    function unlockBalance(address _owner, uint256 _value) public onlyOwner returns (bool success) {
        require(lockedBalances[_owner] >= _value);
        lockedBalances[_owner] -= _value;
        balances[_owner] += _value;
        emit BalanceUnlocked(_owner, _value);
        return true;
    }
}
