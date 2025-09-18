// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";

contract AttackerCantract {
    fallback() external payable {
        revert("Attack revert");
    }
}

contract GovernanceTokenTest is Test {
    GovernanceToken token;
    AttackerCantract Attacker_Cantract;

    address admin = makeAddr("admin");
    address minter = makeAddr("minter");
    address locker = makeAddr("locker");
    address vester = makeAddr("vester");
    address user = makeAddr("user");
    address delegate = makeAddr("delegate");
    address attacker = makeAddr("attacker");

    uint256 amount = 1_00 ether;
    uint256 start = block.timestamp;
    uint256 cliff = 7 days;
    uint256 duration = 30 days;

    address target = admin;
    uint256 value = 0;
    bytes data = "";
    GovernanceToken.Category General = GovernanceToken.Category.General;
    GovernanceToken.Category Upgrade = GovernanceToken.Category.Upgrade;
    string descriptionHash = "ipfs://proposal";

    uint256 public constant EXECUTION_DELAY = 1 days;
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18; // or 10 ** decimals()

    event ProposalAutoExecutionFailed(uint256 indexed proposalId, string reason);
    event UpgradeExecutionBlocked(uint256 proposalId);

    // ========== Errors ==========
    error NotAdmin();
    error TokensLockedError(uint256 unlockTime);
    error InsufficientBalance(uint256 available, uint256 required);
    error ProposalNotExists(uint256 proposalId);
    error ProposalExpired(uint256 current, uint256 expiration);
    error AlreadyExecuted(uint256 proposalId);
    error NoVotingPower(address voter);
    error AlreadyVoted();
    error ProposalDidNotPass(uint256 votesFor, uint256 votesAgainst);
    error ExecutionFailed();
    error ProposalAutoExecutionFailedForUpgradeProposal(uint256 proposalId);
    error OnlySelfCallAllowed();
    error NoVestingSchedule();
    error ZeroAmount();
    error ZeroDuration();
    error InvalidCliffDuration(uint256 duration, uint256 cliff);
    error TimelockNotExpired(uint256 current, uint256 required);
    error AlreadyVesting(address beneficiary);
    error NotRevocable();
    error Error__VestingRevoked();
    error NoTokensToRelease();
    error NotEnoughVotes(uint256 total, uint256 required);
    error NotAuthorizedToCancelThisProposal(address caller);

    function setUp() public {
        start = block.timestamp;
        vm.startPrank(admin);
        token = new GovernanceToken();
        vm.stopPrank();

        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), minter);
        token.grantRole(token.LOCKER_ROLE(), locker);
        token.grantRole(token.VESTER_ROLE(), vester);
        token.grantRole(token.ADMIN_ROLE(), admin);
        vm.stopPrank();

        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin), "admin does not have DEFAULT_ADMIN_ROLE");

        vm.prank(attacker);
        Attacker_Cantract = new AttackerCantract();
    }

    function test_MintTokensSuccess() public {
        vm.prank(minter);
        token.mintTokens(user, amount);
        assertEq(token.balanceOf(user), amount);
    }

    function test_MintTokensNotMinterReverts() public {
        vm.expectRevert();
        vm.prank(attacker);
        token.mintTokens(attacker, amount);
    }

    function test_MintTokensVotingToSelfByDefault() external {
        vm.prank(minter);
        token.mintTokens(user, amount);

        assertEq(token.balanceOf(user), amount);
        assertEq(token.getVotes(user), amount);
    }

    function test_MintTokensVotingToDelegatee() external {
        vm.startPrank(user);
        token.delegateVotingPower(delegate);
        vm.stopPrank();

        vm.prank(minter);
        token.mintTokens(user, amount);

        assertEq(token.balanceOf(user), amount);
        assertEq(token.getVotes(delegate), amount);
        assertEq(token.getVotes(user), 0);
    }

    function test_MintMultipleTimesAccumulates() external {
        vm.prank(minter);
        token.mintTokens(user, 40 ether);

        vm.prank(minter);
        token.mintTokens(user, 60 ether);

        assertEq(token.balanceOf(user), amount);
        assertEq(token.getVotes(user), amount);
    }

    function test_CannotTransferWhileLocked() public {
        vm.prank(minter);
        token.mintTokens(user, amount);

        vm.prank(locker);
        token.lockTokens(user, 2 days);

        vm.expectRevert(abi.encodeWithSelector(TokensLockedError.selector, token.lockupEnd(user)));
        vm.prank(user);
        token.transfer(admin, amount);
    }

    function test_TransferAfterLockExpires() public {
        vm.prank(minter);
        token.mintTokens(user, amount);

        vm.prank(locker);
        token.lockTokens(user, 1 days);

        vm.warp(block.timestamp + 2 days); // after lock
        vm.prank(user);
        token.transfer(admin, amount); // should succeed
        assertEq(token.balanceOf(admin), amount + INITIAL_SUPPLY);
    }

    function test_TransferInsufficientBalanceError() public {
        vm.prank(minter);
        token.mintTokens(user, amount);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(InsufficientBalance.selector, amount, amount + amount));
        token.transfer(admin, amount + amount);
    }

    function test_ProposalLifecycle() public {
        vm.prank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        vm.prank(admin);
        token.voteOnProposal(pid, true);

        // vote without voting power
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(NoVotingPower.selector, attacker));
        token.voteOnProposal(pid, false);

        vm.warp(block.timestamp + 8 days);
        vm.prank(admin);
        token.executeProposal(pid);

        vm.warp(block.timestamp + 1 days);
        vm.prank(admin);
        token.executeProposal(pid);

        vm.prank(minter);
        token.mintTokens(user, amount);

        vm.expectRevert(abi.encodeWithSelector(AlreadyExecuted.selector, pid));
        vm.prank(user);
        token.voteOnProposal(pid, true);

        (,,,,,, bool executed,,,) = token.proposals(pid);
        console.log(executed);
        assertTrue(executed);
    }

    function test_RevertIfNotAdminExecutesProposal() public {
        vm.startPrank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);
        token.voteOnProposal(pid, true);
        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NotAdmin.selector));
        token.executeProposal(pid);
    }

    function test_UpgradeExecutedOnlyByAdmin_UpgradeSucceedsWithEnoughVotes() public {
        vm.startPrank(admin); // admin have full voting power
        uint256 pid = token.createProposal(admin, value, data, Upgrade, descriptionHash);
        token.voteOnProposal(pid, true);
        vm.stopPrank();

        // Simulate expiration and execution delay
        vm.warp(block.timestamp + 8 days);
        token.setQueuedAt(pid, block.timestamp - 1 days);

        // Call manual execution as admin @dev you can also use _safeExecute to avoid Logs.
        vm.prank(admin);
        vm.recordLogs();
        token.executeProposal(pid);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("ProposalExecuted(uint256)")) {
                found = true;
                break;
            }
        }

        assertTrue(found, "Missing ProposalExecuted event");
        (,,,,,, bool executed,,,) = token.proposals(pid);
        assertTrue(executed, "Proposal should be marked as executed");
    }

    function test_UpgradeFailsWithout20PercentVotes() public {
        vm.prank(user);
        uint256 pid = token.createProposal(admin, value, data, Upgrade, descriptionHash);

        // Transfer voting power (10% of total supply)
        vm.prank(admin);
        token.transfer(user, 100_000 ether);

        vm.prank(user);
        token.voteOnProposal(pid, true);

        vm.warp(block.timestamp + 8 days);
        token.setQueuedAt(pid, block.timestamp - 2 days);

        (,,,, uint256 votesFor, uint256 votesAgainst,,,,) = token.proposals(pid);
        uint256 totalVotes = votesFor + votesAgainst;
        uint256 requiredVotes = (token.totalSupply() * token.getQuorumPercentage(Upgrade)) / 100;

        vm.expectRevert(abi.encodeWithSelector(NotEnoughVotes.selector, totalVotes, requiredVotes));

        // Direct call to _safeExecute to bypass try/catch
        vm.prank(address(token)); // because _safeExecute requires msg.sender == address(this)
        token._safeExecute(pid);
    }

    function test_GeneralFailsWithout5PercentVotes() public {
        vm.prank(user);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        // Transfer voting power (4% of total supply)
        vm.prank(admin);
        token.transfer(user, 400_00 ether);

        vm.prank(user);
        token.voteOnProposal(pid, true);

        vm.warp(block.timestamp + 8 days);
        token.setQueuedAt(pid, block.timestamp - 2 days);

        (,,,, uint256 votesFor, uint256 votesAgainst,,,,) = token.proposals(pid);
        uint256 totalVotes = votesFor + votesAgainst;
        uint256 requiredVotes = (token.totalSupply() * token.getQuorumPercentage(General)) / 100;

        vm.expectRevert(abi.encodeWithSelector(NotEnoughVotes.selector, totalVotes, requiredVotes));

        vm.prank(address(token)); // required for internal call context
        token._safeExecute(pid);
    }

    function test_ExecuteFailsIfUpgradeProposalCalledByNotAdmin() public {
        vm.startPrank(admin);
        uint256 pid = token.createProposal(admin, value, data, Upgrade, descriptionHash);
        token.voteOnProposal(pid, true);
        vm.stopPrank();

        // Time passed and queuedAt set
        vm.warp(block.timestamp + 9 days);
        token.setQueuedAt(pid, block.timestamp - 1 days);

        // Expect revert
        vm.expectRevert(abi.encodeWithSelector(ProposalAutoExecutionFailedForUpgradeProposal.selector, pid));

        vm.prank(address(token)); // Needed for _safeExecute's internal check
        token._safeExecute(pid);
    }

    function test_AutoExecuteSkipsUpgradeButExecutesGeneral() public {
        // Upgrade proposal
        vm.startPrank(admin);
        uint256 upgradeId = token.createProposal(admin, value, data, Upgrade, descriptionHash);
        token.voteOnProposal(upgradeId, true);
        vm.stopPrank();

        // General proposal
        vm.startPrank(admin);
        uint256 generalId = token.createProposal(admin, value, data, General, descriptionHash);
        token.voteOnProposal(generalId, true);
        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);
        token.setQueuedAt(upgradeId, block.timestamp - 1 days);
        token.setQueuedAt(generalId, block.timestamp - 1 days);

        vm.prank(user); // Non-admin caller
        vm.recordLogs();
        token.autoExecuteProposals();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool upgradeFailed;
        bool generalExecuted;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("ProposalExecuted(uint256)")) {
                uint256 executedId = uint256(logs[i].topics[1]);
                if (executedId == generalId) generalExecuted = true;
            }
            if (logs[i].topics[0] == keccak256("UpgradeExecutionBlocked(uint256)")) {
                upgradeFailed = true;
            }
        }

        assertTrue(upgradeFailed, "Upgrade should be blocked");
        assertTrue(generalExecuted, "General proposal should execute");
    }

    function test_ProposalVotingFailsForDoubleVote() public {
        vm.startPrank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);
        token.voteOnProposal(pid, true);
        vm.expectRevert(abi.encodeWithSelector(AlreadyVoted.selector));
        token.voteOnProposal(pid, false);
        vm.stopPrank();
    }

    function test_ProposalExecutionFails() public {
        vm.prank(admin);
        uint256 pid = token.createProposal(address(Attacker_Cantract), value, data, General, descriptionHash);

        vm.prank(admin);
        token.voteOnProposal(pid, true);

        vm.warp(block.timestamp + 8 days);
        vm.prank(admin);
        token.executeProposal(pid);

        vm.warp(block.timestamp + 1 days);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ExecutionFailed.selector));
        token.executeProposal(pid);
    }

    function test_CancelProposalSuccessfullyByProposerAndRevertIfNotAdminOrProposer() public {
        vm.prank(user);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        vm.prank(admin);
        token.voteOnProposal(pid, true);

        vm.warp(block.timestamp + 8 days);

        //test if not proposer or only
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(NotAuthorizedToCancelThisProposal.selector, attacker));
        token.cancelProposal(pid);

        // Record logs for event check
        vm.prank(user);
        vm.recordLogs();
        token.cancelProposal(pid);

        (,,,,,, bool executed,,,) = token.proposals(pid);
        assertTrue(executed, "Proposal should be marked as executed");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found = false;

        bytes32 expectedEventSig = keccak256("ProposalCancelled(uint256)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics.length == 2 && logs[i].topics[0] == expectedEventSig && uint256(logs[i].topics[1]) == pid
            ) {
                found = true;
                break;
            }
        }

        assertTrue(found, "Missing ProposalCancelled event");
    }

    function test_CancelProposalRevertsIfAlreadyExecuted() public {
        vm.startPrank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);
        token.voteOnProposal(pid, true);
        vm.stopPrank();

        // Simulate execution
        vm.warp(block.timestamp + 8 days);
        token.setQueuedAt(pid, block.timestamp - 2 days); // skip delay
        vm.prank(admin);
        token.executeProposal(pid);

        // Try cancelling executed proposal
        vm.expectRevert(abi.encodeWithSelector(AlreadyExecuted.selector, pid));
        vm.prank(admin);
        token.cancelProposal(pid);
    }

    function test_CancelProposalFailsIfNotAdminOrProposer() public {
        vm.startPrank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);
        vm.stopPrank();

        // Try canceling from non-admin
        vm.expectRevert(abi.encodeWithSelector(NotAuthorizedToCancelThisProposal.selector, user));
        vm.prank(user);
        token.cancelProposal(pid);
    }

    function test_ProposalExecutionBeforeEndFails() public {
        vm.prank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        vm.prank(admin);
        token.voteOnProposal(pid, true);

        vm.prank(admin);
        token.executeProposal(pid);

        assertFalse(token.getProposal(pid).executed);
    }

    function test_CannotExecuteProposalBeforeDelay() public {
        vm.prank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        vm.prank(admin);
        token.voteOnProposal(pid, true);

        vm.prank(admin);
        token.executeProposal(pid);

        uint256 queuedat = token.queuedAt(pid);
        uint256 requiredTime = queuedat + EXECUTION_DELAY;
        uint256 currentTime = block.timestamp;
        vm.expectRevert(abi.encodeWithSelector(TimelockNotExpired.selector, currentTime, requiredTime));
        vm.prank(admin);
        token.executeProposal(pid);
    }

    function test_ProposalExecutionFailsIfAlreadyExecuted() public {
        vm.startPrank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        token.voteOnProposal(pid, true);

        token.executeProposal(pid);

        vm.warp(block.timestamp + 2 days);

        token.executeProposal(pid);

        vm.expectRevert(abi.encodeWithSelector(AlreadyExecuted.selector, pid));
        token.executeProposal(pid);
        vm.stopPrank();
    }

    function test_ProposalDidNotPass() public {
        vm.prank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        vm.prank(minter);
        token.mintTokens(attacker, amount);

        vm.prank(attacker);
        token.voteOnProposal(pid, false);

        vm.prank(minter);
        token.mintTokens(user, 10);

        vm.prank(user);
        token.voteOnProposal(pid, true);

        (,,,, uint256 votesFor, uint256 votesAgainst,,,,) = token.proposals(pid);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ProposalDidNotPass.selector, votesFor, votesAgainst));
        token.executeProposal(pid);
    }

    function test_RevertIfProposalNotExists() public {
        vm.expectRevert(abi.encodeWithSelector(ProposalNotExists.selector, 999));
        vm.prank(admin);
        token.executeProposal(999); // no proposal with this ID
    }

    function test_RevertIfProposalExpired() public {
        vm.startPrank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        uint256 expiration = token.getProposal(pid).expiration;

        vm.warp(expiration + 1); // Go just past expiration

        vm.expectRevert(abi.encodeWithSelector(ProposalExpired.selector, block.timestamp, expiration));
        token.voteOnProposal(pid, true);
        vm.stopPrank();
    }

    function test_GetProposal_ReturnsCorrectData() public {
        vm.prank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        GovernanceToken.Proposal memory p = token.getProposal(pid);

        assertEq(p.proposer, admin);
        assertEq(p.target, admin);
        assertEq(p.value, value);
        assertEq(p.data, data);
        assertEq(uint256(0), uint256(General));
        assertEq(p.descriptionHash, descriptionHash);
        assertEq(p.executed, false);
        assertGt(p.expiration, block.timestamp); // should be 7 days ahead
    }

    function test_GetProposals_ReturnsAllProposalsInOrder() public {
        vm.startPrank(admin);
        token.createProposal(admin, value, data, General, descriptionHash);
        token.createProposal(address(0x222), 0.5 ether, hex"abcd", GovernanceToken.Category.General, "ipfs://p2");
        vm.stopPrank();

        GovernanceToken.Proposal[] memory all = token.getProposals();

        assertEq(all.length, 2);

        assertEq(all[0].proposer, admin);
        assertEq(all[0].target, admin);
        assertEq(all[0].descriptionHash, descriptionHash);

        assertEq(all[1].target, address(0x222));
        assertEq(all[1].value, 0.5 ether);
        assertEq(all[1].data, hex"abcd");
        assertEq(uint256(0), uint256(GovernanceToken.Category.General));
        assertEq(all[1].descriptionHash, "ipfs://p2");
    }

    function test_AutoExecuteProposalSuccess() public {
        vm.prank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        vm.prank(admin);
        token.voteOnProposal(pid, true);

        vm.warp(block.timestamp + 7 days + 1); // expiration

        vm.prank(admin);
        token.autoExecuteProposals();

        GovernanceToken.Proposal memory prop1 = token.getProposal(pid);
        bool executed1 = prop1.executed;
        assertFalse(executed1);

        // fast forward past EXECUTION_DELAY
        vm.warp(block.timestamp + 1 days + 1);

        // auto execute again
        vm.prank(admin);
        token.autoExecuteProposals();

        GovernanceToken.Proposal memory prop2 = token.getProposal(pid);
        bool executed2 = prop2.executed;
        assertTrue(executed2);
    }

    function test_AutoExecuteSkipsFailedProposals() public {
        vm.prank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        vm.prank(admin);
        token.voteOnProposal(pid, true);

        vm.warp(block.timestamp + 7 days + 1);

        vm.prank(admin);
        token.autoExecuteProposals();

        // Fast forward to allow execution
        vm.warp(block.timestamp + 1 days + 1);

        // Try to execute again
        vm.prank(admin);
        token.autoExecuteProposals();

        GovernanceToken.Proposal memory prop = token.getProposal(pid);
        bool executed = prop.executed;
        assertTrue(executed);
    }

    function test_OnlySelfCallAllowed_SafeExecute() public {
        vm.prank(admin);
        uint256 pid = token.createProposal(admin, value, data, General, descriptionHash);

        vm.prank(admin);
        token.voteOnProposal(pid, true);

        vm.warp(block.timestamp + 7 days + 1);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(OnlySelfCallAllowed.selector));
        token._safeExecute(pid);
    }

    function test_LogRoleAdmin() public view {
        bytes32 adminRole = token.getRoleAdmin(token.MINTER_ROLE());
        console.logBytes32(adminRole);
        assertEq(adminRole, token.DEFAULT_ADMIN_ROLE());
    }

    function test_AdminHasDefaultRoles() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.ADMIN_ROLE(), admin));
    }

    function test_GrantAdminRole_RevokeAdminRole() public {
        vm.prank(admin);
        token.grantAdminRole(user);
        assertTrue(token.hasRole(token.ADMIN_ROLE(), user));

        vm.startPrank(admin);
        token.grantAdminRole(user);
        assertTrue(token.hasRole(token.ADMIN_ROLE(), user));
        token.revokeAdminRole(user);
        assertFalse(token.hasRole(token.ADMIN_ROLE(), user));
        vm.stopPrank();
    }

    function test_AttackerCannot_GrantAdminRole_RevokeAdminRole() public {
        vm.startPrank(attacker);
        vm.expectRevert();
        token.grantAdminRole(user);

        vm.expectRevert();
        token.revokeAdminRole(user);
        vm.stopPrank();
    }

    function test_TransferAdminRole() public {
        vm.startPrank(admin);
        token.transferAdminRole(user);
        assertTrue(token.hasRole(token.ADMIN_ROLE(), user));
        assertFalse(token.hasRole(token.ADMIN_ROLE(), admin));
        vm.stopPrank();
    }

    function test_AttackerCannot_TransferAdminRole() public {
        vm.startPrank(attacker);
        vm.expectRevert();
        token.transferAdminRole(user);
        vm.stopPrank();
    }

    function test_MinterCanMint() public {
        uint256 mintAmount = 100 ether;
        vm.prank(minter);
        token.mintTokens(user, mintAmount);
        assertEq(token.balanceOf(user), mintAmount);
    }

    function test_AttackerCannotMint() public {
        vm.prank(attacker);
        vm.expectRevert();
        token.mintTokens(user, 100 ether);
    }

    function test_LockerCanLockTokens() public {
        vm.prank(locker);
        token.lockTokens(user, 1 days);
        assertGt(token.lockupEnd(user), block.timestamp);
    }

    function test_AttackerCannotLockTokens() public {
        vm.expectRevert();
        vm.prank(attacker);
        token.lockTokens(user, 1 days);
    }

    function test_AdminCanGrantAndRevokeRole() public {
        vm.startPrank(admin);
        token.grantRole(token.MINTER_ROLE(), attacker);
        assertTrue(token.hasRole(token.MINTER_ROLE(), attacker));

        token.revokeRole(token.MINTER_ROLE(), attacker);
        assertFalse(token.hasRole(token.MINTER_ROLE(), attacker));
        vm.stopPrank();
    }

    // function test_NonAdminCannotGrantOrRevokeRole() public {
    //     vm.startPrank(attacker);
    //     vm.expectRevert();
    //     token.grantRole(token.LOCKER_ROLE(), attacker);
    //     vm.expectRevert();
    //     token.revokeRole(token.LOCKER_ROLE(), locker);
    //     vm.stopPrank();
    // }

    function test_VestTokens_Success() public {
        vm.prank(vester);
        token.vestTokens(user, amount, start, cliff, duration, true);

        (,, uint256 durationStored, uint256 amt,, bool revocable,) = token.vestings(user);
        assertEq(durationStored, duration);
        assertEq(amt, amount);
        assertEq(revocable, true);
    }

    function test_VestTokensRevertIf_ZeroAmount_ZeroDuration_InvalidCliffDuration() public {
        vm.prank(vester);
        vm.expectRevert(abi.encodeWithSelector(ZeroAmount.selector));
        token.vestTokens(user, 0, start, cliff, duration, true);

        vm.prank(vester);
        vm.expectRevert(abi.encodeWithSelector(ZeroDuration.selector));
        token.vestTokens(user, amount, start, cliff, 0, true);

        vm.prank(vester);
        vm.expectRevert(abi.encodeWithSelector(InvalidCliffDuration.selector, 100, cliff));
        token.vestTokens(user, amount, start, cliff, 100, true);
    }

    function test_NonRevocableVestingCannotBeRevoked() public {
        vm.prank(vester);
        token.vestTokens(user, amount, start, cliff, duration, false);

        vm.prank(admin);
        vm.expectRevert();
        token.revokeVesting(user);
    }

    function test_AttackerCannotVestTokens() public {
        vm.prank(attacker);
        vm.expectRevert();
        token.vestTokens(user, amount, start, cliff, duration, false);
    }

    function test_RevertOnDoubleVestingWithoutRevocation() public {
        vm.startPrank(vester);
        token.vestTokens(user, amount, start, cliff, duration, true);
        vm.expectRevert(abi.encodeWithSelector(AlreadyVesting.selector, user));
        token.vestTokens(user, amount, start, cliff, duration, true);
        vm.stopPrank();
    }

    function test_ReleaseBeforeCliffFails() public {
        vm.prank(vester);
        token.vestTokens(user, amount, start, cliff, duration, true);

        vm.warp(block.timestamp + 1 days);
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NoTokensToRelease.selector)); // will trigger NoTokensToRelease
        token.releaseVestedTokens();
    }

    function test_ReleaseAfterCliffSucceeds() public {
        vm.prank(vester);
        token.vestTokens(user, amount, start, cliff, duration, true);

        vm.warp(start + cliff + 1);

        vm.prank(user);
        token.releaseVestedTokens();

        uint256 bal = token.balanceOf(user);
        assertGt(bal, 0);
        assertGt(token.getVotes(user), 0);
    }

    function test_FullVestingAfterDuration() public {
        vm.prank(vester);
        token.vestTokens(user, amount, start, cliff, duration, true);

        vm.warp(start + duration + 1);
        vm.prank(user);
        token.releaseVestedTokens();

        assertEq(token.balanceOf(user), amount);
    }

    function test_RevokeVesting() public {
        vm.prank(vester);
        token.vestTokens(user, amount, start, cliff, duration, true);

        vm.prank(vester);
        token.revokeVesting(user);

        (,,,,,, bool revoked) = token.vestings(user);
        assertTrue(revoked);
    }

    function test_RevertRevokeIfAlreadyRevoked() public {
        vm.prank(vester);
        token.vestTokens(user, amount, start, cliff, duration, true);

        vm.prank(vester);
        token.revokeVesting(user);

        vm.prank(vester);
        vm.expectRevert(abi.encodeWithSelector(Error__VestingRevoked.selector));
        token.revokeVesting(user);
    }

    function test_RevertRevokeIfNotRevocable() public {
        vm.prank(vester);
        token.vestTokens(user, amount, start, cliff, duration, false);

        vm.prank(vester);
        vm.expectRevert(abi.encodeWithSelector(NotRevocable.selector));
        token.revokeVesting(user);
    }

    function test_RevertReleaseIfNoVesting() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NoVestingSchedule.selector));
        token.releaseVestedTokens();
    }

    function test_RevertReleaseIfRevoked() public {
        vm.prank(vester);
        token.vestTokens(user, amount, start, cliff, duration, true);

        vm.prank(vester);
        token.revokeVesting(user);

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Error__VestingRevoked.selector));
        token.releaseVestedTokens();
    }

    function test_RevertIfNothingToRelease() public {
        vm.prank(vester);
        token.vestTokens(user, amount, start, cliff, duration, true);

        vm.warp(start + cliff + 1);
        vm.prank(user);
        token.releaseVestedTokens();

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(NoTokensToRelease.selector));
        token.releaseVestedTokens();
    }

    function test_ReceiveETH() public {
        uint256 sendAmount = 1 ether;
        vm.deal(user, 100 ether);
        vm.prank(user);
        (bool success,) = address(token).call{value: sendAmount}("");
        assertTrue(success, "Failed to send ETH to receive() function");
        assertEq(address(token).balance, sendAmount, "Contract did not receive ETH");
    }
}
