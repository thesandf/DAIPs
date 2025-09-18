// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondStorage} from "./DiamondStorage.sol";
import {LibErrors} from "./LibErrors.sol";
 
library AccessControlLib {
    using DiamondStorage for DiamondStorage.Layout;

    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function _hasRole(bytes32 role, address account) internal view returns (bool) {
        return DiamondStorage.layout().roles[role][account];
    }

    function checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert LibErrors.Unauthorized(account, role);
        }
    }

    function grantRole(bytes32 role, address account, address sender) internal {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        checkRole(ds.getRoleAdmin(role), sender);

        if (!ds.roles[role][account]) {
            ds.roles[role][account] = true;
            emit RoleGranted(role, account, sender);
        }
    }

    function revokeRole(bytes32 role, address account, address sender) internal {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        checkRole(ds.getRoleAdmin(role), sender);

        if (ds.roles[role][account]) {
            ds.roles[role][account] = false;
            emit RoleRevoked(role, account, sender);
        }
    }

    function renounceRole(bytes32 role, address caller) internal {
        DiamondStorage.Layout storage ds = DiamondStorage.layout();
        if (!ds.roles[role][caller]) revert LibErrors.InvalidConfirmation();

        ds.roles[role][caller] = false;
        emit RoleRevoked(role, caller, caller);
    }
}
