use starknet::ContractAddress;
#[starknet::interface]
pub trait IContribution<TContractState> {
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
pub mod contribution_component {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starkremit_contract::base::types::{ContributionRound, MemberContribution, RoundStatus};
    use super::*;
    #[storage]
    pub struct Storage {
        rounds: Map<u256, ContributionRound>,
        member_contributions: Map<(u256, ContractAddress), MemberContribution>,
        rotation_schedule: Map<u256, ContractAddress>,
        round_ids: u256,
        contribution_deadline: u64,
        members: Map<ContractAddress, bool>,
        member_count: u32,
        member_by_index: Map<u32, ContractAddress>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ContributionMade: ContributionMade,
        RoundDisbursed: RoundDisbursed,
        RoundCompleted: RoundCompleted,
        ContributionMissed: ContributionMissed,
        MemberAdded: MemberAdded,
    }
    #[derive(Drop, starknet::Event)]
    pub struct ContributionMade {
        round_id: u256,
        member: ContractAddress,
        amount: u256,
    }
    #[derive(Drop, starknet::Event)]
    pub struct RoundDisbursed {
        round_id: u256,
        recipient: ContractAddress,
        amount: u256,
    }
    #[derive(Drop, starknet::Event)]
    pub struct RoundCompleted {
        round_id: u256,
    }
    #[derive(Drop, starknet::Event)]
    pub struct ContributionMissed {
        round_id: u256,
        member: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    pub struct MemberAdded {
        member: ContractAddress,
    }

    #[embeddable_as(Contribution)]
    impl ContributionImpl<
        TContractState, +HasComponent<TContractState>,
    > of IContribution<ComponentState<TContractState>> {
        fn contribute_round(
            ref self: ComponentState<TContractState>, round_id: u256, amount: u256,
        ) {
            let caller = get_caller_address();
            assert(self.is_member(caller), 'Caller is not a member');
            let mut round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, 'Round is not active');
            assert(get_block_timestamp() <= round.deadline, 'Contribution deadline passed');
            let contribution = MemberContribution {
                member: caller, amount, contributed_at: get_block_timestamp(),
            };
            self.member_contributions.write((round_id, caller), contribution);
            round.total_contributions += amount;
            self.rounds.write(round_id, round);
            self
                .emit(
                    Event::ContributionMade(ContributionMade { round_id, member: caller, amount }),
                );
        }
        fn complete_round(ref self: ComponentState<TContractState>, round_id: u256) {
            let mut round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, 'Round is not active');
            round.status = RoundStatus::Completed;
            self.rounds.write(round_id, round);
            self.emit(Event::RoundCompleted(RoundCompleted { round_id }));
        }
        fn add_round_to_schedule(
            ref self: ComponentState<TContractState>, recipient: ContractAddress, deadline: u64,
        ) {
            let round_id = self.round_ids.read() + 1;
            self.round_ids.write(round_id);
            self.rotation_schedule.write(round_id, recipient);
            let round = ContributionRound {
                round_id, recipient, deadline, total_contributions: 0, status: RoundStatus::Active,
            };
            self.rounds.write(round_id, round);
        }
        fn is_member(self: @ComponentState<TContractState>, address: ContractAddress) -> bool {
            self.members.read(address)
        }
        fn check_missed_contributions(ref self: ComponentState<TContractState>, round_id: u256) {
            let round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, 'Round is not active');
            assert(get_block_timestamp() > round.deadline, 'Round deadline not passed');
        }
        fn get_all_members(self: @ComponentState<TContractState>) -> Array<ContractAddress> {
            let mut members = ArrayTrait::new();
            let count = self.member_count.read();
            let mut i = 0;
            while i != count {
                let member = self.member_by_index.read(i);
                members.append(member);
                i += 1;
            }
            members
        }
        fn add_member(ref self: ComponentState<TContractState>, address: ContractAddress) {
            assert(!self.is_member(address), 'Already a member');
            self.members.write(address, true);
            let count = self.member_count.read();
            self.member_by_index.write(count, address);
            self.member_count.write(count + 1);
            self.emit(Event::MemberAdded(MemberAdded { member: address }));
        }
        fn disburse_round_contribution(ref self: ComponentState<TContractState>, round_id: u256) {
            let round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Completed, 'Round not completed');
            self
                .emit(
                    Event::RoundDisbursed(
                        RoundDisbursed {
                            round_id, recipient: round.recipient, amount: round.total_contributions,
                        },
                    ),
                );
        }
    }
}
