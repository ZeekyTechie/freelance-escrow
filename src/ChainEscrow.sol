// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ChainEscrow {

// Represents the different stages a project can be in
    enum ProjectStatus {
        Open,
        Funded,
        Accepted,
        Submitted,
        Completed,
        Cancelled
    }

// Stores all important information about a freelance project
struct Project {
    uint256 id;
    address client;
    address freelancer;
    string title;
    string description;
    uint256 budget;
    uint256 deadline;
    ProjectStatus status;
}

// Generates unique IDs so every project can be identified and retrieved later
uint256 private s_projectCounter;

// Stores projects using their project ID as the key
mapping(uint256 => Project) private s_projects;

// Allows a client to create a new freelance project
function createProject(
    string memory _title,
    string memory _description,
    uint256 _budget,
    uint256 _deadline
) public {

    // Generate a new unique project ID
    s_projectCounter++;

    // Store the project in our mapping
    s_projects[s_projectCounter] = Project({
        id: s_projectCounter,
        client: msg.sender,
        freelancer: address(0),
        title: _title,
        description: _description,
        budget: _budget,
        deadline: _deadline,
        status: ProjectStatus.Open
    });

    // Notify the blockchain that a project was created
emit ProjectCreated(
    s_projectCounter,
    msg.sender,
    _budget
);

}

// Returns the details of a specific project
function getProject(
    uint256 _projectId
)
    public
    view
    returns (Project memory)
{
    return s_projects[_projectId];
}

// Emitted whenever a new project is created
event ProjectCreated(
    uint256 indexed projectId,
    address indexed client,
    uint256 budget
);



// Emitted when a freelancer accepts a project
event ProjectAccepted(
    uint256 indexed projectId,
    address indexed freelancer
);

// Allows a freelancer to accept an available project
function acceptProject(
    uint256 _projectId
) public {

    Project storage project =
        s_projects[_projectId];

    // Ensure the project exists
    require(
        project.id != 0,
        "Project does not exist"
    );

    // Ensure the project is still open
    require(
        project.status == ProjectStatus.Open,
        "Project is not open"
    );

    // Assign the freelancer
    project.freelancer = msg.sender;

    // Update project status
    project.status = ProjectStatus.Accepted;

    // Record acceptance on the blockchain
    emit ProjectAccepted(
        _projectId,
        msg.sender
    );
}
}