use starknet::ContractAddress;

/// Contribution round data structure
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ContributionRound {
    pub round_id: u256,
    pub recipient: ContractAddress,
    pub deadline: u64,
    pub total_contributions: u256,
    pub status: RoundStatus,
}

/// Member contribution data
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct MemberContribution {
    pub member: ContractAddress,
    pub amount: u256,
    pub contributed_at: u64,
}

/// Savings group data structure
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct SavingsGroup {
    pub id: u64,
    pub creator: ContractAddress,
    pub max_members: u8,
    pub member_count: u32,
    pub total_savings: u256,
    pub created_at: u64,
    pub is_active: bool,
}

/// Enum for the status of a contribution round
#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub enum RoundStatus {
    #[default]
    Active,
    Completed,
    Cancelled,
}
