    use starknet::{ContractAddress};
    use starkremit_contract::base::types::{Agent, AgentStatus};
#[starknet::interface]
pub trait IAgent<TContractState> {
    fn register_agent(ref self: TContractState, agent_address: ContractAddress, name: felt252, primary_region: felt252, secondary_region: felt252, commission_rate: u256) -> bool;
    fn update_agent_status(ref self: TContractState, agent_address: ContractAddress, status: AgentStatus) -> bool;
    fn get_agent(self: @TContractState, agent_address: ContractAddress) -> Agent;
    fn get_agents_by_status(self: @TContractState, status: AgentStatus, limit: u32, offset: u32) -> Array<Agent>;
    fn get_agents_by_region(self: @TContractState, region: felt252, limit: u32, offset: u32) -> Array<Agent>;
    fn is_agent_authorized(self: @TContractState, agent: ContractAddress, transfer_id: u256) -> bool;
    fn assign_agent_to_transfer(ref self: TContractState, transfer_id: u256, agent: ContractAddress) -> bool;
}

#[starknet::component]
pub mod agent_component {
    use super::*;
    use starknet::{get_caller_address, get_block_timestamp, ContractAddress};
    use starkremit_contract::base::errors::TransferErrors;
    use starkremit_contract::base::types::{Agent, AgentStatus};
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess,Map};
     

    #[storage]
    pub struct Storage {
        agents: Map<ContractAddress, Agent>,
        agent_exists: Map<ContractAddress, bool>,
        agent_by_region: Map<(felt252, u32), ContractAddress>,
        agent_region_count: Map<felt252, u32>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AgentAssigned: AgentAssigned,
        AgentRegistered: AgentRegistered,
        AgentStatusUpdated: AgentStatusUpdated,
    }
    #[derive(Drop, starknet::Event)]
    pub struct AgentAssigned {
        transfer_id: u256,
        agent: ContractAddress,
        assigned_by: ContractAddress,
        timestamp: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct AgentRegistered {
        agent_address: ContractAddress,
        name: felt252,
        commission_rate: u256,
        registered_by: ContractAddress,
        timestamp: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct AgentStatusUpdated {
        agent: ContractAddress,
        old_status: AgentStatus,
        new_status: AgentStatus,
        updated_by: ContractAddress,
        timestamp: u64,
    }
    
    #[embeddable_as(AgentComponent)]
    impl AgentImpl<
        TContractState, +HasComponent<TContractState>,
    > of IAgent<ComponentState<TContractState>> {
        fn register_agent(ref self: ComponentState<TContractState>, agent_address: ContractAddress, name: felt252, primary_region: felt252, secondary_region: felt252, commission_rate: u256) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            assert(!self.agent_exists.read(agent_address), TransferErrors::AGENT_ALREADY_EXISTS);
            let agent = Agent {
                agent_address,
                name,
                status: AgentStatus::Active,
                primary_region,
                secondary_region,
                commission_rate,
                completed_transactions: 0,
                total_volume: 0,
                registered_at: current_time,
                last_active: current_time,
                rating: 1000
            };
            self.agents.write(agent_address, agent);
            self.agent_exists.write(agent_address, true);
            if primary_region != 0 {
                let region_count = self.agent_region_count.read(primary_region);
                self.agent_by_region.write((primary_region, region_count), agent_address);
                self.agent_region_count.write(primary_region, region_count + 1);
            }
            if secondary_region != 0 {
                let region_count = self.agent_region_count.read(secondary_region);
                self.agent_by_region.write((secondary_region, region_count), agent_address);
                self.agent_region_count.write(secondary_region, region_count + 1);
            }
            self.emit(Event::AgentRegistered(AgentRegistered {
                agent_address,
                name,
                commission_rate,
                registered_by: caller,
                timestamp: current_time,
            }));
            true
        }
        fn update_agent_status(ref self: ComponentState<TContractState>, agent_address: ContractAddress, status: AgentStatus) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            assert(self.agent_exists.read(agent_address), TransferErrors::AGENT_NOT_FOUND);
            let mut agent: Agent = self.agents.read(agent_address);
            let old_status = agent.status;
            agent.status = status;
            agent.last_active = current_time;
            self.agents.write(agent_address, agent);
            self.emit(Event::AgentStatusUpdated(AgentStatusUpdated {
                agent: agent_address,
                old_status,
                new_status: status,
                updated_by: caller,
                timestamp: current_time,
            }));
            true
        }
        fn get_agent(self: @ComponentState<TContractState>, agent_address: ContractAddress) -> Agent {
            assert(self.agent_exists.read(agent_address), TransferErrors::AGENT_NOT_FOUND);
            self.agents.read(agent_address)
        }
        fn get_agents_by_status(self: @ComponentState<TContractState>, status: AgentStatus, limit: u32, offset: u32) -> Array<Agent> {
            let mut agents = ArrayTrait::new();
            // Simplified: In production, maintain a separate agent index
            agents
        }
        fn get_agents_by_region(self: @ComponentState<TContractState>, region: felt252, limit: u32, offset: u32) -> Array<Agent> {
            let mut agents = ArrayTrait::new();
            let total_count = self.agent_region_count.read(region);
            let mut i = offset;
            let mut count = 0;
            while i != total_count && count != limit {
            let agent_address = self.agent_by_region.read((region, i));
            let agent = self.agents.read(agent_address);
            agents.append(agent);
            count += 1;
            i += 1;
            }
            agents
        }
        fn is_agent_authorized(self: @ComponentState<TContractState>, agent: ContractAddress, transfer_id: u256) -> bool {
            if !self.agent_exists.read(agent) {
                return false;
            }
            let agent_data = self.agents.read(agent);
            if agent_data.status != AgentStatus::Active {
                return false;
            }
            // In a real contract, check if agent is assigned to the transfer
            true
        }
        fn assign_agent_to_transfer(ref self: ComponentState<TContractState>, transfer_id: u256, agent: ContractAddress) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            assert(self.agent_exists.read(agent), TransferErrors::AGENT_NOT_FOUND);
            let agent_data = self.agents.read(agent);
            assert(agent_data.status == AgentStatus::Active, TransferErrors::AGENT_NOT_ACTIVE);
            // In a real contract, update the transfer's assigned_agent field
            self.emit(Event::AgentAssigned(AgentAssigned {
                transfer_id,
                agent,
                assigned_by: caller,
                timestamp: current_time,
            }));
            true
        }
    }

}
