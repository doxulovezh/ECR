// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//  abstract contract  MyMBT {
//     function balanceOf(address _addMinter) public view virtual returns (uint256);
// }

contract IDOStackContract is Context,Ownable,ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address public ERC20Address;//ANK address
    address public USDTAddress;//USDT address
    uint256 private aproveunlocked=1;//lock
    uint256 public price;//price
    uint256 public stackTime;//time
    uint256 private MAXAmount=10000000*10**18;//MAX buy amount < 1000w
    bool public IDOActive=false;//
    mapping (address => uint) private balances;
    mapping (address => uint) private purchaseDate;
    event IDOBuyEvent(address user,uint amount);
    event DonateEvent(address user,uint amount);
    constructor(uint256 _price,uint256 _stackTime,address _erc20address,address _usdtAddress) {
        price = _price;
        ERC20Address=_erc20address;
        USDTAddress=_usdtAddress;
        stackTime=_stackTime;
    }  
    

    function donate(uint256 donateamount) public nonReentrant returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        require(donateamount>=1000000000000000000&&donateamount<200000000000000000000000000,"donate Amount out of range");
        require(IERC20(ERC20Address).allowance(_msgSender(),address(this))>=donateamount,"Insufficient number of token approvals");//
        IERC20(ERC20Address).safeTransferFrom(_msgSender(),address(this), donateamount);
        balances[address(this)]=balances[address(this)].add(donateamount);
        DonateEvent(_msgSender(),donateamount);
        return true;
    }

    function buy(uint256 amount) public nonReentrant returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        require(IDOActive,"IDO not Active");
        require(amount>=1000000000000000000&&amount<MAXAmount,"Buy Amount out of range must be more than 1");
        require(balances[address(this)]>=amount,"The number of remaining tokens in the contract is insufficient");
        require(IERC20(USDTAddress).allowance(_msgSender(),address(this))>=amount.mul(price),"Insufficient number of usdt approvals");//
        IERC20(USDTAddress).safeTransferFrom(_msgSender(),address(this), amount.mul(price));
        balances[_msgSender()]=balances[_msgSender()].add(amount);
        balances[address(this)]=balances[address(this)].sub(amount);
        if(purchaseDate[_msgSender()]==0){
            purchaseDate[_msgSender()]=block.timestamp;
        }
        IDOBuyEvent(_msgSender(),amount);
        return true;
    }
    //
    function withdraw () public nonReentrant returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        require(purchaseDate[_msgSender()]<block.timestamp,"purchaseDate must < now time");
        uint256 withdrawAmount=0;
        if(block.timestamp.sub(purchaseDate[_msgSender()])<stackTime){
            withdrawAmount=balances[_msgSender()].div(stackTime).mul(block.timestamp.sub(purchaseDate[_msgSender()]));
        }else{
            withdrawAmount=balances[_msgSender()];
        }
        balances[_msgSender()]=balances[_msgSender()].sub(withdrawAmount);
        IERC20(ERC20Address).safeTransfer(_msgSender(), withdrawAmount);
        return true;
    }

    function withdrawView () public view returns  (uint) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        require(purchaseDate[_msgSender()]<block.timestamp,"purchaseDate must < now time");
        uint256 withdrawAmount=0;
        if(block.timestamp.sub(purchaseDate[_msgSender()])<stackTime){
            withdrawAmount=balances[_msgSender()].div(stackTime).mul(block.timestamp.sub(purchaseDate[_msgSender()]));
        }else{
            withdrawAmount=balances[_msgSender()];
        }
        return withdrawAmount;
    }
    
    function balanceOf(address tokenOwner) public view returns(uint balance){
        return balances[tokenOwner];
    }
    function purchaseDateOf(address tokenOwner) public view returns(uint balance){
        return purchaseDate[tokenOwner];
    }


    function setIDOActive(bool val) public onlyOwner returns  (bool) {
        IDOActive=val;
        return true;
        
    }

    //approve lock
     modifier approvelock(){
        require(aproveunlocked==1,"LOCKED");
        aproveunlocked=0;
        _;
        aproveunlocked=1;
    }
}