// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/*
1. The main function of this contract is to realize the 1:1 exchange between eusdt and usdt, that is, the eusdt token price is linked to usdt

2. Eusdt project party transfers eusdt token into exchange contract

3. First, the user needs to call the approve (spender, amount) of the usdt contract to authorize a certain number of usdts to the exchange contract. The spender fills in the address of the exchange contract. The amount suggests the maximum value of uint256

4. Then, the user needs to call the approve (spender, amount) of eusdt contract to authorize a certain number of eusdts to the exchange contract. Spender fills in the address of the exchange contract. The amount suggests the maximum value of uint256

The contract between the two users of exchange DT and frontaccount can be completed because of the authorization between the two users of exchange DT and frontaccount

6. The user calls the buy function of the exchange contract to complete the conversion of usdt 1:1 into eusdt

7. The user calls the sell function of the exchange contract to complete the eusdt 1:1 conversion to usdt

*8. After the exchange contract goes online, the code will be opened and the contract administrator address will be given to zero address to ensure the security and fairness of the contract


PS: usdt contract is also an erc-20 token, which inherits the function interface of erc20
*/
contract Exchange is Context,Ownable,ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address public ERC20Address;//EUSDT address
    address public USDTAddress;//USDT address

    event ExchangeBuyEvent(address user,uint amount);
    event ExchangeSellEvent(address user,uint amount);
    constructor(address _erc20address,address _usdtAddress) {
        ERC20Address=_erc20address;
        USDTAddress=_usdtAddress;
    }  
    
    function buy(uint256 amount) public nonReentrant returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        require(IERC20(ERC20Address).balanceOf(address(this))>=amount,"The number of remaining tokens in the contract is insufficient");
        require(IERC20(USDTAddress).allowance(_msgSender(),address(this))>=amount,"Insufficient number of usdt approvals");//
        IERC20(USDTAddress).safeTransferFrom(_msgSender(),address(this), amount);
        IERC20(ERC20Address).safeTransfer(_msgSender(), amount);
        emit ExchangeBuyEvent(_msgSender(),amount);
        return true;
    }
    function sell(uint256 amount) public nonReentrant returns  (bool) {
        require(Address.isContract(_msgSender())==false,"not hunman");
        require(IERC20(USDTAddress).balanceOf(address(this))>=amount,"The number of remaining tokens in the contract is insufficient");
        require(IERC20(ERC20Address).allowance(_msgSender(),address(this))>=amount,"Insufficient number of usdt approvals");//
        IERC20(ERC20Address).safeTransferFrom(_msgSender(),address(this), amount);
        IERC20(USDTAddress).safeTransfer(_msgSender(), amount);
        emit ExchangeSellEvent(_msgSender(),amount);
        return true;
    }
    
}