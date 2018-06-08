pragma solidity ^0.4.23;
import "../libs/SafeMath.sol";
import "../permission/PermissionProviderInterface.sol";
import "../riskManagement/RiskManagementProviderInterface.sol";
import "../price/PriceProviderInterface.sol";
import "../libs/ERC20.sol";

contract FundTemplate {

    using SafeMath for uint256;

    //Permission Control
    PermissionProviderInterface internal permissionProvider;
    //Price
    PriceProviderInterface internal priceProvider;
    // Risk Provider
    RiskManagementProviderInterface internal riskProvider;
    //ERC20
    ERC20 internal erc20Token;

    //enum
    enum FundStatus { Pause, Close , Active }

    uint public constant DENOMINATOR = 10000;


    //struct
    struct FUND {
        uint id;
        string name;
        string description;
        string category;
        address[] tokenAddresses;
        uint[] weights;
        uint managementFee;
        uint withdrawCycle; //*hours;
        uint deposit;       //deposit
        FundStatus status;
        //uint follower;
        //uint amount;
        //bytes32 exchangeId;
    }
    struct FUNDExtend {
        address owner;
        bool limit;
        uint createTime;
        uint lockTime;
    }


    //Costant
    uint public pendingOwnerFee;
    uint public withdrawedFee;
    uint256 public totalSupply;
    string public name;
    uint256 public decimals;
    string public symbol;
    address public owner;
    uint public withdrawTime;
    uint public olympusFee;
    address public constant OLYMPUS_WALLET = 0x09227deaeE08a5Ba9D6Eb057F922aDfAd191c36c;

    FUND          public         _FUND;
    FUNDExtend    public         _FUNDExtend;


    //Maping
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;

    //Modifier

    modifier  onlyFundOwner() {
        require(tx.origin == _FUNDExtend.owner && _FUNDExtend.owner != 0x0);
        _;
    }

    modifier  onlyTokenizedOwner() {
        require(msg.sender == owner );
        _;
    }
    modifier  onlyTokenizedAndFundOwner() {
        require(msg.sender == owner && tx.origin == _FUNDExtend.owner);
        _;
    }

    modifier onlyCore() {
        require(permissionProvider.has(msg.sender, permissionProvider.ROLE_CORE()));
        _;
    }

    modifier withNoRisk(address _from, address _to, address _tokenAddress, uint256 _value) {
        require(
            !riskProvider.hasRisk(
             _from,
             _to,
             _tokenAddress,
             _value,
             0 // Price for now not important
        ), "The transaction is risky");

        _;
    }
    //Fix for short address attack against ERC20
    //  https://vessenes.com/the-erc20-short-address-attack-explained/
    modifier onlyPayloadSize(uint size) {
        assert(msg.data.length == size + 4);
        _;
    }

    // -------------------------- ERC20 STANDARD --------------------------
    constructor (string _symbol, string _name,uint _decimals) public {
        require(_decimals >= 0 && _decimals <= 18);
        decimals = _decimals;
        symbol = _symbol;
        name = _name;
        owner = msg.sender;
        _FUNDExtend.owner = tx.origin;
        _FUND.status = FundStatus.Pause;
        totalSupply = 0;
        _FUNDExtend.limit = false;
        _FUNDExtend.createTime = now;
        olympusFee = 0;
     }

    function balanceOf(address _owner) view public returns (uint256) {
        return balances[_owner];
    }

    function transfer(address _recipient, uint256 _value)
     onlyPayloadSize(2*32)
     withNoRisk(msg.sender, _recipient, address(this), _value)
     public {
        require(balances[msg.sender] >= _value && _value > 0, "Balance is not enough or is empty");
        require(_FUNDExtend.lockTime < now , "Fund lock time hasn't expired yet");
        require(_FUND.status == FundStatus.Active, "Fund Status is not active");
        if (_recipient == address(this)) {
            balances[msg.sender] -= _value;
            require(totalSupply - _value > 0);
            totalSupply -= _value;
            emit Destroy(msg.sender, _value);
            //GetMoneyBack
        } else {
            balances[msg.sender] -= _value;
            balances[_recipient] += _value;
            emit Transfer(msg.sender, _recipient, _value);
        }
    }

    function transferFrom(address _from, address _to, uint256 _value)
      withNoRisk(_from, _to, address(this), _value)
       public {
        require(balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0);
        require(_FUND.status == FundStatus.Active, "Fund Status is not active");
        require(_FUNDExtend.lockTime < now );
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
    }

    function allowance(address _owner, address _spender) view public returns (uint256) {
        return allowed[_owner][_spender];
    }

    // -------------------------- TOKENIZED --------------------------
    function createFundDetails(
        uint _id,
        string _name,
        string _description,
        string _category,
        address[] memory _tokenAddresses,
        uint[] memory _weights,
        uint _withdrawCycle

    ) public onlyTokenizedAndFundOwner returns(bool success)
    {
        _FUND.id = _id;
        _FUND.name = _name;
        _FUND.description = _description;
        _FUND.category = _category;
        _FUND.tokenAddresses = _tokenAddresses;
        _FUND.weights = _weights;
        _FUND.managementFee = 1;
        _FUND.status = FundStatus.Active;
        _FUND.withdrawCycle = _withdrawCycle * 3600 + now;
        withdrawTime = _withdrawCycle;
        return true;
    }

    function getFundDetails() public view returns(
        address _owner,
        string _name,
        string _symbol,
        uint _totalSupply,
        string _description,
        string _category,
        address[]  _tokenAddresses,
        uint[]  _weights
    )
    {
        _name = _FUND.name;
        _symbol = symbol;
        _owner = _FUNDExtend.owner;
        _totalSupply = totalSupply;
        _description = _FUND.description;
        _category = _FUND.category;
        _tokenAddresses = _FUND.tokenAddresses;
        _weights = _FUND.weights;
    }

    function changeTokens(address[] _tokens, uint[] _weights) public onlyFundOwner returns(bool success){
        require(_tokens.length == _weights.length);
        _FUND.tokenAddresses = _tokens;
        _FUND.weights = _weights;
        return true;
    }

    // -------------------------- MAPPING --------------------------
    function lockFund (uint _hours) public onlyTokenizedAndFundOwner  returns(bool success){
        _FUNDExtend.lockTime += now + _hours * 3600;
        return true;
    }

    // Minimal 0.1 ETH
    function () public
      withNoRisk(msg.sender, address(this), 0x00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee, msg.value)
      payable {
        uint _fee;
        uint _realBalance;
        uint _realShare;
        uint _sharePrice;

        require(_FUND.status == FundStatus.Active, "The Fund is not active");
        require(msg.value >= 10**15, "Minimum value to invest is 0.1 ETH" );

        (_realBalance,_fee) = calculateFee(msg.value);

        _sharePrice = getPriceInternal(msg.value);

        pendingOwnerFee += _fee;

        _realShare = _realBalance / _sharePrice;

        balances[msg.sender] += _realShare * 10 ** decimals;
        totalSupply += _realShare * 10 ** decimals;
        emit Transfer(owner, msg.sender, _realShare * 10 ** decimals);
        emit BuyFund(msg.sender, _realShare * 10 ** decimals);
    }

    function calculateFee(uint invest) internal view returns(uint _realBalance,uint _managementFee){
        _managementFee = invest / 100 * _FUND.managementFee;
        _realBalance = invest - _managementFee;
    }

    function getPriceInternal(uint _value) internal view returns(uint _price){
        uint _totalValue = 0;
        uint _expectedRate;
        if(totalSupply == 0){return 10**17;} // 0.1 Eth

        for (var i = 0; i < _FUND.tokenAddresses.length; i++) {
            erc20Token = ERC20(_FUND.tokenAddresses[i]);

            uint _balance = erc20Token.balanceOf(address(this));
            uint _decimal = erc20Token.decimals();
            if(_balance == 0){continue;}
            (_expectedRate, ) = priceProvider.getRates(_FUND.tokenAddresses[i], 10**_decimal);
            if(_expectedRate == 0){continue;}
            _totalValue += (_balance * 10**18) / _expectedRate;
        }

        if (_totalValue == 0){return 10**18;} // 1 Eth

        return ((_totalValue + address(this).balance - pendingOwnerFee - _value) * 10 ** decimals ) / totalSupply;
    }

    function getPrice() public view returns(uint _price){
        _price = getPriceInternal(0);
    }

    // -------------------------- FEES --------------------------
    function getPendingManagmentFee() onlyFundOwner public view returns(uint) {
        return pendingOwnerFee;
    }

    function getWithdrawedFee() onlyFundOwner public view returns(uint) {
        return withdrawedFee;
    }

    function withdrawFee() public onlyFundOwner {
        require(pendingOwnerFee > 0);
        require(_FUND.withdrawCycle <= now, "Withdraw is loacked, wait some minutes");
        _FUND.withdrawCycle = withdrawTime * 3600 + now;

        uint olympusAmount = pendingOwnerFee * olympusFee / DENOMINATOR;
        _FUNDExtend.owner.transfer(pendingOwnerFee-olympusAmount);
        OLYMPUS_WALLET.transfer(olympusAmount);
        withdrawedFee += (pendingOwnerFee - olympusAmount);
        pendingOwnerFee = 0;
    }

    function setOlympusFee(uint _olympusFee ) onlyCore public {
        require(_olympusFee > 0);
        require(_olympusFee < DENOMINATOR);
        olympusFee = _olympusFee;
    }


    // -------------------------- PROVIDERS --------------------------

    function setPermissionProvider(address _permissionAddress) public onlyTokenizedOwner  {
        permissionProvider = PermissionProviderInterface(_permissionAddress);
    }

    function setPriceProvider(address _priceAddress) public onlyTokenizedOwner {
        priceProvider = PriceProviderInterface(_priceAddress);
    }

    function setRiskProvider(address _riskProvider) public onlyTokenizedOwner {
        riskProvider = RiskManagementProviderInterface(_riskProvider);
    }


    // -------------------------- EVENTS --------------------------
 	  // Event which is triggered to log all transfers to this contract's event log
    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 _value
    );
	  //Event which is triggered whenever an owner approves a new allowance for a spender.
    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    event Destroy(
        address indexed _spender,
        uint256 _value
    );

    event PersonalLocked(
        address indexed _spender,
        uint256 _value,
        uint256 _lockTime
    );

    event BuyFund(
        address indexed _spender,
        uint256 _value
    );

    event LogS( string text);
    event LogN( uint value, string text);
}