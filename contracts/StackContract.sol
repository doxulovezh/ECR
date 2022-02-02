// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "./SafeControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

//  abstract contract  MyMBT {
//     function balanceOf(address _addMinter) public view virtual returns (uint256);
// }

contract StackContract is Context,SafeControl,Ownable,ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address public myERC20Addr;//MBT address
    // MyMBT private myerc20=MyMBT(myERC20Addr);
    uint256 private aproveunlocked=1;//领取锁，防止重放攻击

    mapping(address => uint256) public allocPoint;//账户--算力
    mapping(address => uint256) public lastRewardBlock;//上次结算时区块
    uint256 public rewardTokenPerBlock;//每个区块的奖励
    event Repevent(address user,uint point,uint reword);
    constructor(uint256 _rewardTokenPerBlock,address _erc20address) {
        rewardTokenPerBlock = _rewardTokenPerBlock;//定义每个区块的token奖励
        myERC20Addr=_erc20address;
    }  
   /*...
    stack  
    stack your token
    */
    function stack(uint256 stackamount) public approvelock returns (bool) {
        require(Address.isContract(_msgSender())==false,"not human");//not hunman
        require(_msgSender()!=address(0),"Zero Address");//
        require(stackamount>=1*10**18,"pledge amount less 1 token");//
        require(IERC20(myERC20Addr).allowance(_msgSender(),address(this))>=stackamount,"approve amount less pledge amount");//
        IERC20(myERC20Addr).safeTransferFrom(_msgSender(),address(this), stackamount);
        uint256 reptmp=reapView(_msgSender());
        lastRewardBlock[_msgSender()]=block.number;
        uint256 nowPointTemp=allocPoint[_msgSender()];
        allocPoint[_msgSender()]=nowPointTemp.add(stackamount).add(reptmp);
        return true;
    }
    /*...
    函数名：computationalPowerOf 
    单个查询 addr地址  算力
    返回值：可领取MBT的数量
    */
    function computationalPowerOf(address addr) public view returns (uint256) {
        return allocPoint[addr];
    }
    /*...
    函数名：computationalPowerOfBatch
    批量查询 addrs 中每个地址  算力
    返回值：可领取MBT的数量的数组
    */
    function computationalPowerOfBatch(address[] memory addrs) public view returns (uint256[] memory) {
        uint len=addrs.length;
        uint256[] memory res=new uint256[](len);
        for(uint i=0;i<len;i++){
            res[i]=allocPoint[addrs[i]];
        }
        return res;
    }
    //计算个人区块总奖励
    function getRewardStack(address addr) public view returns (uint256) {
        if(lastRewardBlock[addr]>=block.number){
             return 0;
        }
       return block.number.sub(lastRewardBlock[addr]).mul(rewardTokenPerBlock);//当前区块-上次更新时的区快数   x    每个区块的奖励 = 区块数总奖励
    }

    /*...
    函数名：reap  
    MBT领取 函数调用者msg.sender 更具 算力与经历的区块数量 计算收益,领取后msg.sender账户算力 归零
    */
    function reap() public nonReentrant returns (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");//not hunman
        if(allocPoint[_msgSender()]<=0){//算力0返回
            return false;
        }
        if (block.number <= lastRewardBlock[_msgSender()]) {//领取收益当时的blockNumber > 上一次领取时的blockNumber
            return false;
        }
        uint256 blockReward = getRewardStack(_msgSender());//计算 累计区块 奖励
        if (blockReward <= 0) {
            return false;
        }
        uint256 allpointTemp=allocPoint[_msgSender()];
        uint256 tokenReward = allpointTemp.div(10**18).mul(blockReward);//更具 时间*stack 数量
        allocPoint[_msgSender()]=0;//用户算力归零  下次更新算力前不能再收获了
        IERC20(myERC20Addr).safeTransfer(_msgSender(), tokenReward.add(allpointTemp));
        Repevent(_msgSender(),allpointTemp,tokenReward);
        return true;
    }
    
    /*...
    函数名：reapView  
    MBT领取预查看 函数调用者msg.sender 更具 算力与经历的区块数量 计算收益
    */
    function reapView(address addr) public view returns (uint256) {
      require(Address.isContract(addr)==false,"not hunman");//not hunman
      require(addr!=address(0),"Zero Address");//
        if(allocPoint[addr]<=0){//算力0返回
            return 0;
        }
        if (block.number <= lastRewardBlock[addr]) {//领取收益当时的blockNumber > 上一次领取时的blockNumber
            return 0;
        }
        uint256 blockReward = getRewardStack(addr);//计算 累计区块 奖励
        if (blockReward <= 0) {
            return 0;
        }
        uint256 allpointTemp=allocPoint[addr];
        uint256 tokenReward = allpointTemp.div(10**18).mul(blockReward);//更具 时间*stack 数量
        return tokenReward;
    }

    function balanceOfBatch(address[] memory addrs) public view returns (uint256[] memory) {
        uint256 len=addrs.length;
        uint256[] memory amounts=new uint256[](len);
        for(uint i=0;i<len;i++){
            amounts[i]=IERC20(myERC20Addr).balanceOf(addrs[i]);//myerc20.balanceOf(addrs[i]);
        }
        return amounts;
    }
    
    //approve 锁，防止重放攻击
     modifier approvelock(){
        require(aproveunlocked==1,"LOCKED");
        aproveunlocked=0;
        _;
        aproveunlocked=1;
    }
}