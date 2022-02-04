// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
/*
Typical transaction scenarios:

1. The seller calls the sell function to generate an order. You can specify or not specify the buyer's address

2. The buyer calls the buy function to pre order.

3. Both parties discussed and reached an agreement through ECC encrypted communication system

4. The seller calls setallowbuyer to set the address of the designated buyer

5. The seller confirms that the transaction between both parties can be carried out, and calls selllock to lock

6. The buyer confirms that the transaction between both parties can be carried out and calls buylock to lock (before that, both parties can cancel the order through sellercancelorder and buyercancelorder)

7. Make payment in private

8. after receiving the payment, the seller calls ReceiveUSDLock.

9. The seller will sell the goods to the buyer

10. buyers confirm that after receiving the sale, call ReceiveObjectLock and complete the transaction.
*/

contract ERCContract is Context,Ownable,ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address public EUSDTAddress;//USDT address
    uint256 private aproveunlocked=1;//lock

    uint256 private MAXAmount=10000000000*10**18;//MAX buy amount < 100y
    mapping(address=>bool) public TransactionBan;//Ban

    mapping(address=>mapping(uint256=>uint256)) public UserTransactionOrders;//
    mapping(address=>uint256) public TransactionOrdersLen;
    mapping(uint256=>TransactionOrder) public AllTransactionOrders;
    uint256 public allTransactionOrderIndex;
    uint256 public allTax;
    uint256 public taxRate=100;
    uint256 public cancelOrderTax=300;
    mapping(uint=>address) private WhiteList;
    uint256 public WhiteListIndex=0;
    event SetWhiteListEvent(address[] users);
    event TransactionOrderBuildEvent(uint256 _identifier,address _seller,string _sellObject,uint256 _stackAmount,address _allowbuyer,uint256 _transactionOrderBiuldTime);
    struct TransactionOrder {//User's order data structure
        uint256 identifier;//Order code
        string sellObject;//The items sold can be described arbitrarily. If it is a secret transaction, anyone will write irrelevant information
        uint256 stackAmount;//The token of the goods sold by the seller that needs to be pledged, which is three times the price of the goods sold in USD
        address seller;//Seller address
        address allowbuyer;//Specify a buyer
        address buyer;//Buyer address
        uint256 buyerstackAmount;//The number of tokens that the buyer needs to pledge will be automatically set to 1 / 3 of the seller's pledge
        bool sellLock;//Seller lock
        bool buyLock;//Buyer lock The buyer is locked. You can cancel the order before it becomes true. However, the cancelling party will deduct a certain tax and return it to the pledge, and the other party will return the original amount to the pledge.
        bool receiveUSD;//After the seller receives the payment cash, change the value to true
        bool receiveObject;//After the buyer receives the item, change the value to true
        uint256 transactionOrderBiuldTime;//Order creation time

    }
    constructor(address _eusdtAddress) {
        EUSDTAddress=_eusdtAddress;//The token contract address can be usdt or erc20 created by yourself, or eusdt created by yourself
    } 
    // Set transaction tax rate_ When txrate is 1, the lowest tax rate is 1 / 10000, i.e. 0.01%. The highest level is 100%.
    function SetTxRate(uint256 _txrate)public onlyOwner returns(bool){
        require(_txrate<10000,"_txrate must <10000");
        taxRate=_txrate;
        return true;
    }
    //Sellers sell items and create orders
    function Sell(string calldata _sellObject,uint256 _stackAmount,address _allowbuyer) public nonReentrant returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        //Administrators can block a certain address for transactions
        require(!TransactionBan[_msgSender()],"Transaction ban");
        require(_stackAmount>=1000000000000000000&&_stackAmount<MAXAmount,"Buy Amount out of range must be more than 1 less than MAXAmount");
        //Sellers sell items and create orders. Before that, the user needs to complete the authorization of this transaction contract by eusdt. The recommended authorization value is max (uint256), that is, full authorization
        require(IERC20(EUSDTAddress).balanceOf(_msgSender())>=_stackAmount,"The number of remaining tokens in the seller is insufficient");
        require(IERC20(EUSDTAddress).allowance(_msgSender(),address(this))>=_stackAmount,"Insufficient number of eusdt approvals");//
        //Payment of pledged eusdt to transaction contract
        IERC20(EUSDTAddress).safeTransferFrom(_msgSender(),address(this),_stackAmount);
        //biuld oder
        TransactionOrder memory oder;
        oder.identifier=allTransactionOrderIndex;
        oder.sellObject=_sellObject;
        oder.stackAmount=_stackAmount;
        oder.seller=_msgSender();
        oder.allowbuyer=_allowbuyer;
        oder.transactionOrderBiuldTime=block.timestamp;
        
        uint256 userindex=TransactionOrdersLen[_msgSender()];
        UserTransactionOrders[_msgSender()][userindex]=oder.identifier;
        AllTransactionOrders[allTransactionOrderIndex]=oder;

        allTransactionOrderIndex=allTransactionOrderIndex.add(1);
        TransactionOrdersLen[_msgSender()]=userindex.add(1);

        emit TransactionOrderBuildEvent(oder.identifier,oder.seller,oder.sellObject,oder.stackAmount,oder.allowbuyer,oder.transactionOrderBiuldTime);
        return true;
    }
    //Set the address of the specified buyer and trader, which can be set directly in sell, or set the value to address (0) in sell to ensure that everyone can buy, and then call this function to set
    function setallowbuyer(uint256 _identifier,address _allowbuyer) public returns  (bool) {
        TransactionOrder memory oder= AllTransactionOrders[_identifier];
        require(oder.stackAmount>0,"cancel oder");//cancel Oder
        require(oder.seller==_msgSender(),"not owner");
        require(oder.sellLock==false,"sell Locked");//锁了不能改
        oder.allowbuyer=_allowbuyer;
        AllTransactionOrders[_identifier]=oder;
        return true;
        
    }
    //The buyer wants to buy the order and pledge his eusdt
    function Buy(uint256 _identifier) public lock returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        require(!TransactionBan[_msgSender()],"Transaction ban");
        //获得订单
        require(AllTransactionOrders[_identifier].seller!=address(0),"null oder");//空订单  
        require(AllTransactionOrders[_identifier].stackAmount>0,"cancel oder");//cancel Oder

        require(AllTransactionOrders[_identifier].sellLock==false,"sell Locked");//卖方未锁定
        if(AllTransactionOrders[_identifier].allowbuyer!=address(0)){
            require(AllTransactionOrders[_identifier].allowbuyer==_msgSender(),"you are not allowbuyer");//卖方未锁定
        }
        uint256 _buyerStackAmount=AllTransactionOrders[_identifier].stackAmount.div(3).mul(1);
        require(IERC20(EUSDTAddress).balanceOf(_msgSender())>=_buyerStackAmount,"The number of remaining tokens in the seller is insufficient");
        require(IERC20(EUSDTAddress).allowance(_msgSender(),address(this))>=_buyerStackAmount,"Insufficient number of eusdt approvals");//
        IERC20(EUSDTAddress).safeTransferFrom(_msgSender(),address(this),_buyerStackAmount);
        //不为空的buyer给他还回去
        if(AllTransactionOrders[_identifier].buyer!=address(0)){
            IERC20(EUSDTAddress).safeTransfer(AllTransactionOrders[_identifier].buyer, AllTransactionOrders[_identifier].buyerstackAmount);
        }
         //buy oder
        AllTransactionOrders[_identifier].buyer=_msgSender();
        AllTransactionOrders[_identifier].buyerstackAmount=_buyerStackAmount;
        return true;
    }
    //Seller lock , confirm transaction
    function SellLock(uint256 _identifier) public lock returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        //获得订单
         require(AllTransactionOrders[_identifier].stackAmount>0,"cancel oder");//cancel Oder
        require( AllTransactionOrders[_identifier].sellLock==false,"sell Locked");//没有锁
        require( AllTransactionOrders[_identifier].buyer!=address(0),"buyer can not empty");//得有买家
        require( AllTransactionOrders[_identifier].seller==_msgSender(),"not seller");//得是卖家
      
        //sell lock
        AllTransactionOrders[_identifier].sellLock=true;
        return true;
    }
    //Buyer lock, confirm transaction
    function BuyLock(uint256 _identifier) public lock returns (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        //获得订单
        require(AllTransactionOrders[_identifier].stackAmount>0,"cancel oder");//cancel Oder
        require( AllTransactionOrders[_identifier].sellLock==true,"sell UnLocked");//卖方锁定
        require( AllTransactionOrders[_identifier].buyLock==false,"buy Locked");//没有锁
        require( AllTransactionOrders[_identifier].buyer==_msgSender(),"not seller");//得是买家
        //sell lock
        AllTransactionOrders[_identifier].buyLock=true;
        return true;
    }
    //Seller confirms receipt of cash
    function ReceiveUSDLock(uint256 _identifier) public lock returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        //获得订单
        require(AllTransactionOrders[_identifier].stackAmount>0,"cancel oder");//cancel Oder
        require( AllTransactionOrders[_identifier].buyLock==true,"buy UnLocked");//买家锁
        require( AllTransactionOrders[_identifier].receiveUSD==false,"Received USD");//未确认收款
        require( AllTransactionOrders[_identifier].seller==_msgSender(),"not seller");//得是卖家
        //sell lock
        AllTransactionOrders[_identifier].receiveUSD=true;
        return true;
    }
    //Buyer confirms receipt of item
    function ReceiveObjectLock(uint256 _identifier) public lock returns (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        //获得订单
        require(AllTransactionOrders[_identifier].stackAmount>0,"cancel oder");//cancel Oder
        require( AllTransactionOrders[_identifier].receiveUSD==true,"Not Received USD");//确认收款
        require( AllTransactionOrders[_identifier].receiveObject==false,"Received Object");//未确认收货
        require( AllTransactionOrders[_identifier].buyer==_msgSender(),"not seller");//得是买家
        //sell lock
        AllTransactionOrders[_identifier].receiveObject=true;
        //CompleteTransaction
        uint256 sellSA=AllTransactionOrders[_identifier].stackAmount;
        uint256 buySA=AllTransactionOrders[_identifier].buyerstackAmount;
        uint256 tx_seller=sellSA.div(10000).mul(taxRate);//min  0.01%
        uint256 tx_buyer=buySA.div(10000).mul(taxRate);

        allTax=allTax.add(tx_seller.add(tx_buyer));//all tax

        IERC20(EUSDTAddress).safeTransfer(AllTransactionOrders[_identifier].seller,sellSA.sub(tx_seller));
        IERC20(EUSDTAddress).safeTransfer(AllTransactionOrders[_identifier].buyer,buySA.sub(tx_buyer));
        
        return true;
    }
    // If the seller cancels the transaction order, this function can only be executed before the buyer locks it
    function SellerCancelOrder(uint256 _identifier) public lock returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        //获得订单
        require(AllTransactionOrders[_identifier].seller!=address(0),"null oder");//空订单  
        require(AllTransactionOrders[_identifier].stackAmount>0,"cancel oder");//cancel Oder
        require(AllTransactionOrders[_identifier].buyLock==false,"buy Locked");//卖方未锁定
        require(AllTransactionOrders[_identifier].seller==_msgSender(),"not oder owner");//得是卖家
        //tax cancelOrderTax
        uint256 SellerSA=AllTransactionOrders[_identifier].stackAmount;
        uint256 BuyerSA=AllTransactionOrders[_identifier].buyerstackAmount;

        uint256 tx_cancel=SellerSA.div(10000).mul(cancelOrderTax);//min  0.01%
        IERC20(EUSDTAddress).safeTransfer(AllTransactionOrders[_identifier].seller,SellerSA.sub(tx_cancel));
        if(BuyerSA>0){
            IERC20(EUSDTAddress).safeTransfer(AllTransactionOrders[_identifier].buyer,BuyerSA);
        }
        //cancelOrder
        AllTransactionOrders[_identifier].stackAmount=0;
        AllTransactionOrders[_identifier].buyerstackAmount=0;
        return true;
    }
    //If the buyer cancels the transaction order, this function can only be executed before the buyer is locked
    function BuyerCancelOrder(uint256 _identifier) public lock returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        //获得订单
        require(AllTransactionOrders[_identifier].seller!=address(0),"null oder");//空订单  
        require(AllTransactionOrders[_identifier].buyer==_msgSender(),"not oder owner");//得是卖家
        require(AllTransactionOrders[_identifier].buyLock==false,"buy Locked");//卖方未锁定
        require(AllTransactionOrders[_identifier].buyerstackAmount>0,"cancel oder");//cancel Oder
        //tax cancelOrderTax
        uint256 SellerSA=AllTransactionOrders[_identifier].stackAmount;
        uint256 BuyerSA=AllTransactionOrders[_identifier].buyerstackAmount;

        uint256 tx_cancel=BuyerSA.div(10000).mul(cancelOrderTax);//min  0.01%
        IERC20(EUSDTAddress).safeTransfer(AllTransactionOrders[_identifier].seller,SellerSA);
        IERC20(EUSDTAddress).safeTransfer(AllTransactionOrders[_identifier].buyer,BuyerSA.sub(tx_cancel));

        //cancelOrder
        AllTransactionOrders[_identifier].stackAmount=0;
        AllTransactionOrders[_identifier].buyerstackAmount=0;
        return true;
    }


    //Administrator withdraws transaction tax income
    function withdrawTax(address _to) public onlyOwner lock returns (bool) {
        //sell lock
        require(Address.isContract(_msgSender())==false,"sender not hunman");
        require(Address.isContract(_to)==false,"to address not hunman");
        IERC20(EUSDTAddress).safeTransfer(_to,allTax);
        allTax=0;
        return true;
    }
    //Arbitration white list. This function is under discussion
    function setWhiteList(address[] memory users) public onlyOwner returns  (bool) {
        uint len=users.length;
        for(uint i=0;i<len;i++){
            WhiteList[WhiteListIndex]=users[i];
            WhiteListIndex=WhiteListIndex.add(1);
        }
        emit SetWhiteListEvent(users);
        return true;     
    }
    function getWhiteList() public view returns  (address[] memory) {
        address[] memory users=new address[](WhiteListIndex);
        for(uint i=0;i<WhiteListIndex;i++){
            users[i]=WhiteList[i];
        }
        return users;
    }
    function isInWhiteList(address user) public view returns  (bool) {
        for(uint i=0;i<WhiteListIndex;i++){
            if(WhiteList[i]==user){
                return true;
            }
        }
        return false;
    }
    //approve lock
     modifier lock(){
        require(aproveunlocked==1,"LOCKED");
        aproveunlocked=0;
        _;
        aproveunlocked=1;
    }
}