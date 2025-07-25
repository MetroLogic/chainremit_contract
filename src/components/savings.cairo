use starknet::ContractAddress;
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use crate::base::events::savings::*;
use crate::base::types::savings::*;
#[starknet::interface]
pub trait ISavings<TContractState> {
    // Savings Group Functions
    fn create_group(ref self: TContractState, max_members: u8) -> u64;
    fn join_group(ref self: TContractState, group_id: u64);

    // Contribution Management (Savings-related)
    fn contribute_round(ref self: TContractState, round_id: u256, amount: u256);
    fn complete_round(ref self: TContractState, round_id: u256);
    fn add_round_to_schedule(ref self: TContractState, recipient: ContractAddress, deadline: u64);
    fn is_member(self: @TContractState, address: ContractAddress) -> bool;
    fn check_missed_contributions(ref self: TContractState, round_id: u256);
    fn get_all_members(self: @TContractState) -> Array<ContractAddress>;
    fn add_member(ref self: TContractState, address: ContractAddress);
    fn disburse_round_contribution(ref self: TContractState, round_id: u256);
}


#[starknet::component]
pub mod savings_component {
    use super::*;

    #[storage]
    struct Storage {
        // contribution storage
        rounds: Map<u256, ContributionRound>,
        member_contributions: Map<(u256, ContractAddress), MemberContribution>,
        rotation_schedule: Map<u256, ContractAddress>,
        round_ids: u256,
        contribution_deadline: u64,
        members: Map<ContractAddress, bool>,
        member_count: u32, //
        member_by_index: Map<u32, ContractAddress>,
        // Savings Group storage
        groups: Map<u64, SavingsGroup>, // Stores all savings groups by ID
        group_members: Map<(u64, ContractAddress), bool>, // True if user is member of given group
        group_count: u64 // Counter used to assign unique group IDs
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ContributionMade: ContributionMade,
        RoundDisbursed: RoundDisbursed,
        RoundCompleted: RoundCompleted,
        ContributionMissed: ContributionMissed,
        MemberAdded: MemberAdded,
        GroupCreated: GroupCreated, // New savings group created
        MemberJoined: MemberJoined // User joined a savings group
    }

    #[embeddable_as(Savings)]
    impl SavingsImpl<
        TContractState, +HasComponent<TContractState>,
    > of ISavings<ComponentState<TContractState>> {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {}
}
