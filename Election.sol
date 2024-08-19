// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EVoting {
    address public owner;

    struct Voter {
        uint256 voteChoice;
        bool isValidVoter;
    }

    struct Candidate {
        uint256 id;
        string name;
        uint256 voteCount;
    }

    struct Election {
        uint256 id;
        string name;
        uint256 startDate;
        uint256 endDate;
        address[] voterAddresses;
        mapping(address => Voter) voters;
        mapping(uint256 => Candidate) candidates;
        uint256 candidateCount;
        uint256 voterCount;
    }

    struct Result {
        mapping(uint256 => uint256) totalVotes; // candidateId => voteCount
        mapping(address => uint256) voteChoices; // voterAddress => voteChoice
    }

    mapping(uint256 => Election) public elections;
    uint256 public electionCount = 0;
    uint256 public candidateCount = 0;

    event ElectionCreated(uint256 electionId, string name, uint256 startDate, uint256 endDate);
    event VoteCasted(uint256 electionId, address voter, uint256 candidateId);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action!");
        _;
    }

    function createElection(
        string memory _name,
        uint256 _startDate,
        uint256 _endDate,
        address[] memory _voters,
        string[] memory _candidates
    ) public onlyOwner {
        require(_startDate < _endDate, "Start date must be before end date");
        require(_endDate > block.timestamp, "End date must be in the future");
        require(_voters.length > 1, "Must have atleast two voters");
        require(_candidates.length > 1, "Must have atleast two candidate");

        electionCount++;
        Election storage newElection = elections[electionCount];
        newElection.id = electionCount;
        newElection.name = _name;
        newElection.startDate = _startDate;
        newElection.endDate = _endDate;
        newElection.candidateCount = 0;

        for (uint256 i = 0; i < _voters.length; i++) {
            require(_voters[i] != owner, "Owner can not be a voter");
            newElection.voterCount++;
            newElection.voterAddresses.push(_voters[i]);
            newElection.voters[_voters[i]] = Voter({
                voteChoice: 0,
                isValidVoter: true
            });
        }

        for (uint256 i = 0; i < _candidates.length; i++) {
            candidateCount++;
            newElection.candidateCount++;
            newElection.candidates[newElection.candidateCount] = Candidate({
                id: newElection.candidateCount,
                name: _candidates[i],
                voteCount: 0
            });
        }

        emit ElectionCreated(electionCount, _name, _startDate, _endDate);
    }

    function isElectionEnded(uint256 _electionEndDate) internal view returns (bool) {
        return block.timestamp > _electionEndDate;
    }

    function getElectionDetails(uint256 _electionId)
        public
        view
        returns (
            string memory name,
            uint256 startDate,
            uint256 endDate,
            Candidate[] memory candidates,
            address[] memory voterList,
            uint256[] memory voterChoices,
            uint256[] memory results,
            bool hasVoted,
            uint256 votedChoice,
            bool hasEnded
        )
    {
        Election storage election = elections[_electionId];

        name = election.name;
        endDate = election.endDate;
        hasVoted = election.voters[msg.sender].isValidVoter && election.voters[msg.sender].voteChoice != 0;
        hasEnded = isElectionEnded(endDate);
        votedChoice = 0;

        if (hasVoted) {
            votedChoice = election.voters[msg.sender].voteChoice;
        }

        candidates = new Candidate[](election.candidateCount);

        for (uint256 i = 1; i <= election.candidateCount; i++) {
            candidates[i - 1] = election.candidates[i];
        }

        if (isElectionEnded(endDate)) {
            voterList = new address[](election.voterCount);

            for (uint256 i = 0; i < election.voterCount; i++) {
                voterList[i] = election.voterAddresses[i];
            }
        } else {
            voterList = new address[](0);
        }

        if (isElectionEnded(endDate)) {
            results = new uint256[](election.candidateCount);
            voterChoices = new uint256[](election.voterCount);

            // get candidates voted count result
            for (uint256 i = 1; i <= election.candidateCount; i++) {
                results[i - 1] = election.candidates[i].voteCount;
            }

            for (uint256 i = 0; i < election.voterCount; i++) {
                address voterAddress = election.voterAddresses[i];
                voterChoices[i] = election.voters[voterAddress].voteChoice;
            }
        }

        // Return the election details and candidates
        return (name, startDate, endDate, candidates, voterList, voterChoices, results, hasVoted, votedChoice, hasEnded);
    }

    struct ElectionInfo {
        uint256 id;
        string name;
        uint256 startDate;
        uint256 endDate;
        bool hasVoted;
    }

    function isRegisteredVoter(uint256 _electionId, address _voterAddress) internal view returns (bool) {
        Election storage election = elections[_electionId];

        if (election.voters[_voterAddress].isValidVoter == true) {
            return true;
        }

        return false;
    }

    function getElections() public view returns (ElectionInfo[] memory) {
        uint256 count = 0;

        // First pass to count the number of valid elections
        for (uint256 i = 1; i <= electionCount; i++) {
            if (isRegisteredVoter(i, msg.sender) || msg.sender == owner) {
                count++;
            }
        }

        // Initialize the result array with the correct size
        ElectionInfo[] memory electionList = new ElectionInfo[](count);
        uint256 j = 0;

        // Second pass to populate the result array
        for (uint256 i = 1; i <= electionCount; i++) {
            if (isRegisteredVoter(i, msg.sender) || msg.sender == owner) {
                Election storage election = elections[i];
                electionList[j] = ElectionInfo({
                    id: election.id,
                    name: election.name,
                    startDate: election.startDate,
                    endDate: election.endDate,
                    hasVoted: election.voters[msg.sender].isValidVoter && election.voters[msg.sender].voteChoice != 0
                });
                j++;
            }
        }

        return electionList;
    }

    function vote(uint256 _electionId, uint256 _candidateId) public {
        Election storage election = elections[_electionId];

        require(block.timestamp >= election.startDate, "Election has not started");
        require(block.timestamp < election.endDate, "Election has ended");
        require(election.voters[msg.sender].isValidVoter, "Not a valid voter");
        require(election.voters[msg.sender].voteChoice == 0, "Already Voted");
        require(_candidateId > 0 && _candidateId <= election.candidateCount, "Invalid Candidate ID");

        election.voters[msg.sender].voteChoice = _candidateId;
        election.candidates[_candidateId].voteCount++;

        emit VoteCasted(_electionId, msg.sender, _candidateId);
    }
}
