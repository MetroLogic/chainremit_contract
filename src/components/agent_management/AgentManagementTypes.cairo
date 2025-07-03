use starknet::ContractAddress;

/// @title AgentStatus
/// @notice Enum representing the status of an agent for tracking availability.
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum AgentStatus {
    #[default]
    Active,
    Inactive,
    Suspended,
}

/// @title Agent
/// @notice Struct representing a cash-out agent with relevant details and statistics.
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Agent {
    pub agent_address: ContractAddress,
    pub name: felt252,
    pub status: AgentStatus,
    pub primary_region: felt252,
    pub secondary_region: felt252,
    pub commission_rate: u256,
    pub completed_transactions: u256,
    pub total_volume: u256,
    pub registered_at: u64,
    pub last_active: u64,
    pub rating: u256,
}
