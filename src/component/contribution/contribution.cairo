use starknet::ContractAddress;
use starkremit_contract::base::errors::ContributionErrors;
use starkremit_contract::base::types::{ContributionRound, MemberContribution, RoundStatus};

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


    fn get_member_contribution_history(
        self: @TContractState, member: ContractAddress, limit: u32, offset: u32,
    ) -> Array<MemberContribution>;
    fn get_round_statistics(
        self: @TContractState, round_id: u256,
    ) -> (u256, u32, u32); // total_amount, contributor_count, member_count
    fn validate_contribution_eligibility(
        self: @TContractState, member: ContractAddress, round_id: u256,
    ) -> bool;
    fn get_next_recipient(ref self: TContractState) -> ContractAddress;
    fn advance_round_rotation(ref self: TContractState);
}

#[starknet::component]
pub mod contribution_component {
    use core::num::traits::Zero;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::access::ownable::OwnableComponent::OwnableImpl;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use starkremit_contract::base::errors::ContributionErrors;
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
        required_contribution: u256,
        member_index_map: Map<ContractAddress, u32>,
        erc20_address: ContractAddress,
        // Enhanced storage
        member_contribution_history: Map<
            (ContractAddress, u32), u256,
        >, // member -> (index -> round_id)
        member_contribution_count: Map<ContractAddress, u32>, // member -> total contributions
        current_rotation_index: u32, // Current position in member rotation
        round_contributor_count: Map<u256, u32>, // round_id -> number of contributors
        member_last_contribution: Map<
            ContractAddress, u64,
        >, // member -> last contribution timestamp
        contribution_limits: Map<ContractAddress, u256>, // member -> max contribution per round
        grace_period_hours: u64 // Grace period for late contributions
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
        ContributionLimitUpdated: ContributionLimitUpdated,
        GracePeriodUpdated: GracePeriodUpdated,
        RoundRotationAdvanced: RoundRotationAdvanced,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContributionMade {
        round_id: u256,
        member: ContractAddress,
        amount: u256,
        timestamp: u64,
        is_on_time: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoundDisbursed {
        round_id: u256,
        recipient: ContractAddress,
        amount: u256,
        contributor_count: u32,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoundCompleted {
        round_id: u256,
        total_amount: u256,
        contributor_count: u32,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContributionMissed {
        round_id: u256,
        member: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MemberAdded {
        member: ContractAddress,
        added_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MemberRemoved {
        member: ContractAddress,
        removed_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RequiredContributionUpdated {
        old_amount: u256,
        new_amount: u256,
        updated_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContributionLimitUpdated {
        member: ContractAddress,
        old_limit: u256,
        new_limit: u256,
        updated_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GracePeriodUpdated {
        old_hours: u64,
        new_hours: u64,
        updated_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoundRotationAdvanced {
        old_index: u32,
        new_index: u32,
        next_recipient: ContractAddress,
        timestamp: u64,
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
            let current_time = get_block_timestamp();

            // Validate caller is a member
            assert(self.is_member(caller), ContributionErrors::NOT_MEMBER);

            // Prevent double contributions
            let existing_contribution = self.member_contributions.read((round_id, caller));
            assert(existing_contribution.amount == 0, ContributionErrors::ALREADY_CONTRIBUTED);

            let mut round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, ContributionErrors::ROUND_NOT_ACTIVE);

            // Check if contribution is within grace period
            let grace_period = self.grace_period_hours.read() * 3600; // Convert to seconds
            let is_on_time = current_time <= round.deadline + grace_period;
            assert(is_on_time, ContributionErrors::CONTRIBUTION_DEADLINE_PASSED);

            // Validate contribution amount
            let required_amount = self.required_contribution.read();
            assert(amount >= required_amount, ContributionErrors::INSUFFICIENT_AMOUNT);

            // Check contribution limits
            let member_limit = self.contribution_limits.read(caller);
            if member_limit > 0 {
                assert(amount <= member_limit, ContributionErrors::CONTRIBUTION_LIMIT_EXCEEDED);
            }

            // Create contribution record
            let contribution = MemberContribution {
                member: caller, amount, contributed_at: current_time,
            };
            self.member_contributions.write((round_id, caller), contribution);

            // Update round statistics
            round.total_contributions += amount;
            self.rounds.write(round_id, round);

            // Update contributor count
            let contributor_count = self.round_contributor_count.read(round_id);
            self.round_contributor_count.write(round_id, contributor_count + 1);

            // Update member statistics
            let member_contribution_count = self.member_contribution_count.read(caller);
            self.member_contribution_count.write(caller, member_contribution_count + 1);
            self.member_last_contribution.write(caller, current_time);

            // Add to member's contribution history
            let history_count = self.member_contribution_count.read(caller);
            self.member_contribution_history.write((caller, history_count - 1), round_id);

            // Token transfer
            let erc20_address = self.erc20_address.read();
            IERC20Dispatcher { contract_address: erc20_address }
                .transfer_from(caller, get_contract_address(), amount);

            self
                .emit(
                    Event::ContributionMade(
                        ContributionMade {
                            round_id,
                            member: caller,
                            amount,
                            timestamp: current_time,
                            is_on_time: current_time <= round.deadline,
                        },
                    ),
                );
        }

        fn complete_round(ref self: ComponentState<TContractState>, round_id: u256) {
            self.is_owner();

            let mut round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, ContributionErrors::ROUND_NOT_ACTIVE);

            let current_time = get_block_timestamp();
            round.status = RoundStatus::Completed;
            round.completed_at = current_time;
            self.rounds.write(round_id, round);

            let contributor_count = self.round_contributor_count.read(round_id);

            self
                .emit(
                    Event::RoundCompleted(
                        RoundCompleted {
                            round_id,
                            total_amount: round.total_contributions,
                            contributor_count,
                            timestamp: current_time,
                        },
                    ),
                );
        }

        fn add_round_to_schedule(
            ref self: ComponentState<TContractState>, recipient: ContractAddress, deadline: u64,
        ) {
            self.is_owner();

            // Validate recipient is a member
            assert(self.is_member(recipient), ContributionErrors::RECIPIENT_NOT_MEMBER);

            // Validate deadline is in the future
            assert(deadline > get_block_timestamp(), ContributionErrors::DEADLINE_NOT_IN_FUTURE);

            let round_id = self.round_ids.read() + 1;
            self.round_ids.write(round_id);
            self.rotation_schedule.write(round_id, recipient);

            let round = ContributionRound {
                round_id,
                recipient,
                deadline,
                completed_at: 0,
                total_contributions: 0,
                status: RoundStatus::Active,
            };
            self.rounds.write(round_id, round);

            // Initialize contributor count
            self.round_contributor_count.write(round_id, 0);
        }

        fn is_member(self: @ComponentState<TContractState>, address: ContractAddress) -> bool {
            self.members.read(address)
        }

        fn check_missed_contributions(ref self: ComponentState<TContractState>, round_id: u256) {
            let round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, ContributionErrors::ROUND_NOT_ACTIVE);

            let current_time = get_block_timestamp();
            let grace_period = self.grace_period_hours.read() * 3600;
            assert(
                current_time > round.deadline + grace_period,
                ContributionErrors::ROUND_DEADLINE_NOT_PASSED,
            );

            // Check all members for missed contributions
            let all_members = self.get_all_members();
            let mut i = 0;
            while i < all_members.len() {
                let member = *all_members[i];
                let contribution = self.member_contributions.read((round_id, member));
                if contribution.amount == 0 {
                    self
                        .emit(
                            Event::ContributionMissed(
                                ContributionMissed {
                                    round_id, member: member, timestamp: current_time,
                                },
                            ),
                        );
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

                i += 1;
            }
            members.span()
        }

        fn add_member(ref self: ComponentState<TContractState>, address: ContractAddress) {
            self.is_owner();

            // Validate address is not zero
            assert(!address.is_zero(), ContributionErrors::INVALID_ADDRESS);

            assert(!self.is_member(address), ContributionErrors::ALREADY_MEMBER);
            self.members.write(address, true);
            let count = self.member_count.read();
            self.member_by_index.write(count, address);

            // Track member index for efficient removal
            self.member_index_map.write(address, count);

            self.member_count.write(count + 1);

            // Initialize member statistics
            self.member_contribution_count.write(address, 0);
            self.member_last_contribution.write(address, 0);

            self
                .emit(
                    Event::MemberAdded(
                        MemberAdded {
                            member: address,
                            added_by: get_caller_address(),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn disburse_round_contribution(ref self: ComponentState<TContractState>, round_id: u256) {
            self.is_owner();

            let round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Completed, ContributionErrors::ROUND_NOT_COMPLETED);

            let current_time = get_block_timestamp();
            let contributor_count = self.round_contributor_count.read(round_id);

            // Token transfer to recipient
            let erc20_address = self.erc20_address.read();
            IERC20Dispatcher { contract_address: erc20_address }
                .transfer(round.recipient, round.total_contributions);

            self
                .emit(
                    Event::RoundDisbursed(
                        RoundDisbursed {
                            round_id,
                            recipient: round.recipient,
                            amount: round.total_contributions,
                            contributor_count,
                            timestamp: current_time,
                        },
                    ),
                );
        }

        fn remove_member(ref self: ComponentState<TContractState>, address: ContractAddress) {
            self.is_owner();

            assert(self.is_member(address), ContributionErrors::NOT_MEMBER);

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

            self
                .emit(
                    Event::MemberRemoved(
                        MemberRemoved {
                            member: address,
                            removed_by: get_caller_address(),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
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

            self
                .emit(
                    Event::RequiredContributionUpdated(
                        RequiredContributionUpdated {
                            old_amount,
                            new_amount: amount,
                            updated_by: get_caller_address(),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn get_required_contribution(self: @ComponentState<TContractState>) -> u256 {
            self.required_contribution.read()
        }

        // Enhanced functions
        fn get_member_contribution_history(
            self: @ComponentState<TContractState>, member: ContractAddress, limit: u32, offset: u32,
        ) -> Array<MemberContribution> {
            let mut contributions = ArrayTrait::new();
            let total_count = self.member_contribution_count.read(member);

            let mut i = offset;
            let mut count = 0;

            while i < total_count && count < limit {
                let round_id = self.member_contribution_history.read((member, i));
                if round_id > 0 {
                    let contribution = self.member_contributions.read((round_id, member));
                    contributions.append(contribution);
                    count += 1;
                }
                i += 1;
            }

            contributions
        }

        fn get_round_statistics(
            self: @ComponentState<TContractState>, round_id: u256,
        ) -> (u256, u32, u32) {
            let round = self.rounds.read(round_id);
            let contributor_count = self.round_contributor_count.read(round_id);
            let member_count = self.member_count.read();

            (round.total_contributions, contributor_count, member_count)
        }

        fn validate_contribution_eligibility(
            self: @ComponentState<TContractState>, member: ContractAddress, round_id: u256,
        ) -> bool {
            // Check if member exists and is active
            if !self.is_member(member) {
                return false;
            }

            // Check if round is active
            let round = self.rounds.read(round_id);
            if round.status != RoundStatus::Active {
                return false;
            }

            // Check if member already contributed
            let contribution = self.member_contributions.read((round_id, member));
            if contribution.amount > 0 {
                return false;
            }

            // Check if deadline hasn't passed (including grace period)
            let current_time = get_block_timestamp();
            let grace_period = self.grace_period_hours.read() * 3600;
            if current_time > round.deadline + grace_period {
                return false;
            }

            true
        }

        fn get_next_recipient(ref self: ComponentState<TContractState>) -> ContractAddress {
            let member_count = self.member_count.read();
            if member_count == 0 {
                return 0.try_into().unwrap();
            }

            // Start scanning from the next index after the current rotation index
            let current_index = self.current_rotation_index.read();
            let start_index = (current_index + 1) % member_count;

            // Scan up to member_count entries to find the first active member
            let mut scanned = 0_u32;
            while scanned < member_count {
                let candidate_index = (start_index + scanned) % member_count;
                let candidate = self.member_by_index.read(candidate_index);
                if self.is_member(candidate) {
                    // Advance rotation to the found active member and return it
                    self.current_rotation_index.write(candidate_index);
                    return candidate;
                }
                scanned += 1_u32;
            }

            // If no active member found, return zero address
            0.try_into().unwrap()
        }

        fn advance_round_rotation(ref self: ComponentState<TContractState>) {
            self.is_owner();

            let member_count = self.member_count.read();
            if member_count == 0 {
                return;
            }

            let current_index = self.current_rotation_index.read();
            let start_index = (current_index + 1) % member_count;

            // Scan up to member_count entries to find the first active member
            let mut scanned = 0_u32;
            let mut found = false;
            let mut found_index = current_index; // default to current if none found
            let mut next_recipient: ContractAddress = 0.try_into().unwrap();

            while scanned < member_count {
                let candidate_index = (start_index + scanned) % member_count;
                let candidate = self.member_by_index.read(candidate_index);
                if self.is_member(candidate) {
                    found = true;
                    found_index = candidate_index;
                    next_recipient = candidate;
                    break;
                }
                scanned += 1_u32;
            }

            // If no active member is found, do not change the index
            if !found {
                return;
            }

            self.current_rotation_index.write(found_index);

            self
                .emit(
                    Event::RoundRotationAdvanced(
                        RoundRotationAdvanced {
                            old_index: current_index,
                            new_index: found_index,
                            next_recipient,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Owner: OwnableComponent::HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, token_address: ContractAddress) {
            self.erc20_address.write(token_address);
            self.grace_period_hours.write(24); // Default 24 hours grace period
        }

        fn is_owner(self: @ComponentState<TContractState>) {
            let owner_comp = get_dep_component!(self, Owner);
            let owner = owner_comp.owner();
            assert(owner == get_caller_address(), ContributionErrors::NOT_OWNER);
        }
    }
}
