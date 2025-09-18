// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Lib} from "../libraries/ERC20Lib.sol";
import {DiamondStorage} from "./DiamondStorage.sol";

contract ERC20Facet {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external view returns (string memory) {
        return DiamondStorage.layout().name;
    }

    function symbol() external view returns (string memory) {
        return DiamondStorage.layout().symbol;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function totalSupply() external view returns (uint256) {
        return DiamondStorage.layout().totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return DiamondStorage.layout().balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return DiamondStorage.layout().allowances[owner][spender];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        ERC20Lib.transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        ERC20Lib.approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        ERC20Lib.spendAllowance(from, msg.sender, amount);
        ERC20Lib.transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external {
        ERC20Lib.mint(to, amount);
    }

    function burn(address from, uint256 amount) external {
        ERC20Lib.burn(from, amount);
    }
}
