use starknet::ContractAddress;
/// @notice Emitted when a new savings group is created.
/// @param group_id Unique identifier for the group.
/// @param creator Address of the group creator.
/// @param max_members Maximum number of members allowed in the group.
#[derive(Copy, Drop, starknet::Event)]
pub struct GroupCreated {
    #[key]
    pub group_id: u64,
    pub creator: ContractAddress,
    pub max_members: u8,
}

/// @notice Emitted when a member joins a savings group.
/// @param group_id Identifier of the group joined.
/// @param member Address of the member who joined.
#[derive(Copy, Drop, starknet::Event)]
pub struct MemberJoined {
    #[key]
    pub group_id: u64,
    #[key]
    pub member: ContractAddress,
}

/// @notice Emitted when a member is added to a group by an admin or creator.
/// @param address Address of the member added.
#[derive(Copy, Drop, starknet::Event)]
pub struct MemberAdded {
    #[key]
    pub address: ContractAddress,
}

/// @notice Emitted when a contribution is made to a round.
/// @param round_id Identifier of the round.
/// @param member Address of the contributing member.
/// @param amount Amount contributed.
#[derive(Copy, Drop, starknet::Event)]
pub struct ContributionMade {
    #[key]
    pub round_id: u256,
    pub member: ContractAddress,
    pub amount: u256,
}


/// @notice Emitted when a round is disbursed to a recipient.
/// @param round_id Identifier of the round.
/// @param amount Amount disbursed.
/// @param recipient Address of the recipient.
#[derive(Copy, Drop, starknet::Event)]
pub struct RoundDisbursed {
    #[key]
    pub round_id: u256,
    pub amount: u256,
    pub recipient: ContractAddress,
}

/// @notice Emitted when a round is completed.
/// @param round_id Identifier of the completed round.
#[derive(Copy, Drop, starknet::Event)]
pub struct RoundCompleted {
    #[key]
    pub round_id: u256,
}


/// @notice Emitted when a member misses a contribution in a round.
/// @param round_id Identifier of the round.
/// @param member Address of the member who missed the contribution.
#[derive(Copy, Drop, starknet::Event)]
pub struct ContributionMissed {
    #[key]
    pub round_id: u256,
    pub member: ContractAddress,
}
