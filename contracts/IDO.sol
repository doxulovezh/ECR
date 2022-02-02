// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//  abstract contract  MyMBT {
//     function balanceOf(address _addMinter) public view virtual returns (uint256);
// }

contract IDOContract is Context,Ownable,ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address public ERC20Address;//ANK address
    address public USDTAddress;//USDT address
    uint256 private aproveunlocked=1;//lock
    uint256 public price;//price 1000=10usdt 100=1usdt  10=0.1usdt   1=0.01usdt
    uint256 private MAXAmount=10000000*10**18;//MAX buy amount < 1000w
    bool public IDOActive=false;//
    mapping(uint=>address) private WhiteList;
    uint256 public WhiteListIndex=0;
    event SetWhiteListEvent(address[] users);
    event IDOBuyEvent(address user,uint amount);
    constructor(uint256 _price,address _erc20address,address _usdtAddress) {
        price = _price;
        ERC20Address=_erc20address;
        USDTAddress=_usdtAddress;
    }  
    
    function buy(uint256 amount) public nonReentrant returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        require(IDOActive,"IDO not Active");
        require(amount>=1000000000000000000&&amount<MAXAmount,"Buy Amount out of range must be more than 1 less than MAXAmount");
        require(IERC20(ERC20Address).balanceOf(address(this))>=amount,"The number of remaining tokens in the contract is insufficient");
        require(IERC20(USDTAddress).allowance(_msgSender(),address(this))>=amount.mul(price).div(100),"Insufficient number of usdt approvals");//
        IERC20(USDTAddress).safeTransferFrom(_msgSender(),address(this), amount.mul(price).div(100));
        IERC20(ERC20Address).safeTransfer(_msgSender(), amount);
        emit IDOBuyEvent(_msgSender(),amount);
        return true;
    }
    
    function setWhiteList(address[] memory users) public onlyOwner returns  (bool) {
        uint len=users.length;
        for(uint i=0;i<len;i++){
            WhiteList[WhiteListIndex]=users[i];
            WhiteListIndex=WhiteListIndex.add(1);
        }
        emit SetWhiteListEvent(users);
        return true;
        
    }

    function setIDOActive(bool val) public onlyOwner returns  (bool) {
        IDOActive=val;
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
     modifier approvelock(){
        require(aproveunlocked==1,"LOCKED");
        aproveunlocked=0;
        _;
        aproveunlocked=1;
    }
}