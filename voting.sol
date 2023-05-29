// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedProposalId;
    }
    struct Proposal {
        string description;
        uint256 voteCount;
    }

    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    mapping(address => Voter) voters;
    mapping(address => bool) public whitelist;
    Proposal[] public allProposal;
    address[] public addresses;
    WorkflowStatus public workflowStatus = WorkflowStatus.RegisteringVoters;

    event Authorized(address _address);
    event VoterRegistered(address voterAddress);
    event WorkflowStatusChange(
        WorkflowStatus previousStatus,
        WorkflowStatus newStatus
    );
    event ProposalRegistered(uint256 proposalId);
    event Voted(address voter, uint256 proposalId);

    modifier check() {
        require(whitelist[msg.sender] == true, "Not Authorized");
        _;
    }

    constructor() {
        whitelist[owner()] = true;
    }

    function authorize(address _address) public check {
        whitelist[_address] = true;
        emit Authorized(_address);
    }

    function setWhitelist(address[] calldata _addresses) external onlyOwner {
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(
                !whitelist[_addresses[i]],
                unicode"L'adresse est déjà dans la liste blanche"
            );
            whitelist[_addresses[i]] = true;
            emit Authorized(_addresses[i]);
        }
    }

    function giveRightToVote(address voter) external onlyOwner check {
        require(
            !voters[voter].isRegistered,
            unicode"L'électeur est déjà enregistré"
        );
        require(!voters[voter].hasVoted, unicode"L'électeur a déjà voté");
        voters[voter].isRegistered = true;
        addresses.push(voter);
        emit VoterRegistered(voter);
    }

    function startRegisterSession() public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.RegisteringVoters,
            unicode"Le processus d'enregistrement des électeurs doit être en cours"
        );
        workflowStatus = WorkflowStatus.ProposalsRegistrationStarted;
        emit WorkflowStatusChange(
            WorkflowStatus.RegisteringVoters,
            WorkflowStatus.ProposalsRegistrationStarted
        );
    }

    function registerProposal(string calldata proposalDescription)
        external
        check
    {
        require(
            workflowStatus == WorkflowStatus.ProposalsRegistrationStarted,
            "L'enregistrement des propositions n'est pas ouvert"
        );

        Proposal memory newProposal;
        newProposal.description = proposalDescription;
        newProposal.voteCount = 0;

        allProposal.push(newProposal);
        emit ProposalRegistered(allProposal.length - 1);
    }

    function endProposalRegistration() public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.ProposalsRegistrationStarted,
            unicode"La session d'enregistrement des propositions doit être en cours"
        );
        workflowStatus = WorkflowStatus.ProposalsRegistrationEnded;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationStarted,
            WorkflowStatus.ProposalsRegistrationEnded
        );
    }

    function startVotingSession() public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.ProposalsRegistrationEnded,
            unicode"La session d'enregistrement des propositions doit être terminée"
        );
        workflowStatus = WorkflowStatus.VotingSessionStarted;
        emit WorkflowStatusChange(
            WorkflowStatus.ProposalsRegistrationEnded,
            WorkflowStatus.VotingSessionStarted
        );
    }

    function vote(uint256 proposalId) external check {
        require(
            workflowStatus == WorkflowStatus.VotingSessionStarted,
            "La session de vote n'est pas ouverte"
        );
        require(!voters[msg.sender].hasVoted, unicode"Vous avez déjà voté");
        require(proposalId < allProposal.length, "La proposition n'existe pas");

        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedProposalId = proposalId;

        allProposal[proposalId].voteCount += 1;

        emit Voted(msg.sender, proposalId);
    }

    function endVotingSession() public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.VotingSessionStarted,
            unicode"La session de vote doit être en cours"
        );
        workflowStatus = WorkflowStatus.VotingSessionEnded;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionStarted,
            WorkflowStatus.VotingSessionEnded
        );
    }

    function tallyVotes() public onlyOwner {
        require(
            workflowStatus == WorkflowStatus.VotingSessionEnded,
            unicode"La session de vote doit être terminée avant de compter les votes"
        );
        workflowStatus = WorkflowStatus.VotesTallied;
        emit WorkflowStatusChange(
            WorkflowStatus.VotingSessionEnded,
            WorkflowStatus.VotesTallied
        );
    }

    function getWinners()
        public
        view
        returns (uint256[] memory winningProposals_, uint256 winningVoteCount_)
    {
        require(
            workflowStatus == WorkflowStatus.VotesTallied,
            unicode"Le vote doit être terminé pour compter les votes"
        );

        uint256 winningVoteCount = 0;
        uint256[] memory winningProposals;

        for (uint256 p = 0; p < allProposal.length; p++) {
            if (allProposal[p].voteCount > winningVoteCount) {
                winningVoteCount = allProposal[p].voteCount;
                winningProposals = new uint256[](1);
                winningProposals[0] = p;
            } else if (allProposal[p].voteCount == winningVoteCount) {
                uint256[] memory tempWinners = new uint256[](
                    winningProposals.length + 1
                );
                for (uint256 i = 0; i < winningProposals.length; i++) {
                    tempWinners[i] = winningProposals[i];
                }
                tempWinners[winningProposals.length] = p;
                winningProposals = tempWinners;
            }
        }

        return (winningProposals, winningVoteCount);
    }

    function reset() public onlyOwner {
        workflowStatus = WorkflowStatus.RegisteringVoters;
        for (uint256 i = 0; i < allProposal.length; i++) {
            allProposal[i].voteCount = 0;
        }
        for (uint256 i = 0; i < allProposal.length; i++) {
            delete allProposal[i];
        }
        for (uint256 i = 0; i < addresses.length; i++) {
            voters[addresses[i]].isRegistered = false;
            voters[addresses[i]].hasVoted = false;
            voters[addresses[i]].votedProposalId = 0;
        }
        addresses = new address[](0);
    }
}
