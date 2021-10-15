// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelinUpgrade/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelinUpgrade/contracts/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelinUpgrade/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelinUpgrade/contracts/math/SafeMathUpgradeable.sol";

import '../../interfaces/IErc20Interface.sol';
import '../../interfaces/ICTokenInterface.sol';
import '../interfaces/ISafeBox.sol';

// Safebox vault, deposit, withdrawal, borrowing, repayment
contract SafeBoxYexCTokenImpl is ERC20Upgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IErc20Interface public eToken;
    ICTokenInterface public cToken;

    function __SafeBoxYexCTokenImpl__init(address _cToken) public initializer {
        __ERC20_init(string(abi.encodePacked("y ", ERC20Upgradeable(IErc20Interface(_cToken).underlying()).name())),
            string(abi.encodePacked("y", ERC20Upgradeable(IErc20Interface(_cToken).underlying()).symbol())));
        _setupDecimals(ERC20Upgradeable(_cToken).decimals());
        eToken = IErc20Interface(_cToken);
        cToken = ICTokenInterface(_cToken);
        require(cToken.isCToken(), 'not ctoken address');
        IERC20Upgradeable(baseToken()).approve(_cToken, uint256(-1));
    }

    function baseToken() public virtual view returns (address) {
        return eToken.underlying();
    }

    function ctokenSupplyRatePerBlock() public virtual view returns (uint256) {
        return cToken.supplyRatePerBlock();
    }

    function ctokenBorrowRatePerBlock() public virtual view returns (uint256) {
        return cToken.borrowRatePerBlock();
    }

    function call_balanceOf(address _token, address _account) public virtual view returns (uint256 balance) {
        balance = IERC20Upgradeable(_token).balanceOf(_account);
    }
    
    function call_balanceOfCToken_this() public virtual view returns (uint256 balance) {
        balance = call_balanceOf(address(cToken), address(this));
    }    
    
    function call_balanceOfBaseToken_this() public virtual returns (uint256) {
        return call_balanceOfCToken_this().mul(cToken.exchangeRateCurrent()).div(1e18);
    }

    function call_borrowBalanceCurrent_this() public virtual returns (uint256) {
        return cToken.borrowBalanceCurrent(address(this));
    }

    function getBaseTokenPerCToken() public virtual view returns (uint256) {
        return cToken.exchangeRateStored();
    }

    // deposit
    function ctokenDeposit(uint256 _value) internal virtual returns (uint256 lpAmount) {
        uint256 cBalanceBefore = call_balanceOf(address(cToken), address(this));
        require(eToken.mint(uint256(_value)) == 0, 'deposit token error');
        uint256 cBalanceAfter = call_balanceOf(address(cToken), address(this));
        lpAmount = cBalanceAfter.sub(cBalanceBefore);
    }
    
    function ctokenWithdraw(uint256 _lpAmount) internal virtual returns (uint256 value) {
        uint256 cBalanceBefore = call_balanceOf(baseToken(), address(this));
        require(eToken.redeem(_lpAmount) == 0, 'withdraw supply ctoken error');
        uint256 cBalanceAfter = call_balanceOf(baseToken(), address(this));
        value = cBalanceAfter.sub(cBalanceBefore);
    }

    function ctokenClaim(uint256 _lpAmount) internal virtual returns (uint256 value) {
        value = ctokenWithdraw(_lpAmount);
    }

    function ctokenBorrow(uint256 _value) internal virtual returns (uint256 value) {
        uint256 cBalanceBefore = call_balanceOf(baseToken(), address(this));
        require(eToken.borrow(_value) == 0, 'borrow ubalance error');
        uint256 cBalanceAfter = call_balanceOf(baseToken(), address(this));
        value = cBalanceAfter.sub(cBalanceBefore);
    }

    function ctokenRepayBorrow(uint256 _value) internal virtual {
        require(eToken.repayBorrow(_value) == 0, 'repayBorrow ubalance error');
    }
}
