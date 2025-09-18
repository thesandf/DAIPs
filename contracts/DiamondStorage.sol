// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title DiamondStorage
 * @dev Library for Diamond storage slot and structs (EIP-2535). Used by all facets for upgrade-safe storage.
 */
library DiamondStorage {
    bytes32 internal constant STORAGE_SLOT = keccak256("diamond.standard.diamond.storage");

    enum Category { General, Treasury, Upgrade }

    struct Proposal {
        address proposer;
        address target;
        uint256 value;
        bytes data;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        uint256 expiration;
        Category category;
        string descriptionHash;
    }

    struct VestingSchedule {
        uint256 start;
        uint256 cliff;
        uint256 duration;
        uint256 amount;
        uint256 released;
        bool revocable;
        bool revoked;
    }

    struct Layout {
        string name;
        string symbol;
        uint256 totalSupply;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        // Role-based access control
        mapping(bytes32 => mapping(address => bool)) roles;
        mapping(bytes32 => bytes32) roleAdmins;
        // ReentrancyGuard
        bool _entered;
        // Governance
        uint256 proposalCount;
        mapping(address => address) delegates;
        mapping(address => uint256) votingPower;
        mapping(uint256 => Proposal) proposals;
        mapping(uint256 => uint256) queuedAt;
        mapping(uint256 => mapping(address => bool)) hasVoted;
        mapping(address => VestingSchedule) vestings;
        mapping(address => uint256) lockupEnd;
    }

    // Role constants
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 internal constant LOCKER_ROLE = keccak256("LOCKER_ROLE");
    bytes32 internal constant VESTER_ROLE = keccak256("VESTER_ROLE");

    function layout() internal pure returns (Layout storage ds) {
        bytes32 position = STORAGE_SLOT;
        assembly {
            ds.slot := position
        }
    }
    function getRoleAdmin(bytes32 role) internal view returns (bytes32) {
        return layout().roleAdmins[role];
    }
}
