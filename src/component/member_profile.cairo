use starknet::ContractAddress;
use starkremit_contract::base::types::MemberProfileData;

// Trait that the main contract must implement to provide data access
pub trait IMainContractData<TContractState> {
    fn get_member_status(self: @TContractState, member: ContractAddress) -> bool;
    fn get_member_count(self: @TContractState) -> u32;
    fn get_member_by_index(self: @TContractState, index: u32) -> ContractAddress;
}

#[starknet::interface]
pub trait IMemberProfile<TContractState> {
    fn create_member_profile(ref self: TContractState, member: ContractAddress);
    fn update_reliability_rating(ref self: TContractState, member: ContractAddress, new_rating: u8);
    fn get_member_profile(self: @TContractState, member: ContractAddress) -> MemberProfileData;
    fn add_to_waitlist(ref self: TContractState, member: ContractAddress);
    fn remove_from_waitlist(ref self: TContractState, member: ContractAddress) -> bool;
    fn get_waitlist_position(self: @TContractState, member: ContractAddress) -> u32;
    fn update_communication_preferences(
        ref self: TContractState, member: ContractAddress, preferences: felt252,
    );
    fn send_member_message(ref self: TContractState, member: ContractAddress, message: felt252);
}

#[starknet::component]
pub mod member_profile_component {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starkremit_contract::base::errors::MemberProfileComponentErrors;
    use super::*;


    #[storage]
    #[allow(starknet::invalid_storage_member_types)]
    pub struct Storage {
        member_profiles: Map<ContractAddress, MemberProfileData>,
        waitlist: Map<u32, ContractAddress>, // Index -> Address
        waitlist_length: u32,
        total_members: u32,
        admin: ContractAddress,
        member_messages: Map<(ContractAddress, u32), felt252>, // (member, message_index) -> message
        message_counts: Map<ContractAddress, u32> // member -> message_count
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ProfileCreated: ProfileCreated,
        ProfileUpdated: ProfileUpdated,
        ReliabilityRatingUpdated: ReliabilityRatingUpdated,
        MemberAddedToWaitlist: MemberAddedToWaitlist,
        MemberRemovedFromWaitlist: MemberRemovedFromWaitlist,
        CommunicationSent: CommunicationSent,
        ContributionRecorded: ContributionRecorded,
        MissedContributionRecorded: MissedContributionRecorded,
        PaymentMethodUpdated: PaymentMethodUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProfileCreated {
        member: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ProfileUpdated {
        member: ContractAddress,
        updated_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ReliabilityRatingUpdated {
        member: ContractAddress,
        old_rating: u8,
        new_rating: u8,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MemberAddedToWaitlist {
        member: ContractAddress,
        position: u32,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MemberRemovedFromWaitlist {
        member: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CommunicationSent {
        message_hash: felt252,
        recipients_count: u32,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContributionRecorded {
        member: ContractAddress,
        amount: u256,
        round_id: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MissedContributionRecorded {
        member: ContractAddress,
        round_id: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PaymentMethodUpdated {
        member: ContractAddress,
        old_method: felt252,
        new_method: felt252,
        timestamp: u64,
    }

    #[embeddable_as(MemberProfile)]
    pub impl MemberProfileImpl<
        TContractState, +HasComponent<TContractState>, +IMainContractData<TContractState>,
    > of IMemberProfile<ComponentState<TContractState>> {
        fn create_member_profile(
            ref self: ComponentState<TContractState>, member: ContractAddress,
        ) {
            // Check if profile already exists
            let existing_profile = self.member_profiles.read(member);
            assert(
                existing_profile.join_date == 0,
                MemberProfileComponentErrors::PROFILE_ALREADY_EXISTS,
            );

            let current_time = get_block_timestamp();
            let new_profile = MemberProfileData {
                join_date: current_time,
                total_contributions: 0,
                missed_contributions: 0,
                credit_score: 50, // Start with neutral score
                last_recipient_round: 0,
                reliability_rating: 50, // Start with neutral rating
                preferred_payment_method: 'DEFAULT',
                communication_preferences: 'ALL',
                is_on_waitlist: false,
                waitlist_position: 0,
                last_message_timestamp: 0,
            };

            self.member_profiles.write(member, new_profile);
            let total = self.total_members.read();
            self.total_members.write(total + 1);

            self.emit(Event::ProfileCreated(ProfileCreated { member, timestamp: current_time }));
        }

        fn update_reliability_rating(
            ref self: ComponentState<TContractState>, member: ContractAddress, new_rating: u8,
        ) {
            self._assert_admin();
            assert(new_rating <= 100, MemberProfileComponentErrors::INVALID_RATING);

            let mut profile = self.member_profiles.read(member);
            assert(profile.join_date != 0, MemberProfileComponentErrors::PROFILE_NOT_FOUND);

            let old_rating = profile.reliability_rating;
            profile.reliability_rating = new_rating;
            self.member_profiles.write(member, profile);

            self
                .emit(
                    Event::ReliabilityRatingUpdated(
                        ReliabilityRatingUpdated {
                            member, old_rating, new_rating, timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn get_member_profile(
            self: @ComponentState<TContractState>, member: ContractAddress,
        ) -> MemberProfileData {
            let profile = self.member_profiles.read(member);
            assert(profile.join_date != 0, MemberProfileComponentErrors::PROFILE_NOT_FOUND);
            profile
        }

        fn add_to_waitlist(ref self: ComponentState<TContractState>, member: ContractAddress) {
            let current_length = self.waitlist_length.read();
            self.waitlist.write(current_length, member);
            self.waitlist_length.write(current_length + 1);

            // Update member profile
            let mut profile = self.member_profiles.read(member);
            profile.is_on_waitlist = true;
            profile.waitlist_position = current_length + 1;
            self.member_profiles.write(member, profile);

            self
                .emit(
                    Event::MemberAddedToWaitlist(
                        MemberAddedToWaitlist {
                            member, position: current_length + 1, timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn remove_from_waitlist(
            ref self: ComponentState<TContractState>, member: ContractAddress,
        ) -> bool {
            let waitlist_length = self.waitlist_length.read();
            let mut found = false;
            let mut i = 0;

            // Find member in waitlist
            loop {
                if i >= waitlist_length {
                    break;
                }

                if self.waitlist.read(i) == member {
                    found = true;
                    // Shift remaining members
                    let mut j = i;
                    loop {
                        if j + 1 >= waitlist_length {
                            break;
                        }
                        let next_member = self.waitlist.read(j + 1);
                        self.waitlist.write(j, next_member);
                        j += 1;
                    }
                    // Update waitlist_position for shifted members' profiles
                    let mut k = i;
                    loop {
                        if k + 1 > waitlist_length {
                            break;
                        }
                        // Only indices up to waitlist_length - 2 are valid after shift
                        if k >= waitlist_length - 1 {
                            break;
                        }
                        let shifted_member = self.waitlist.read(k);
                        let mut shifted_profile = self.member_profiles.read(shifted_member);
                        shifted_profile.waitlist_position = k + 1;
                        self.member_profiles.write(shifted_member, shifted_profile);
                        k += 1;
                    }
                    break;
                }
                i += 1;
            }

            if found {
                self.waitlist_length.write(waitlist_length - 1);

                // Update member profile
                let mut profile = self.member_profiles.read(member);
                profile.is_on_waitlist = false;
                profile.waitlist_position = 0;
                self.member_profiles.write(member, profile);

                self
                    .emit(
                        Event::MemberRemovedFromWaitlist(
                            MemberRemovedFromWaitlist { member, timestamp: get_block_timestamp() },
                        ),
                    );
            }

            found
        }

        fn get_waitlist_position(
            self: @ComponentState<TContractState>, member: ContractAddress,
        ) -> u32 {
            let profile = self.member_profiles.read(member);
            if profile.is_on_waitlist {
                profile.waitlist_position
            } else {
                0
            }
        }

        fn update_communication_preferences(
            ref self: ComponentState<TContractState>, member: ContractAddress, preferences: felt252,
        ) {
            let mut profile = self.member_profiles.read(member);
            assert(profile.join_date != 0, MemberProfileComponentErrors::PROFILE_NOT_FOUND);

            let old_preferences = profile.communication_preferences;
            profile.communication_preferences = preferences;
            self.member_profiles.write(member, profile);

            self
                .emit(
                    Event::CommunicationSent(
                        CommunicationSent {
                            message_hash: preferences,
                            recipients_count: 1,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn send_member_message(
            ref self: ComponentState<TContractState>, member: ContractAddress, message: felt252,
        ) {
            let mut profile = self.member_profiles.read(member);
            assert(profile.join_date != 0, MemberProfileComponentErrors::PROFILE_NOT_FOUND);

            // Store message
            let message_count = self.message_counts.read(member);
            self.member_messages.write((member, message_count), message);
            self.message_counts.write(member, message_count + 1);

            // Update last message timestamp
            profile.last_message_timestamp = get_block_timestamp();
            self.member_profiles.write(member, profile);

            self
                .emit(
                    Event::CommunicationSent(
                        CommunicationSent {
                            message_hash: message,
                            recipients_count: 1,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +IMainContractData<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            self.admin.write(admin);
            self.total_members.write(0);
            self.waitlist_length.write(0);
        }

        fn _assert_admin(self: @ComponentState<TContractState>) {
            let admin = self.admin.read();
            assert(get_caller_address() == admin, MemberProfileComponentErrors::NOT_ADMIN);
        }

        fn _calculate_credit_score(
            self: @ComponentState<TContractState>, profile: @MemberProfileData,
        ) -> u8 {
            // Simple credit score calculation based on contributions vs missed
            let total_rounds: u256 = *profile.total_contributions
                + (*profile.missed_contributions).into();
            if total_rounds == 0 {
                return 50; // Neutral score for new members
            }

            let success_rate: u256 = (*profile.total_contributions * 100_u256) / total_rounds;
            success_rate.try_into().unwrap_or(50)
        }

        fn _update_contribution_stats(
            ref self: ComponentState<TContractState>, member: ContractAddress, amount: u256,
        ) {
            let mut profile = self.member_profiles.read(member);
            profile.total_contributions += amount;
            profile.credit_score = self._calculate_credit_score(@profile);
            self.member_profiles.write(member, profile);
        }
    }
}
