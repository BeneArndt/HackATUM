contract Bank is IBank{

    //ERC20 hak = new ERC20("hakatum", "HAK");
    
    mapping(address => Account) private accETH;
    mapping(address => Account) private accHAK;
    mapping(address => Account) private borETH;
    mapping(address => uint256) virtualPrice;
    
    address ETHcontract = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address HAKcontract = 0xBefeeD4CB8c6DD190793b1c97B72B60272f3EA6C; 
    address POcontract = 0xc3F639B8a6831ff50aD8113B438E2Ef873845552;

    constructor(address POaddress, address HAKaddress)
    {
        HAKcontract = HAKaddress;
        POcontract = POaddress;
    }
    
    
    function deposit(address token, uint256 amount) payable external override returns (bool){
        require(
            amount > 0,
            "Deposit should be greater than 0"
            );

        if(token != ETHcontract && token != HAKcontract) { revert("token not supported"); }
        calcNewInterest(token, true);
        emit Deposit(msg.sender, token, amount);
        if(token == ETHcontract){
            accETH[msg.sender].deposit = accETH[msg.sender].deposit + amount;
        }
        if(token == HAKcontract){
            accHAK[msg.sender].deposit = accHAK[msg.sender].deposit + amount;
        }
        
        return true;
    }
    
    function withdraw(address token, uint256 amount) external override returns (uint256){
        if(token != ETHcontract && token != HAKcontract) { revert("token not supported"); }
            
        if(token == ETHcontract){
            if(accETH[msg.sender].deposit == 0) { revert("no balance"); }
            if(accETH[msg.sender].deposit < amount) { revert("amount exceeds balance"); }
            //require(accETH[msg.sender].deposit >= amount, 
            //"You dont have enough balance!");
            calcNewInterest(token, true);
            uint256 receivedAmount;
            if(amount == 0){
                receivedAmount = accETH[msg.sender].interest + accETH[msg.sender].deposit;
                accETH[msg.sender].deposit = 0;
            }
            else{
                receivedAmount = accETH[msg.sender].interest + amount;
                accETH[msg.sender].deposit -= amount;
            }
            accETH[msg.sender].interest = 0;
            emit Withdraw(msg.sender, token, receivedAmount);
        return receivedAmount;
        }
        
        if(token == HAKcontract){
            if(accHAK[msg.sender].deposit == 0) { revert("no balance"); }
            if(accHAK[msg.sender].deposit < amount) { revert("amount exceeds balance"); }
            //require(accHAK[msg.sender].deposit >= amount, 
            //"You dont have enough balance!");
            calcNewInterest(token, true);
            uint256 receivedAmount;
            if(amount == 0){
                receivedAmount = accHAK[msg.sender].interest + accHAK[msg.sender].deposit;
                accHAK[msg.sender].deposit = 0;
            }
            else{
                receivedAmount = accHAK[msg.sender].interest + amount;
                accHAK[msg.sender].deposit -= amount;
            }
            accHAK[msg.sender].interest = 0;
            emit Withdraw(msg.sender, token, receivedAmount);
        return receivedAmount;
        }
    }
    
    function borrow(address token, uint256 amount) external override returns (uint256){
        if(token != ETHcontract) { revert("token not supported"); }
        if(accHAK[msg.sender].deposit == 0) { revert("no collateral deposited"); }
        calcNewInterest(token, false);
        borETH[msg.sender].deposit += amount;
        uint256 colRat = this.getCollateralRatio(HAKcontract, msg.sender);
        emit Borrow(msg.sender, token, amount, colRat); 
        return amount;
    }
    
    function repay(address token, uint256 amount) payable external override returns (uint256){
        if(token != ETHcontract) { revert("token not supported"); }
        calcNewInterest(token, false);
        if((borETH[msg.sender].deposit + borETH[msg.sender].interest) == 0) { revert("nothing to repay"); }
        require(amount <= (borETH[msg.sender].deposit + borETH[msg.sender].interest), "nothing to repay");
        if(amount <= borETH[msg.sender].interest){
            borETH[msg.sender].interest -= amount;
        }
        else{
            uint256 overflow = amount - borETH[msg.sender].interest;
            borETH[msg.sender].interest = 0;
            borETH[msg.sender].deposit -= overflow;
        }
        uint256 restDebt = (borETH[msg.sender].deposit + borETH[msg.sender].interest);
        emit Repay(msg.sender, token, restDebt); 
        return restDebt;
    }
    
    function liquidate(address token, address account) payable external override returns (bool){
        require(token == HAKcontract, "not HAK token");
        if(this.getCollateralRatio(token, account) < 15000){
            uint256 amountLiquidated = accHAK[account].deposit +accHAK[account].interest;
            borETH[msg.sender].deposit += borETH[account].deposit + borETH[account].interest;
            accHAK[msg.sender].deposit += accHAK[account].deposit + accHAK[account].interest;
            borETH[account].deposit = 0;
            borETH[account].interest = 0;
            accHAK[account].deposit = 0;
            accHAK[account].interest = 0;
            emit Liquidate(msg.sender, account, token, amountLiquidated, 0);
            return true;
        }
        return false;
    }
    
    
    function getCollateralRatio(address token, address account) view external override returns (uint256){
        //(deposits[account] + accruedInterest[account]) * 10000 * HAKprice/ 
        //(borrowed[account] + owedInterest[account]) 
        require(token == HAKcontract, "not HAK token");
        if(borETH[account].deposit == 0){
            return type(uint256).max;
        }
        //PriceOracleTest ptsd = new PriceOracleTest();
        //uint256 HAKprice = ptsd.getVirtualPrice(token);
        uint256 numerator = (accHAK[account].deposit + accHAK[account].interest) * 10000;// * HAKprice;
        uint256 denominator = (borETH[account].deposit + borETH[account].interest);
        uint256 result = numerator / denominator;
        return result;
    }
    
    
    function getBalance(address token) view external override returns (uint256){        
        if(token != ETHcontract && token != HAKcontract) { revert("token not supported"); }  
        if(token == ETHcontract){
            return accETH[msg.sender].deposit + accETH[msg.sender].interest;
        }
        
        if(token == HAKcontract){
            return accHAK[msg.sender].deposit + accHAK[msg.sender].interest;
        }
    }
    
    
    function getBlockDelta(uint256 blockStart) view private returns (uint256) {
        return block.number - blockStart;
    }
    
    function calcNewInterest(address token, bool isBalance) private returns (uint256) {        
        if(token != ETHcontract && token != HAKcontract) { revert("token not supported"); }            
        if(isBalance)
        {
            if(token == ETHcontract){ 
                uint256 delta = getBlockDelta(accETH[msg.sender].lastInterestBlock);
                accETH[msg.sender].interest += accETH[msg.sender].deposit * delta * 3 / 10000;
                accETH[msg.sender].lastInterestBlock = block.number;
                return accETH[msg.sender].interest;
            }
            
            if(token == HAKcontract){
                uint256 delta = getBlockDelta(accHAK[msg.sender].lastInterestBlock);
                accHAK[msg.sender].interest += accHAK[msg.sender].deposit * delta * 3 / 10000;
                accHAK[msg.sender].lastInterestBlock = block.number;
                return accHAK[msg.sender].interest;
            }
        }
        else
        {
            uint256 delta = getBlockDelta(borETH[msg.sender].lastInterestBlock);
            borETH[msg.sender].interest += borETH[msg.sender].deposit * delta * 5 / 10000;
            borETH[msg.sender].lastInterestBlock = block.number;
            return borETH[msg.sender].interest;
        }
    }
}