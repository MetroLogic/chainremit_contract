use starknet::ContractAddress;
use starkremit_contract::base::types::{ContributionRound, MemberContribution};

#[starknet::interface]
pub trait IContribution<TContractState> {
    fn contribute_round(ref self: TContractState, round_id: u256, amount: u256);
    fn complete_round(ref self: TContractState, round_id: u256);
    fn add_round_to_schedule(ref self: TContractState, recipient: ContractAddress, deadline: u64);
    fn is_member(self: @TContractState, address: ContractAddress) -> bool;
    fn check_missed_contributions(ref self: TContractState, round_id: u256);
    fn get_all_members(self: @TContractState) -> Span<ContractAddress>;
    fn add_member(ref self: TContractState, address: ContractAddress);
    fn disburse_round_contribution(ref self: TContractState, round_id: u256);

    fn remove_member(ref self: TContractState, address: ContractAddress);
    fn get_round_details(self: @TContractState, round_id: u256) -> ContributionRound;
    fn get_member_contribution(
        self: @TContractState, round_id: u256, member: ContractAddress,
    ) -> MemberContribution;
    fn get_current_round_id(self: @TContractState) -> u256;
    fn set_required_contribution(ref self: TContractState, amount: u256);
    fn get_required_contribution(self: @TContractState) -> u256;
}

#[starknet::component]
pub mod contribution_component {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::OwnableComponent::OwnableImpl;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use starkremit_contract::base::types::{ContributionRound, MemberContribution, RoundStatus};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
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
        required_contribution: u256,
        member_index_map: Map<ContractAddress, u32>, // Track member indices for efficient removal
        erc20_address: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ContributionMade: ContributionMade,
        RoundDisbursed: RoundDisbursed,
        RoundCompleted: RoundCompleted,
        ContributionMissed: ContributionMissed,
        MemberAdded: MemberAdded,
        MemberRemoved: MemberRemoved,
        RequiredContributionUpdated: RequiredContributionUpdated,
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

    #[derive(Drop, starknet::Event)]
    pub struct MemberRemoved {
        member: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    pub struct RequiredContributionUpdated {
        old_amount: u256,
        new_amount: u256,
    }

    #[embeddable_as(Contribution)]
    impl ContributionImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
    > of IContribution<ComponentState<TContractState>> {
        fn contribute_round(
            ref self: ComponentState<TContractState>, round_id: u256, amount: u256,
        ) {
            let caller = get_caller_address();
            assert(self.is_member(caller), 'Caller is not a member');

            // Prevent double contributions
            let existing_contribution = self.member_contributions.read((round_id, caller));
            assert(existing_contribution.amount == 0, 'Already contributed');

            let mut round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, 'Round is not active');
            assert(get_block_timestamp() <= round.deadline, 'Contribution deadline passed');

            // Validate contribution amount
            let required_amount = self.required_contribution.read();
            assert(amount >= required_amount, 'amount less than required');

            let contribution = MemberContribution {
                member: caller, amount, contributed_at: get_block_timestamp(),
            };
            self.member_contributions.write((round_id, caller), contribution);
            round.total_contributions += amount;
            self.rounds.write(round_id, round);

            // Token transfer
            let erc20_address = self.erc20_address.read();
            IERC20Dispatcher { contract_address: erc20_address }.transfer_from(
                caller, get_contract_address(), amount,
            );

            self
                .emit(
                    Event::ContributionMade(ContributionMade { round_id, member: caller, amount }),
                );
        }

        fn complete_round(ref self: ComponentState<TContractState>, round_id: u256) {
            self.is_owner();

            let mut round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, 'Round is not active');
            round.status = RoundStatus::Completed;
            self.rounds.write(round_id, round);
            self.emit(Event::RoundCompleted(RoundCompleted { round_id }));
        }

        fn add_round_to_schedule(
            ref self: ComponentState<TContractState>, recipient: ContractAddress, deadline: u64,
        ) {
            self.is_owner();

            // Validate recipient is a member
            assert(self.is_member(recipient), 'Recipient must be a member');

            // Validate deadline is in the future
            assert(deadline > get_block_timestamp(), 'Deadline not in the future');

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

            // Check all members for missed contributions
            let all_members = self.get_all_members();
            let mut i = 0;
            while i < all_members.len() {
                let member = *all_members[i];
                let contribution = self.member_contributions.read((round_id, member));
                if contribution.amount == 0 {
                    self.emit(ContributionMissed { round_id, member: member });
                }
                i += 1;
            }
        }

        fn get_all_members(self: @ComponentState<TContractState>) -> Span<ContractAddress> {
            let mut members = ArrayTrait::new();
            let count = self.member_count.read();
            let mut i = 0;
            while i != count {
                let member = self.member_by_index.read(i);

                // Filter out inactive/removed members
                if self.is_member(member) {
                    members.append(member);
                }

                members.append(member);
                i += 1;
            }
            members.span()
        }

        fn add_member(ref self: ComponentState<TContractState>, address: ContractAddress) {
            self.is_owner();

            // Validate address is not zero
            assert(!address.is_zero(), 'Invalid address');

            assert(!self.is_member(address), 'Already a member');
            self.members.write(address, true);
            let count = self.member_count.read();
            self.member_by_index.write(count, address);

            // Track member index for efficient removal
            self.member_index_map.write(address, count);

            self.member_count.write(count + 1);
            self.emit(MemberAdded { member: address });
        }

        fn disburse_round_contribution(ref self: ComponentState<TContractState>, round_id: u256) {
            self.is_owner();

            let round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Completed, 'Round not completed');

            // Token transfer to recipient
            let erc20_address = self.erc20_address.read();
            IERC20Dispatcher { contract_address: erc20_address }.transfer(
                round.recipient, round.total_contributions,
            );

            self
                .emit(
                    Event::RoundDisbursed(
                        RoundDisbursed {
                            round_id, recipient: round.recipient, amount: round.total_contributions,
                        },
                    ),
                );
        }

        fn remove_member(ref self: ComponentState<TContractState>, address: ContractAddress) {
            self.is_owner();

            assert(self.is_member(address), 'Not a member');

            // Remove from members mapping
            self.members.write(address, false);

            // Get member's index and reorganize array
            let member_index = self.member_index_map.read(address);
            let last_index = self.member_count.read() - 1;

            if member_index != last_index {
                // Move last member to removed member's position
                let last_member = self.member_by_index.read(last_index);
                self.member_by_index.write(member_index, last_member);
                self.member_index_map.write(last_member, member_index);
            }

            // Clear last position and update count
            self.member_by_index.write(last_index, 0.try_into().unwrap());
            self.member_count.write(last_index);
            self.member_index_map.write(address, 0);

            self.emit(MemberRemoved { member: address });
        }

        fn get_round_details(
            self: @ComponentState<TContractState>, round_id: u256,
        ) -> ContributionRound {
            self.rounds.read(round_id)
        }

        fn get_member_contribution(
            self: @ComponentState<TContractState>, round_id: u256, member: ContractAddress,
        ) -> MemberContribution {
            self.member_contributions.read((round_id, member))
        }

        fn get_current_round_id(self: @ComponentState<TContractState>) -> u256 {
            self.round_ids.read()
        }

        fn set_required_contribution(ref self: ComponentState<TContractState>, amount: u256) {
            self.is_owner();

            let old_amount = self.required_contribution.read();
            self.required_contribution.write(amount);

            self.emit(RequiredContributionUpdated { old_amount, new_amount: amount });
        }

        fn get_required_contribution(self: @ComponentState<TContractState>) -> u256 {
            self.required_contribution.read()
        }
    }

    #[generate_trait]
    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, token_address: ContractAddress) {
        self.erc20_address.write(token_address);
    }

        fn is_owner(self: @ComponentState<TContractState>) {
            let owner_comp = get_dep_component!(self, Owner);
            let owner = owner_comp.owner();
            assert(owner == get_caller_address(), 'Caller is not the owner');
        }
    }
}
