// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @title SafeERC20Lib
/// @notice Safe wrapper for external ERC-20 interactions in Diamond-compatible contracts.
library SafeERC20Lib {
    error SafeERC20FailedTransfer(address token, address to, uint256 amount);
    error SafeERC20FailedTransferFrom(address token, address from, address to, uint256 amount);
    error SafeERC20FailedApprove(address token, address spender, uint256 amount);

    function safeTransfer(address token, address to, uint256 amount) internal {
        bool success = IERC20Minimal(token).transfer(to, amount);
        if (!success) revert SafeERC20FailedTransfer(token, to, amount);
    }

    function safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bool success = IERC20Minimal(token).transferFrom(from, to, amount);
        if (!success) revert SafeERC20FailedTransferFrom(token, from, to, amount);
    }

    function safeApprove(address token, address spender, uint256 amount) internal {
        bool success = IERC20Minimal(token).approve(spender, amount);
        if (!success) revert SafeERC20FailedApprove(token, spender, amount);
    }
}
