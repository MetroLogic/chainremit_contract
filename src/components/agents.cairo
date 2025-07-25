use starknet::ContractAddress;
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use crate::base::events::agents::*;
use crate::base::types::agents::*;
#[starknet::interface]
pub trait IAgents<TContractState> {
    // Agent Management Functions
    fn register_agent(
        ref self: TContractState,
        agent_address: ContractAddress,
        name: felt252,
        primary_region: felt252,
        secondary_region: felt252,
        commission_rate: u256,
    ) -> bool;
    fn update_agent_status(
        ref self: TContractState, agent_address: ContractAddress, status: AgentStatus,
    ) -> bool;
    fn get_agent(self: @TContractState, agent_address: ContractAddress) -> Agent;
    fn get_agents_by_status(
        self: @TContractState, status: AgentStatus, limit: u32, offset: u32,
    ) -> Array<Agent>;
    fn get_agents_by_region(
        self: @TContractState, region: felt252, limit: u32, offset: u32,
    ) -> Array<Agent>;
    fn is_agent_authorized(
        self: @TContractState, agent: ContractAddress, transfer_id: u256,
    ) -> bool;
    fn get_agent_statistics(self: @TContractState, agent: ContractAddress) -> (u256, u256, u256);

    // Agent-specific Transfer Functions
    fn complete_cash_out(ref self: TContractState, transfer_id: u256) -> bool;
}


#[starknet::component]
pub mod agent_component {
    use super::*;

    #[storage]
    struct Storage {
        // Agent Management storage
        agents: Map<ContractAddress, Agent>, // Agent address to Agent mapping
        agent_exists: Map<ContractAddress, bool>, // Check if agent exists
        agent_by_region: Map<
            (felt252, u32), ContractAddress,
        >, // Agents by region (region, index) -> agent_address
        agent_region_count: Map<felt252, u32> // Count of agents by region
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AgentAuthorized: AgentAuthorized,
        AgentPermissionUpdated: AgentPermissionUpdated,
        AgentPermissionRevoked: AgentPermissionRevoked,
        AgentAssigned: AgentAssigned, // Event for agent assignment
        AgentRegistered: AgentRegistered, // Event for agent registration
        AgentStatusUpdated: AgentStatusUpdated // Event for agent status updates
    }

    #[embeddable_as(Agent)]
    impl AgentImpl<
        TContractState, +HasComponent<TContractState>,
    > of IAgents<ComponentState<TContractState>> {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {}
}
