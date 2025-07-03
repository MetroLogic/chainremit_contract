use starknet::ContractAddress;
use crate::components::agent_management::AgentManagementTypes::AgentStatus;
/// @notice Emitted when an agent is assigned to a transfer.
/// @param transfer_id The unique identifier of the transfer.
/// @param agent The address of the assigned agent.
/// @param assigned_by The address of the entity assigning the agent.
/// @param timestamp The time when the assignment occurred.
#[derive(Copy, Drop, starknet::Event)]
pub struct AgentAssigned {
    #[key]
    pub transfer_id: u256,
    #[key]
    pub agent: ContractAddress,
    #[key]
    pub assigned_by: ContractAddress,
    pub timestamp: u64,
}
/// @notice Emitted when a new agent is registered.
/// @param agent_address The address of the registered agent.
/// @param name The name of the agent.
/// @param commission_rate The commission rate assigned to the agent.
/// @param registered_by The address of the entity registering the agent.
/// @param timestamp The time when the registration occurred.
#[derive(Copy, Drop, starknet::Event)]
pub struct AgentRegistered {
    #[key]
    pub agent_address: ContractAddress,
    pub name: felt252,
    pub commission_rate: u256,
    pub registered_by: ContractAddress,
    pub timestamp: u64,
}

/// @notice Emitted when an agent's status is updated.
/// @param agent The address of the agent whose status is updated.
/// @param old_status The previous status of the agent.
/// @param new_status The new status of the agent.
/// @param updated_by The address of the entity updating the status.
/// @param timestamp The time when the status update occurred.
#[derive(Copy, Drop, starknet::Event)]
pub struct AgentStatusUpdated {
    #[key]
    pub agent: ContractAddress,
    pub old_status: AgentStatus,
    pub new_status: AgentStatus,
    pub updated_by: ContractAddress,
    pub timestamp: u64,
}
