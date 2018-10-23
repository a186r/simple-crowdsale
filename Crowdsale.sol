pragma solidity 0.4.25;

// 1.部署token合约,需要设置一个ICO结束时间
// 2.使用上一步得到的token地址部署Crowdsale合约
// 3.使用setCrowdsale()方法在token合约中设置Crowdsale地址以便于分发token
// 4.讲Crowdsale地址公开给投资者，以便他们可以发送以太购买token

library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {

      // Gas optimization: this is cheaper than asserting 'a' not being zero, but the

      // benefit is lost if 'b' is also tested.

      // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522

        if (a == 0) {

            return 0;

        }

        c = a * b;  

        assert(c / a == b);

        return c;

    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {

      // assert(b > 0); // Solidity automatically throws when dividing by 0

      // uint256 c = a / b;

      // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return a / b;

    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {

        assert(b <= a);

        return a - b;

    }

    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {

        c = a + b;

        assert(c >= a);

        return c;

    }

}

contract Token{
    using SafeMath for uint256;

    event Transfer(address indexed from,address indexed to,uint256 value);
    event Approval(address indexed owner,address indexed spender,uint256 value);

    mapping(address => uint256) balances;

    uint256 totalSupply_;

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function transfer(address _to,uint256 _value) public returns(bool){
        require(_value <= balances[msg.sender]);
        require(_to != address(0));
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        emit Transfer(msg.sender,_to,_value);
        return true;
    }

    function balanceOf(address _owner) public view returns(uint256) {
        return balances[_owner];
    }

    mapping (address => mapping(address => uint256)) internal allowed;

    function transferFrom(address _from,address _to, uint256 _value) public returns(bool){
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
        require(_to != address(0));

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);

        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

        emit Transfer(_from,_to,_value);

        return true;

    }

    function approve(address _spender,uint256 _value) public returns (bool){
        allowed[msg.sender][_spender] = _value;

        emit Approval(msg.sender,_spender,_value);

        return true;
    }

    function allowance(address _owner,address _spender) public view returns (uint256){
        return allowed[_owner][_spender];
    }

    function increaseApproval(address _spender,uint256 _addedValue) public returns(bool){
        allowed[msg.sender][_spender] = (allowed[msg.sender][_spender].add(_addedValue));
        emit Approval(msg.sender,_spender,allowed[msg.sender][_spender]);
    }

    function decreaseApproval (address _spender,uint256 _subtractedValue) public returns (bool){
        uint256 oldValue = allowed[msg.sender][_spender];

        if(_subtractedValue >= oldValue) {
            allowed[msg.sender][_spender] = 0;
        }else{
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }

        emit Approval(msg.sender,_spender,allowed[msg.sender][_spender]);
        return true;
    }
}

contract ICOToken is Token{
    string public name = "ICOToken";
    string public symbol = "ITK";
    uint256 public decimals = 18;

    address public crowdsaleAddress;
    address public owner;
    uint256 public ICOEndTime;    

    modifier onlyCrowdsale{
        require(msg.sender == crowdsaleAddress);
        _;
    }

    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }

    modifier afterCrowdsale{
        require(now > ICOEndTime || msg.sender == crowdsaleAddress);
        _;
    }
    
    constructor (uint256 _IcoEndTime) public Token(){
        require(_IcoEndTime > 0);
        totalSupply_ = 100e24;
        owner = msg.sender;
        ICOEndTime = _IcoEndTime;
    }

    function setCrowdsale(address _crowdsaleAddress) public onlyOwner {
        require(_crowdsaleAddress != address(0));
        crowdsaleAddress = _crowdsaleAddress;
    }

    function buyTokens(address _receive,uint256 _amount) public onlyCrowdsale{
        require(_receive != address(0));
        require(_amount > 0);
        transfer(_receive,_amount);
    }

    // 重写transfer方法，在ico结束之前不允许transfer
    function transfer(address _to,uint256 _value) public afterCrowdsale returns (bool){
        return super.transfer(_to,_value);
    }

    function transferFrom(address _from,address _to ,uint256 _value) public afterCrowdsale returns (bool){
        return super.transferFrom(_from,_to,_value);
    }

    function approve(address _spender,uint256 _value) public afterCrowdsale returns (bool){
        return super.approve(_spender,_value);
    }

    function increaseApproval(address _spender,uint _addedValue) public afterCrowdsale returns (bool success){
        return super.increaseApproval(_spender,_addedValue);
    }

    function decreaseApprove(address _spender,uint _subtractedValue) public afterCrowdsale returns (bool success){
        return super.decreaseApproval(_spender,_subtractedValue);
    }

    function emergencyExtract() external onlyOwner{
        owner.transfer(address(this).balance);
    }
}

contract Crowdsale{

    using SafeMath for uint256;

    // ico是否完成
    bool icoCompleted;
    // ico开始时间
    uint256 public icoStartTime;
    // ico结束时间
    uint256 public icoEndTime;
    // 代币价格
    uint256 public tokenRate;
    // ICOToken
    ICOToken public token;
    // // 代币地址
    // address public tokenAddress;
    // 募资目标
    uint256 public fundingGoal;

    address public owner;

    uint256 public tokensRaised;

    uint256 public etherRaised;

    // ico完成
    modifier whenIcoCompleted{
        require(icoCompleted);
        _;
    }

    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }

    function () public payable{
        buy();
    }

    // 添加构造函数,在创建合约的时候初始化好上面的参数
    constructor (
        uint256 _icoStart,
        uint256 _icoEnd,
        uint256 _tokenRate,
        address _tokenAddress,
        uint256 _fundingGoal) public {

        require(
            _icoStart != 0 &&
            _icoEnd >= _icoStart &&
            _tokenRate != 0 &&
            _tokenAddress != address(0) &&
            _fundingGoal != 0
        );

        icoStartTime = _icoStart;
        icoEndTime = _icoEnd;
        tokenRate = _tokenRate;
        token = ICOToken(_tokenAddress);
        fundingGoal = _fundingGoal;
        owner = msg.sender;
    }
    uint256 public rateOne = 5000;
    uint256 public rateTwo = 4000;
    uint256 public rateThree = 3000;
    uint256 public rateFour = 2000;

    uint256 public limitTierOne = 25e6 * (10 ** token.decimals());
    uint256 public limitTierTwo = 50e6 * (10 ** token.decimals());
    uint256 public limitTierThree = 75e6 * (10 ** token.decimals());
    uint256 public limitTierFour = 100e6 * (10 ** token.decimals());


    function buy() public payable{
        require(tokensRaised < fundingGoal);
        require(now < icoEndTime && now > icoStartTime);

        uint256 tokensToBuy;
        uint256 etherUsed = msg.value;
        tokensToBuy = etherUsed * (10 ** token.decimals()) / 1 ether * tokenRate;

        // 如果募集的资金小于2500w，则使用第一个费率
        if (tokensRaised < limitTierOne){
            // 费率1
            tokensToBuy = etherUsed * (10 ** token.decimals()) / 1 ether * rateOne;

            // 如果购买token的数量超出此等级
            if(tokensRaised + tokensToBuy > limitTierOne){
                tokensToBuy = calculateExcessToken(etherUsed,limitTierOne,1,rateOne);
            }
        }else if(tokensRaised >= limitTierOne && tokensRaised < limitTierTwo) {
            // 费率2
            tokensToBuy = etherUsed * (10 ** token.decimals()) / 1 ether * rateTwo;

            if(tokensRaised + tokensToBuy > limitTierTwo){
                tokensToBuy = calculateExcessToken(etherUsed,limitTierTwo,2,rateTwo);
            }
        }else if(tokensRaised >= limitTierTwo && tokensRaised < limitTierThree) {
            // 费率3
            tokensToBuy = etherUsed * (10 ** token.decimals()) / 1 ether * rateThree;

            if(tokensRaised + tokensToBuy > limitTierThree){
                tokensToBuy = calculateExcessToken(etherUsed,limitTierThree,3,rateThree);
            }
        }else if(tokensRaised >= limitTierThree && tokensRaised < limitTierFour) {
            // 费率4
            tokensToBuy = etherUsed * (10 ** token.decimals()) / 1 ether * rateFour;
        }

        // 检查是否到达硬顶，以方便退还多余的ether
        if(tokensRaised + tokensToBuy > fundingGoal){
            uint256 exceedingTokens = tokensRaised + tokensToBuy - fundingGoal;

            uint256 exceedingEther;

            // 将token转换为ether并退还
            exceedingEther = exceedingTokens * 1 ether / tokenRate / token.decimals();

            msg.sender.transfer(exceedingEther);

            tokensToBuy -= exceedingTokens;

            etherUsed -= exceedingEther;
        }

        // 发送token给购买人
        token.buyTokens(msg.sender,tokensToBuy);
        
        tokensRaised += tokensToBuy;
        // etherRaised += etherUsed;
    }

    function calculateExcessToken(
        uint256 amount,
        uint256 tokensThisTier,
        uint256 tierSelected,
        uint256 _rate
    ) public returns (uint256 totalTokens){
        require(amount > 0 && tokensThisTier > 0 && _rate > 0);
        require(tierSelected >= 1 && tierSelected <= 4);

        uint256 weiThisTier = tokensThisTier.sub(tokensRaised).div(_rate);
        uint256 weiNextTier = amount.sub(weiThisTier);
        uint256 tokensNextTier = 0;
        bool returnTokens = false;

        if(tierSelected != 4)
            tokensNextTier = calculateTokensTier(weiNextTier,tierSelected.add(1));
        else
            returnTokens = true;

        totalTokens = tokensThisTier.sub(tokensRaised).add(tokensNextTier);

        // 最后transfer
        if(returnTokens) msg.sender.transfer(weiNextTier);
    }

    function calculateTokensTier(uint256 weiPaid,uint256 tierSelected) internal constant returns(uint256 calculatedTokens){
        require(weiPaid > 0);
        require(tierSelected >= 1 && tierSelected <= 4);

        if(tierSelected == 1)
            calculatedTokens = weiPaid * (10 ** token.decimals()) / 1 ether * rateOne;
        else if(tierSelected == 2)
            calculatedTokens = weiPaid * (10 ** token.decimals()) / 1 ether * rateTwo;
        else if(tierSelected == 3)
            calculatedTokens = weiPaid * (10 ** token.decimals()) / 1 ether * rateThree;
        else if(tierSelected == 4)
            calculatedTokens = weiPaid * (10 ** token.decimals()) / 1 ether * rateFour;
    }

    // function unbuy() public payable{
    //     uint256 tokensToConvert = 10;
    //     uint256 weiFromTokens;
    //     weiFromTokens = tokensToCovert * 1 / tokenRate / 1e5;
    // }

    function extractEther() public  whenIcoCompleted{
        owner.transfer(address(this).balance);
    }
}