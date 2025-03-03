// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title Voting with delegation.
contract Ballot {
    // errors
    error Ballot__OnlyChairPersonCanGiveRightToVote();
    error Ballot__VoterAlreadyVoted();
    error Ballot__VoterAlredyHaveRightToVote();
    error Ballot__VoterHasNoRightToVote();
    error Ballot__SelfDelegationIsDisallowed();
    error Ballot__FoundLoopInDelegation();

    // represent a single voter.
    struct Voter {
        uint weight; // weight is accumulated by delegation
        bool voted; // if true, that person already voted
        address delegate; // person delegated to
        uint vote; // index of the voted proposal
    }

    // a single proposal.
    struct Proposal {
        bytes32 name; // short name (up to 32 bytes)
        uint voteCount; // number of accumulated votes
    }

    address public chairperson;

    // stores a `Voter` struct for each possible address.
    mapping(address => Voter) public voters;

    // A dynamically-sized array of `Proposal` structs.
    Proposal[] public proposals;

    constructor(bytes32[] memory proposalNames) {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        // create a new proposal object for each of the provided proposal names
        // and add it to the end of the array.
        for (uint i = 0; i < proposalNames.length; i++) {
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }

    // Give `voter` the right to vote on this ballot.
    // May only be called by `chairperson`.
    function giveRightToVote(address voter) external {
        if(msg.sender != chairperson) revert Ballot__OnlyChairPersonCanGiveRightToVote();

        if(voters[voter].voted) revert Ballot__VoterAlreadyVoted();

        if(voters[voter].weight != 0) revert Ballot__VoterAlredyHaveRightToVote();

        voters[voter].weight = 1;
    }

    /// Delegate your vote to the voter `to`.
    function delegate(address to) external {
        Voter storage sender = voters[msg.sender];

        if(sender.weight == 0) revert Ballot__VoterHasNoRightToVote();

        if(sender.voted) revert Ballot__VoterAlreadyVoted();

        if(to == msg.sender) revert Ballot__SelfDelegationIsDisallowed();

        // Forward the delegation as long as
        // `to` also delegated.
        while (voters[to].delegate != address(0)) {
            to = voters[to].delegate;

            if(to == msg.sender) revert Ballot__FoundLoopInDelegation();
        }

        Voter storage delegate_ = voters[to];

        // Voters cannot delegate to accounts that cannot vote.
        if(delegate_.weight == 0) revert Ballot__VoterHasNoRightToVote();

        sender.voted = true;
        sender.delegate = to;

        if(delegate_.voted) {
            // If the delegate already voted,
            // directly add to the number of votes
            proposals[delegate_.vote].voteCount += sender.weight;
        }
        else {
            // If the delegate did not vote yet,
            // add to her weight.
            delegate_.weight += sender.weight;
        }
    }

    /// Give your vote (including votes delegated to you)
    /// to proposal `proposals[proposal].name`.
    function vote(uint proposal) external {
        Voter storage sender = voters[msg.sender];

        if(sender.weight == 0) revert Ballot__VoterHasNoRightToVote();

        if(sender.voted) revert Ballot__VoterAlreadyVoted();

        sender.voted = true;
        sender.vote = proposal;

        // If `proposal` is out of the range of the array,
        // this will throw automatically and revert all changes.
        proposals[proposal].voteCount += sender.weight;
    }

    function winningProposal() public view returns (uint winningProposal_) {
        uint winningVoteCount = 0;

        for(uint p = 0; p < proposals.length; p++) {
            if(proposals[p].voteCount > winningVoteCount) {
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }

        return winningProposal_;
    }

    function winnerName() external view returns(bytes32 winnerName_) {
        winnerName_ = proposals[winningProposal()].name;
    }
}