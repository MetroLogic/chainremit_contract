use starknet::ContractAddress;
use starkremit_contract::base::types::{AutoScheduleConfig, RoundStatus, ScheduledRound};


// Trait that the main contract must implement to provide data access
pub trait IMainContractData<TContractState> {
    fn get_member_count(self: @TContractState) -> u32;
    fn get_member_by_index(self: @TContractState, index: u32) -> ContractAddress;
    fn get_current_round_id(self: @TContractState) -> u256;
    fn create_round(ref self: TContractState, recipient: ContractAddress, deadline: u64) -> u256;
}

#[starknet::interface]
pub trait IAutoSchedule<TContractState> {
    // Configuration and query functions (simple operations)
    fn get_config(self: @TContractState) -> AutoScheduleConfig;
    fn get_scheduled_round(self: @TContractState, round_id: u256) -> ScheduledRound;
    fn get_next_scheduled_rounds(self: @TContractState, count: u8) -> Array<ScheduledRound>;
    fn get_current_rotation_index(self: @TContractState) -> u32;

    fn is_auto_schedule_enabled(self: @TContractState) -> bool;
    fn get_rotation_length(self: @TContractState) -> u32;
}

#[starknet::component]
pub mod auto_schedule_component {
    use core::array::ArrayTrait;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starkremit_contract::base::errors::AutoScheduleErrors;
    use starkremit_contract::base::types::RoundStatus;
    use super::{AutoScheduleConfig, IMainContractData, ScheduledRound};

    const SECONDS_PER_DAY: u64 = 86400;

    #[storage]
    pub struct Storage {
        config: AutoScheduleConfig,
        scheduled_rounds: Map<u256, ScheduledRound>,
        member_rotation: Map<u32, ContractAddress>, // Index -> Address
        rotation_length: u32,
        current_rotation_index: u32,
        next_round_id: u256,
        last_processed_round: u256,
        last_processed_timestamp: u64,
        admin: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AutoScheduleSetup: AutoScheduleSetup,
        RoundAutoActivated: RoundAutoActivated,
        RoundAutoCompleted: RoundAutoCompleted,
        ScheduleMaintained: ScheduleMaintained,
        RoundScheduleModified: RoundScheduleModified,
        ConfigUpdated: ConfigUpdated,
        ScheduleProcessed: ScheduleProcessed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AutoScheduleSetup {
        admin: ContractAddress,
        start_date: u64,
        round_duration_days: u64,
        rolling_schedule_count: u8,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoundAutoActivated {
        round_id: u256,
        recipient: ContractAddress,
        scheduled_start: u64,
        scheduled_deadline: u64,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoundAutoCompleted {
        round_id: u256,
        completed_at: u64,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ScheduleMaintained {
        rounds_created: u32,
        last_maintenance_timestamp: u64,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RoundScheduleModified {
        round_id: u256,
        old_deadline: u64,
        new_deadline: u64,
        modified_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ConfigUpdated {
        old_config: AutoScheduleConfig,
        new_config: AutoScheduleConfig,
        updated_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ScheduleProcessed {
        rounds_processed: u32,
        more_work_remaining: bool,
        timestamp: u64,
    }

    #[embeddable_as(AutoSchedule)]
    impl AutoScheduleImpl<
        TContractState, +HasComponent<TContractState>, +IMainContractData<TContractState>,
    > of super::IAutoSchedule<ComponentState<TContractState>> {
        fn get_config(self: @ComponentState<TContractState>) -> AutoScheduleConfig {
            self.config.read()
        }

        fn get_scheduled_round(
            self: @ComponentState<TContractState>, round_id: u256,
        ) -> ScheduledRound {
            self.scheduled_rounds.read(round_id)
        }

        fn get_next_scheduled_rounds(
            self: @ComponentState<TContractState>, count: u8,
        ) -> Array<ScheduledRound> {
            let mut rounds = ArrayTrait::new();
            let current_index = self.current_rotation_index.read();
            let mut rounds_added = 0_u8;

            // Get next scheduled rounds
            let mut i = 1_u256;
            while i <= self.next_round_id.read() && rounds_added < count.into() {
                let scheduled_round = self.scheduled_rounds.read(i);
                if scheduled_round.status == RoundStatus::Scheduled {
                    rounds.append(scheduled_round);
                    rounds_added += 1_u8;
                }
                i += 1_u256;
            }

            rounds
        }

        fn get_current_rotation_index(self: @ComponentState<TContractState>) -> u32 {
            self.current_rotation_index.read()
        }

        fn is_auto_schedule_enabled(self: @ComponentState<TContractState>) -> bool {
            let config = self.config.read();
            config.auto_activation_enabled
        }

        fn get_rotation_length(self: @ComponentState<TContractState>) -> u32 {
            self.rotation_length.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +IMainContractData<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            self.admin.write(admin);

            // Set default auto-schedule configuration
            let default_config = AutoScheduleConfig {
                round_duration_days: 30,
                start_date: get_block_timestamp(),
                auto_activation_enabled: true,
                auto_completion_enabled: true,
                rolling_schedule_count: 3,
            };
            self.config.write(default_config);

            // Initialize rotation system
            self.rotation_length.write(0);
            self.current_rotation_index.write(0);
            self.next_round_id.write(1);
            self.last_processed_round.write(1);
            self.last_processed_timestamp.write(get_block_timestamp());

            self
                .emit(
                    Event::AutoScheduleSetup(
                        AutoScheduleSetup {
                            admin,
                            start_date: default_config.start_date,
                            round_duration_days: default_config.round_duration_days,
                            rolling_schedule_count: default_config.rolling_schedule_count,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        // Internal function to assert that the caller is the admin
        fn _assert_admin(self: @ComponentState<TContractState>) {
            let admin: ContractAddress = self.admin.read();
            let caller: ContractAddress = get_caller_address();
            assert(caller == admin, AutoScheduleErrors::NOT_ADMIN);
        }

        // Complex operations that will be called by the main contract
        fn _setup_auto_schedule(
            ref self: ComponentState<TContractState>, config: AutoScheduleConfig,
        ) {
            self._assert_admin();

            let old_config = self.config.read();
            self.config.write(config);

            // Initialize member rotation if not already set
            if self.rotation_length.read() == 0 {
                self._initialize_member_rotation();
            }

            self
                .emit(
                    Event::ConfigUpdated(
                        ConfigUpdated {
                            old_config,
                            new_config: config,
                            updated_by: get_caller_address(),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn _maintain_rolling_schedule(ref self: ComponentState<TContractState>) {
            let config = self.config.read();
            let current_time = get_block_timestamp();
            let last_maintenance = self.last_processed_timestamp.read();

            // Check if maintenance is needed
            if current_time - last_maintenance < config.round_duration_days * SECONDS_PER_DAY {
                return;
            }

            let mut rounds_created = 0_u32;
            let mut current_index: u256 = self.next_round_id.read();

            // Create new rounds to maintain rolling schedule
            while rounds_created < config.rolling_schedule_count.into() {
                current_index += 1_u256;

                // Calculate timing for the new round
                let round_duration_seconds: u64 = config.round_duration_days * SECONDS_PER_DAY;
                let round_start = config.start_date
                    + ((current_index - 1_u256).try_into().unwrap() * round_duration_seconds);
                let round_deadline = round_start + round_duration_seconds;

                // Determine recipient by rotating through the member list
                let recipient = self._get_next_recipient();

                let scheduled_round = ScheduledRound {
                    round_id: current_index,
                    recipient,
                    scheduled_start: round_start,
                    scheduled_deadline: round_deadline,
                    status: RoundStatus::Scheduled,
                    auto_generated: true,
                };

                self.scheduled_rounds.write(current_index, scheduled_round);
                rounds_created += 1;
            }

            // Update indices for the next maintenance cycle
            self.next_round_id.write(current_index);
            self.last_processed_timestamp.write(current_time);

            self
                .emit(
                    Event::ScheduleMaintained(
                        ScheduleMaintained {
                            rounds_created: rounds_created.try_into().unwrap(),
                            last_maintenance_timestamp: current_time,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn _auto_activate_round(ref self: ComponentState<TContractState>, round_id: u256) {
            let config = self.config.read();
            if !config.auto_activation_enabled {
                return;
            }

            let mut scheduled_round = self.scheduled_rounds.read(round_id);
            if scheduled_round.status == RoundStatus::Scheduled {
                scheduled_round.status = RoundStatus::Active;
                self.scheduled_rounds.write(round_id, scheduled_round);

                self
                    .emit(
                        Event::RoundAutoActivated(
                            RoundAutoActivated {
                                round_id,
                                recipient: scheduled_round.recipient,
                                scheduled_start: scheduled_round.scheduled_start,
                                scheduled_deadline: scheduled_round.scheduled_deadline,
                                timestamp: get_block_timestamp(),
                            },
                        ),
                    );
            }
        }

        fn _auto_complete_expired_rounds(
            ref self: ComponentState<TContractState>, max_iterations: u32,
        ) -> (u32, bool) {
            let config = self.config.read();
            if !config.auto_completion_enabled {
                return (0, false);
            }

            let current_time = get_block_timestamp();
            let mut rounds_processed = 0_u32;

            // Determine batch limit
            let default_limit: u32 = 50;
            let limit: u32 = if max_iterations == 0 {
                default_limit
            } else {
                max_iterations
            };

            // Iterate starting from the last processed cursor with wrap-around
            let next_round_id = self.next_round_id.read();
            if next_round_id == 0_u256 {
                return (0, false);
            }
            let mut i = self.last_processed_round.read();
            if i < 1_u256 {
                i = 1_u256;
            }

            let mut iterated: u32 = 0;
            while i <= next_round_id && iterated < limit {
                let mut scheduled_round = self.scheduled_rounds.read(i);

                if scheduled_round.status == RoundStatus::Active
                    && scheduled_round.scheduled_deadline <= current_time {
                    scheduled_round.status = RoundStatus::Completed;
                    self.scheduled_rounds.write(i, scheduled_round);
                    rounds_processed += 1_u32;

                    self
                        .emit(
                            Event::RoundAutoCompleted(
                                RoundAutoCompleted {
                                    round_id: i,
                                    completed_at: current_time,
                                    timestamp: get_block_timestamp(),
                                },
                            ),
                        );
                }
                i += 1_u256;
                iterated += 1_u32;
            }

            // Update cursor: wrap to 1 if we've reached the end
            let mut more_work_remaining = false;
            if i <= next_round_id {
                more_work_remaining = true;
                self.last_processed_round.write(i);
            } else {
                self.last_processed_round.write(1);
            }

            self
                .emit(
                    Event::ScheduleProcessed(
                        ScheduleProcessed {
                            rounds_processed, more_work_remaining, timestamp: get_block_timestamp(),
                        },
                    ),
                );

            (rounds_processed, more_work_remaining)
        }

        fn _modify_schedule(
            ref self: ComponentState<TContractState>, round_id: u256, new_deadline: u64,
        ) {
            self._assert_admin();

            let mut scheduled_round = self.scheduled_rounds.read(round_id);
            let old_deadline = scheduled_round.scheduled_deadline;

            // Validate new deadline
            assert(
                new_deadline > get_block_timestamp(),
                AutoScheduleErrors::NEW_DEADLINE_NOT_IN_FUTURE,
            );
            assert(
                new_deadline > scheduled_round.scheduled_start,
                AutoScheduleErrors::NEW_DEADLINE_NOT_AFTER_START,
            );

            scheduled_round.scheduled_deadline = new_deadline;
            self.scheduled_rounds.write(round_id, scheduled_round);

            self
                .emit(
                    Event::RoundScheduleModified(
                        RoundScheduleModified {
                            round_id,
                            old_deadline,
                            new_deadline,
                            modified_by: get_caller_address(),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        // Helper functions
        fn _initialize_member_rotation(ref self: ComponentState<TContractState>) {
            let contract_state = self.get_contract();
            let member_count = contract_state.get_member_count();

            if member_count > 0 {
                self.rotation_length.write(member_count);

                // Populate rotation array
                let mut i = 0;
                while i < member_count {
                    let member = contract_state.get_member_by_index(i);
                    self.member_rotation.write(i, member);
                    i += 1;
                }
            }
        }

        fn _get_next_recipient(ref self: ComponentState<TContractState>) -> ContractAddress {
            let rotation_length = self.rotation_length.read();
            if rotation_length == 0 {
                return 0.try_into().unwrap();
            }

            let current_index = self.current_rotation_index.read();
            let recipient = self.member_rotation.read(current_index);
            let next_index = (current_index + 1_u32) % rotation_length;

            // Update rotation index after selecting the recipient
            self.current_rotation_index.write(next_index);

            recipient
        }
    }
}
