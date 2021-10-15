// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

// import "@openzeppelinBase/contracts/math/SafeMath.sol";
import "@openzeppelinBase/contracts/token/ERC20/ERC20Pausable.sol";

contract mockToken is ERC20Pausable {
    // using SafeMath for uint256;

    constructor(string memory _symbol)
        public ERC20(_symbol, _symbol) {
    }

    function mint(uint value) external {
        _mint(msg.sender, value);
    }
    
    function burn(address _acct, uint value) external {
        _burn(_acct, value);
    }
}
