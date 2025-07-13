contract GovernanceToken_Stateful is Test {
    GovernanceToken public token;
    GovernanceTokenHandler public handler;

    function setUp() public {
        token = new GovernanceToken();
        handler = new GovernanceTokenHandler(token);
        // Use cheatcode to enable fuzz calls from handler
        targetContract(address(handler));
    }

    function invariant_TotalVotingPowerLeTotalSupply() public view {
        uint256 totalVoting;
        for (uint160 i = 1; i <= 5; i++) {
            address user = address(i);
            totalVoting += token.getVotes(user);
        }
        assertLe(totalVoting, token.totalSupply());
    }

    function invariant_OnlyRevocableCanBeRevoked() public {
        for (uint160 i = 1; i <= 5; i++) {
            GovernanceToken.VestingSchedule memory v = token.vestings(address(i));
            if (!v.revocable && v.revoked) {
                fail("Non-revocable vesting was revoked!");
            }
        }
    }

    function invariant_ActiveProposalNotExecutedBeforeTime() public {
        for (uint256 i = 1; i <= token.proposalCount(); i++) {
            GovernanceToken.Proposal memory p = token.getProposal(i);
            if (!p.executed) {
                assertGt(p.expiration + 1 days, block.timestamp);
            }
        }
    }
}
