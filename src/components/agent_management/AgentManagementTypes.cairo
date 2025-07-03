use starknet::ContractAddress;

/// Agent status for tracking agent availability
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum AgentStatus {
    #[default]
    Active,
    Inactive,
    Suspended,
}

/// Agent data structure for managing cash-out agents
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Agent {
    pub agent_address: ContractAddress,
    pub name: felt252,
    pub status: AgentStatus,
    // pub primary_currency: felt252,
    // pub secondary_currency: felt252,
    pub primary_region: felt252,
    pub secondary_region: felt252,
    pub commission_rate: u256,
    pub completed_transactions: u256,
    pub total_volume: u256,
    pub registered_at: u64,
    pub last_active: u64,
    pub rating: u256,
}
