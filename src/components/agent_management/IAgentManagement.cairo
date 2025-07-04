use starknet::ContractAddress;
use super::AgentManagementTypes::{Agent, AgentStatus};

#[starknet::interface]
pub trait IAgentManagement<TContractState> {
    /// @notice Registers a new agent. Only callable by admin.
    /// @param agent_address The address of the agent to register.
    /// @param name The name of the agent.
    /// @param primary_region The primary region of the agent.
    /// @param secondary_region The secondary region of the agent.
    /// @param commission_rate The commission rate for the agent.
    /// @return True if registration is successful.
    fn register_agent(
        ref self: TContractState,
        agent_address: ContractAddress,
        name: felt252,
        primary_region: felt252,
        secondary_region: felt252,
        commission_rate: u256,
    ) -> bool;
    /// @notice Updates the status of an agent. Only callable by admin.
/// @param agent_address The address of the agent.
/// @param status The new status for the agent.
/// @return True if update is successful.
// fn update_agent_status(
//     ref self: TContractState, agent_address: ContractAddress, status: AgentStatus,
// ) -> bool;

    // /// @notice Retrieves the details of an agent.
// /// @param agent_address The address of the agent.
// /// @return The Agent struct containing agent details.
// fn get_agent(self: @TContractState, agent_address: ContractAddress) -> Agent;

    // /// @notice Retrieves a list of agents filtered by status.
// /// @param status The status to filter agents by.
// /// @param limit The maximum number of agents to return.
// /// @param offset The number of agents to skip.
// /// @return An array of Agent structs.
// fn get_agents_by_status(
//     self: @TContractState, status: AgentStatus, limit: u32, offset: u32,
// ) -> Array<Agent>;

    // /// @notice Retrieves a list of agents filtered by region.
// /// @param region The region to filter agents by.
// /// @param limit The maximum number of agents to return.
// /// @param offset The number of agents to skip.
// /// @return An array of Agent structs.
// fn get_agents_by_region(
//     self: @TContractState, region: felt252, limit: u32, offset: u32,
// ) -> Array<Agent>;

    // /// @notice Checks if an agent is authorized for a specific transfer.
// /// @param agent The address of the agent.
// /// @param transfer_id The ID of the transfer.
// /// @return True if the agent is authorized.
// fn is_agent_authorized(
//     self: @TContractState, agent: ContractAddress, transfer_id: u256,
// ) -> bool;

    // /// @notice Retrieves statistics for an agent.
// /// @param agent The address of the agent.
// /// @return total_transfers, total_volume, rating.
// fn get_agent_statistics(self: @TContractState, agent: ContractAddress) -> (u256, u256, u256);
}
