use openzeppelin::access::accesscontrol::AccessControlComponent;
use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
use crate::components::agent_management::AgentManagementEvents::AgentRegistered;
use crate::components::agent_management::AgentManagementTypes::{Agent, AgentStatus};
use crate::components::agent_management::IAgentManagement::IAgentManagement;
use crate::components::transfer_management::TransferManagementErrors::TransferErrors::AGENT_ALREADY_EXISTS;
#[starknet::component]
pub mod AgentManagementComponent {
    use super::*;
    const ADMIN_ROLE: felt252 = selector!("ADMIN");


    #[storage]
    pub struct Storage {
        agents: Map<ContractAddress, Agent>, // Agent address to Agent mapping
        agent_exists: Map<ContractAddress, bool>, // Check if agent exists
        agent_by_region: Map<
            (felt252, u32), ContractAddress,
        >, // Agents by region (region, index) -> agent_address
        agent_region_count: Map<felt252, u32> // Count of agents by region
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        AgentRegistered: AgentRegistered,
    }

    #[embeddable_as(AgentManagement)]
    impl AgentManagementImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl AccessControl: AccessControlComponent::HasComponent<TContractState>,
        impl AccessControlInternal: AccessControlComponent::InternalImpl::HasComponent<TContractState>,
    > of IAgentManagement<ComponentState<TContractState>> {
        fn register_agent(
            ref self: ComponentState<TContractState>,
            agent_address: ContractAddress,
            name: felt252,
            primary_region: felt252,
            secondary_region: felt252,
            commission_rate: u256,
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let access_control_comp = get_dep_component!(@self, AccessControl);
            access_control_comp.assert_only_role(ADMIN_ROLE);
            assert(!self.agent_exists.read(agent_address), AGENT_ALREADY_EXISTS);

            let agent = Agent {
                agent_address,
                name,
                status: AgentStatus::Active,
                // primary_currency,
                // secondary_currency,
                primary_region,
                secondary_region,
                commission_rate,
                completed_transactions: 0,
                total_volume: 0,
                registered_at: current_time,
                last_active: current_time,
                rating: 1000 // Default rating
            };

            // Store agent
            self.agents.write(agent_address, agent);
            self.agent_exists.write(agent_address, true);

            // Update region indices for primary region
            if primary_region != 0 {
                let region_count = self.agent_region_count.read(primary_region);
                self.agent_by_region.write((primary_region, region_count), agent_address);
                self.agent_region_count.write(primary_region, region_count + 1);
            }

            // Update region indices for secondary region if provided
            if secondary_region != 0 {
                let region_count = self.agent_region_count.read(secondary_region);
                self.agent_by_region.write((secondary_region, region_count), agent_address);
                self.agent_region_count.write(secondary_region, region_count + 1);
            }

            // Emit event
            self
                .emit(
                    AgentRegistered {
                        agent_address,
                        name,
                        commission_rate,
                        registered_by: caller,
                        timestamp: current_time,
                    },
                );

            true
        }
    }
}
