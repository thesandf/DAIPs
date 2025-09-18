// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DiamondStorage} from "./DiamondStorage.sol";
import {LibErrors} from "./LibErrors.sol";

library ERC20Lib {
    using DiamondStorage for DiamondStorage.Layout;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyRole(bytes32 role) {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        if (!ds.roles[role][msg.sender]) {
            revert LibErrors.OwnableInvalidOwner(msg.sender);
        }
        _;
    }

    function initialize(string memory name_, string memory symbol_, address admin) internal {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        ds.name = name_;
        ds.symbol = symbol_;

        // Assign default roles to deployer
        ds.roles[DiamondStorage.DEFAULT_ADMIN_ROLE][admin] = true;
        ds.roles[DiamondStorage.ADMIN_ROLE][admin] = true;
        ds.roles[DiamondStorage.MINTER_ROLE][admin] = true;
        ds.roles[DiamondStorage.LOCKER_ROLE][admin] = true;
        ds.roles[DiamondStorage.VESTER_ROLE][admin] = true;
    }

    function grantRole(bytes32 role, address account) internal onlyRole(DiamondStorage.ADMIN_ROLE) {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        ds.roles[role][account] = true;
    }

    function revokeRole(bytes32 role, address account) internal onlyRole(DiamondStorage.ADMIN_ROLE) {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        ds.roles[role][account] = false;
    }

    function mint(address to, uint256 amount) internal onlyRole(DiamondStorage.MINTER_ROLE) {
        if (to == address(0)) revert LibErrors.InvalidReceiver(to);

        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        ds.totalSupply += amount;
        ds.balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) internal onlyRole(DiamondStorage.MINTER_ROLE) {
        if (from == address(0)) revert LibErrors.InvalidSender(from);

        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        uint256 fromBalance = ds.balances[from];
        if (fromBalance < amount) revert LibErrors.InsufficientBalance(from, fromBalance, amount);

        unchecked {
            ds.balances[from] = fromBalance - amount;
            ds.totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }

    function transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert LibErrors.InvalidSender(from);
        if (to == address(0)) revert LibErrors.InvalidReceiver(to);

        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        uint256 fromBalance = ds.balances[from];
        if (fromBalance < amount) revert LibErrors.InsufficientBalance(from, fromBalance, amount);

        unchecked {
            ds.balances[from] = fromBalance - amount;
            ds.balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0)) revert LibErrors.InvalidApprover(owner);
        if (spender == address(0)) revert LibErrors.InvalidSpender(spender);

        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        ds.allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function spendAllowance(address owner, address spender, uint256 amount) internal {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        uint256 currentAllowance = ds.allowances[owner][spender];

        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert LibErrors.InsufficientAllowance(spender, currentAllowance, amount);
            }
            unchecked {
                ds.allowances[owner][spender] = currentAllowance - amount;
            }
        }
    }

}
