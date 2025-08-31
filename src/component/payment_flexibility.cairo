use starknet::ContractAddress;
use starkremit_contract::base::types::{RoundStatus, RoundData};
use starkremit_contract::base::errors::PaymentFlexibilityErrors;

// Trait that the main contract must implement to provide data access
pub trait IMainContractData<TContractState> {
    fn get_round_data(self: @TContractState, round_id: u256) -> RoundData;
    fn get_member_status(self: @TContractState, member: ContractAddress) -> bool;
    fn get_member_count(self: @TContractState) -> u32;
    fn get_member_by_index(self: @TContractState, index: u32) -> ContractAddress;
}

#[starknet::interface]
pub trait IPaymentFlexibility<TContractState> {
    // Configuration and query functions (simple operations)
    fn get_payment_config(self: @TContractState) -> PaymentConfig;
    fn get_auto_payment_setup(self: @TContractState, member: ContractAddress) -> AutoPaymentSetup;
    fn get_payment_status(self: @TContractState, member: ContractAddress, round_id: u256) -> PaymentStatus;
    fn get_supported_tokens(self: @TContractState) -> Array<ContractAddress>;
    fn is_token_supported(self: @TContractState, token: ContractAddress) -> bool;
    
    // Utility functions (simple operations)
    fn get_grace_period_extension(self: @TContractState, member: ContractAddress) -> u64;
    fn get_early_payment_discount(self: @TContractState, amount: u256) -> u256;
}

// Data structures for payment flexibility functionality
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PaymentConfig {
    pub grace_period_hours: u64,
    pub early_payment_discount_basis_points: u256, // E.g., 500 for 5%
    pub auto_payment_enabled: bool,
    pub usd_oracle_address: ContractAddress,
    pub max_grace_period_extension: u64, // Maximum extension in hours
    pub min_early_payment_days: u64, // Minimum days before deadline for early payment
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub enum PaymentFrequency {
    Once,
    Daily,
    Weekly,
    Monthly,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct AutoPaymentSetup {
    pub member: ContractAddress,
    pub token: ContractAddress,
    pub amount: u256,
    pub frequency: PaymentFrequency,
    pub next_payment_date: u64,
    pub is_active: bool,
    pub created_at: u64,
    pub last_payment_date: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub enum PaymentStatus {
    Pending,
    Paid,
    Late,
    Missed,
    Overpaid,
    Early,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PaymentRecord {
    pub member: ContractAddress,
    pub round_id: u256,
    pub amount: u256,
    pub token: ContractAddress,
    pub payment_date: u64,
    pub status: PaymentStatus,
    pub is_early_payment: bool,
    pub discount_applied: u256,
    pub grace_period_used: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct EarlyPaymentInfo {
    pub member: ContractAddress,
    pub round_id: u256,
    pub original_amount: u256,
    pub discount_amount: u256,
    pub final_amount: u256,
    pub payment_date: u64,
}

#[starknet::component]
pub mod payment_flexibility_component {
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapReadAccess, StorageMapWriteAccess,
    };
    use core::array::ArrayTrait;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use super::{PaymentConfig, PaymentFrequency, AutoPaymentSetup, PaymentStatus, PaymentRecord, EarlyPaymentInfo, IMainContractData};
    use starkremit_contract::base::errors::PaymentFlexibilityErrors;
    use super::*;

    const SECONDS_PER_HOUR: u64 = 3600;
    const SECONDS_PER_DAY: u64 = 86400;
    const BASIS_POINTS: u256 = 10000;

    #[storage]
    pub struct Storage {
        payment_config: PaymentConfig,
        auto_payment_setups: Map<ContractAddress, AutoPaymentSetup>,
        payment_records: Map<(ContractAddress, u256), PaymentRecord>, // (member, round_id) -> record
        supported_tokens: Map<u32, ContractAddress>, // Index -> Token
        supported_tokens_count: u32,
        early_payments: Map<u256, EarlyPaymentInfo>, // round_id -> early payment info
        grace_period_extensions: Map<ContractAddress, u64>, // member -> extension hours
        admin: ContractAddress,
        last_auto_payment_processing: u64,
        auto_payment_interval: u64, // How often to process auto-payments
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AutoPaymentSetup: AutoPaymentSetupEvent,
        EarlyPaymentProcessed: EarlyPaymentProcessed,
        GracePeriodExtended: GracePeriodExtended,
        TokenValueConverted: TokenValueConverted,
        PaymentStatusUpdated: PaymentStatusUpdated,
        AutoPaymentExecuted: AutoPaymentExecuted,
        SupportedTokenAdded: SupportedTokenAdded,
        SupportedTokenRemoved: SupportedTokenRemoved,
        PaymentConfigUpdated: PaymentConfigUpdated,
        GracePeriodUsed: GracePeriodUsed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AutoPaymentSetupEvent {
        member: ContractAddress,
        token: ContractAddress,
        amount: u256,
        frequency: PaymentFrequency,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EarlyPaymentProcessed {
        member: ContractAddress,
        round_id: u256,
        original_amount: u256,
        discount_amount: u256,
        final_amount: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GracePeriodExtended {
        member: ContractAddress,
        extension_hours: u64,
        new_deadline: u64,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenValueConverted {
        from_token: ContractAddress,
        to_token: ContractAddress,
        input_amount: u256,
        output_amount: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PaymentStatusUpdated {
        member: ContractAddress,
        round_id: u256,
        old_status: PaymentStatus,
        new_status: PaymentStatus,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AutoPaymentExecuted {
        member: ContractAddress,
        amount: u256,
        token: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SupportedTokenAdded {
        token: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct SupportedTokenRemoved {
        token: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PaymentConfigUpdated {
        admin: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GracePeriodUsed {
        member: ContractAddress,
        round_id: u256,
        extension_hours: u64,
        timestamp: u64,
    }

    #[embeddable_as(PaymentFlexibility)]
    impl PaymentFlexibilityImpl<
        TContractState, +HasComponent<TContractState>, +IMainContractData<TContractState>,
    > of super::IPaymentFlexibility<ComponentState<TContractState>> {
        
        fn get_payment_config(self: @ComponentState<TContractState>) -> PaymentConfig {
            self.payment_config.read()
        }

        fn get_auto_payment_setup(self: @ComponentState<TContractState>, member: ContractAddress) -> AutoPaymentSetup {
            self.auto_payment_setups.read(member)
        }

        fn get_payment_status(self: @ComponentState<TContractState>, member: ContractAddress, round_id: u256) -> PaymentStatus {
            self._calculate_payment_status(member, round_id)
        }

        fn get_supported_tokens(self: @ComponentState<TContractState>) -> Array<ContractAddress> {
            let mut tokens = ArrayTrait::new();
            let count = self.supported_tokens_count.read();
            let mut i = 0;
            while i < count {
                let token = self.supported_tokens.read(i);
                tokens.append(token);
                i += 1;
            }
            tokens
        }

        fn is_token_supported(self: @ComponentState<TContractState>, token: ContractAddress) -> bool {
            self._is_token_supported(token)
        }

        fn get_grace_period_extension(self: @ComponentState<TContractState>, member: ContractAddress) -> u64 {
            self.grace_period_extensions.read(member)
        }

        fn get_early_payment_discount(self: @ComponentState<TContractState>, amount: u256) -> u256 {
            let config = self.payment_config.read();
            (amount * config.early_payment_discount_basis_points) / BASIS_POINTS
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +IMainContractData<TContractState>,
    > of InternalTrait<TContractState> {
        
        fn initializer(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            self.admin.write(admin);
            
            // Set default payment configuration
            let default_config = PaymentConfig {
                grace_period_hours: 48, // 48 hours default grace period
                early_payment_discount_basis_points: 500, // 5% discount for early payments
                auto_payment_enabled: true,
                usd_oracle_address: 0.try_into().unwrap(), // No oracle by default
                max_grace_period_extension: 168, // Maximum 1 week extension
                min_early_payment_days: 7, // Minimum 7 days before deadline for early payment
            };
            self.payment_config.write(default_config);
            
            // Initialize auto-payment processing
            self.last_auto_payment_processing.write(get_block_timestamp());
            self.auto_payment_interval.write(3600); // Process every hour
            
            // Initialize supported tokens count
            self.supported_tokens_count.write(0);
        }

        // Internal function to assert that the caller is the admin
        fn _assert_admin(self: @ComponentState<TContractState>) {
            let admin: ContractAddress = self.admin.read();
            let caller: ContractAddress = get_caller_address();
            assert(caller == admin, PaymentFlexibilityErrors::NOT_ADMIN);
        }

        // Complex operations that will be called by the main contract
        fn _setup_auto_payment(
            ref self: ComponentState<TContractState>,
            member: ContractAddress,
            token: ContractAddress,
            amount: u256,
            frequency: PaymentFrequency,
        ) {
            let config = self.payment_config.read();
            assert(config.auto_payment_enabled, PaymentFlexibilityErrors::AUTO_PAYMENT_DISABLED);
            assert(amount > 0, PaymentFlexibilityErrors::INVALID_AMOUNT);
            assert(self._is_token_supported(token), PaymentFlexibilityErrors::INVALID_TOKEN);
            
            // Check if member already has auto-payment setup
            let existing_setup = self.auto_payment_setups.read(member);
            assert(!existing_setup.is_active, PaymentFlexibilityErrors::AUTO_PAYMENT_ACTIVE);
            
            // Calculate next payment date based on frequency
            let next_payment_date = self._calculate_next_payment_date(frequency);
            
            // Create auto-payment setup
            let auto_payment = AutoPaymentSetup {
                member,
                token,
                amount,
                frequency,
                next_payment_date,
                is_active: true,
                created_at: get_block_timestamp(),
                last_payment_date: 0,
            };
            
            self.auto_payment_setups.write(member, auto_payment);
            
            self.emit(Event::AutoPaymentSetup(AutoPaymentSetupEvent {
                member,
                token,
                amount,
                frequency,
                timestamp: get_block_timestamp(),
            }));
        }

        fn _process_early_payment(
            ref self: ComponentState<TContractState>,
            member: ContractAddress,
            round_id: u256,
            amount: u256,
        ) -> (u256, u256) {
            let config = self.payment_config.read();
            let contract_state = self.get_contract();
            let round = contract_state.get_round_data(round_id);
            
            // Validate round is active
            assert(round.status == RoundStatus::Active, PaymentFlexibilityErrors::ROUND_NOT_FOUND);
            
            // Check if payment is early enough to qualify for discount
            let current_time = get_block_timestamp();
            let days_until_deadline = (round.deadline - current_time) / SECONDS_PER_DAY;
            assert(days_until_deadline >= config.min_early_payment_days, PaymentFlexibilityErrors::INVALID_AMOUNT);
            
            // Calculate early payment discount
            let discount_amount = self._calculate_early_payment_discount(amount);
            let final_amount = amount - discount_amount;
            
            // Store early payment info
            let early_payment = EarlyPaymentInfo {
                member,
                round_id,
                original_amount: amount,
                discount_amount,
                final_amount,
                payment_date: current_time,
            };
            self.early_payments.write(round_id, early_payment);
            
            // Update payment record
            let payment_record = PaymentRecord {
                member,
                round_id,
                amount: final_amount,
                token: 0.try_into().unwrap(), // Default token
                payment_date: current_time,
                status: PaymentStatus::Early,
                is_early_payment: true,
                discount_applied: discount_amount,
                grace_period_used: 0,
            };
            self.payment_records.write((member, round_id), payment_record);
            
            self.emit(Event::EarlyPaymentProcessed(EarlyPaymentProcessed {
                member,
                round_id,
                original_amount: amount,
                discount_amount,
                final_amount,
                timestamp: current_time,
            }));
            
            (final_amount, discount_amount)
        }

        fn _extend_grace_period(
            ref self: ComponentState<TContractState>,
            member: ContractAddress,
            extension_hours: u64,
        ) {
            self._assert_admin();
            
            let config = self.payment_config.read();
            assert(extension_hours > 0, PaymentFlexibilityErrors::INVALID_AMOUNT);
            assert(extension_hours <= config.max_grace_period_extension, PaymentFlexibilityErrors::INVALID_AMOUNT);
            
            // Get current grace period extension
            let current_extension = self.grace_period_extensions.read(member);
            let new_extension = current_extension + extension_hours;
            
            // Update grace period extension
            self.grace_period_extensions.write(member, new_extension);
            
            self.emit(Event::GracePeriodExtended(GracePeriodExtended {
                member,
                extension_hours,
                new_deadline: get_block_timestamp() + (new_extension * SECONDS_PER_HOUR),
                timestamp: get_block_timestamp(),
            }));
        }

        fn _process_auto_payments(ref self: ComponentState<TContractState>) {
            let config = self.payment_config.read();
            if !config.auto_payment_enabled {
                return;
            }
            
            let current_time = get_block_timestamp();
            let last_processing = self.last_auto_payment_processing.read();
            let interval = self.auto_payment_interval.read();
            
            // Check if it's time to process auto-payments
            if current_time < last_processing + interval {
                return;
            }
            
            let mut processed_count = 0;
            let member_count = self._get_member_count();
            
            // Process auto-payments for all members
            let mut i = 0;
            while i < member_count {
                let member = self._get_member_by_index(i);
                let auto_setup = self.auto_payment_setups.read(member);
                
                if auto_setup.is_active && current_time >= auto_setup.next_payment_date {
                    // Execute auto-payment
                    self._execute_auto_payment(member, auto_setup);
                    processed_count += 1;
                }
                i += 1;
            }
            
            // Update last processing timestamp
            self.last_auto_payment_processing.write(current_time);
            
            if processed_count > 0_u32 {
                self.emit(Event::AutoPaymentExecuted(AutoPaymentExecuted {
                    member: 0.try_into().unwrap(), // Not applicable for bulk processing
                    amount: 0, // Not applicable for bulk processing
                    token: 0.try_into().unwrap(), // Not applicable for bulk processing
                    timestamp: current_time,
                }));
            }
        }

        fn _add_supported_token(ref self: ComponentState<TContractState>, token: ContractAddress) {
            self._assert_admin();
            
            // Check if token is already supported
            assert(!self._is_token_supported(token), PaymentFlexibilityErrors::INVALID_TOKEN);
            
            let count = self.supported_tokens_count.read();
            self.supported_tokens.write(count, token);
            self.supported_tokens_count.write(count + 1);
            
            self.emit(Event::SupportedTokenAdded(SupportedTokenAdded {
                token,
                timestamp: get_block_timestamp(),
            }));
        }

        fn _remove_supported_token(ref self: ComponentState<TContractState>, token: ContractAddress) {
            self._assert_admin();
            
            // Check if token is supported
            assert(self._is_token_supported(token), PaymentFlexibilityErrors::INVALID_TOKEN);
            
            // Find and remove token
            let count = self.supported_tokens_count.read();
            let mut i = 0;
            while i < count {
                let stored_token = self.supported_tokens.read(i);
                if stored_token == token {
                    // Remove by setting to zero address
                    self.supported_tokens.write(i, 0.try_into().unwrap());
                    break;
                }
                i += 1;
            }
            
            self.emit(Event::SupportedTokenRemoved(SupportedTokenRemoved {
                token,
                timestamp: get_block_timestamp(),
            }));
        }

        fn _update_payment_config(ref self: ComponentState<TContractState>, new_config: PaymentConfig) {
            self._assert_admin();
            
            let old_config = self.payment_config.read();
            self.payment_config.write(new_config);
            
            self.emit(Event::PaymentConfigUpdated(PaymentConfigUpdated {
                admin: get_caller_address(),
                timestamp: get_block_timestamp(),
            }));
        }

        // Helper functions
        fn _calculate_payment_status(
            self: @ComponentState<TContractState>,
            member: ContractAddress,
            round_id: u256,
        ) -> PaymentStatus {
            let contract_state = self.get_contract();
            let round = contract_state.get_round_data(round_id);
            let payment_record = self.payment_records.read((member, round_id));
            let current_time = get_block_timestamp();
            let config = self.payment_config.read();
            
            if payment_record.amount == 0 {
                // No payment made
                let grace_period_end = round.deadline + (config.grace_period_hours * SECONDS_PER_HOUR);
                let member_extension = self.grace_period_extensions.read(member);
                let extended_deadline = grace_period_end + (member_extension * SECONDS_PER_HOUR);
                
                if current_time > extended_deadline {
                    return PaymentStatus::Missed;
                } else if current_time > round.deadline {
                    return PaymentStatus::Late;
                } else {
                    return PaymentStatus::Pending;
                }
            } else {
                // Payment made
                if payment_record.is_early_payment {
                    return PaymentStatus::Early;
                } else if current_time <= round.deadline {
                    return PaymentStatus::Paid;
                } else if current_time <= round.deadline + (config.grace_period_hours * SECONDS_PER_HOUR) {
                    return PaymentStatus::Late;
                } else {
                    return PaymentStatus::Overpaid; // Payment made after grace period
                }
            }
        }

        fn _calculate_next_payment_date(self: @ComponentState<TContractState>, frequency: PaymentFrequency) -> u64 {
            let current_time = get_block_timestamp();
            
            match frequency {
                PaymentFrequency::Once => current_time,
                PaymentFrequency::Daily => current_time + SECONDS_PER_DAY,
                PaymentFrequency::Weekly => current_time + (SECONDS_PER_DAY * 7),
                PaymentFrequency::Monthly => current_time + (SECONDS_PER_DAY * 30),
            }
        }

        fn _calculate_early_payment_discount(self: @ComponentState<TContractState>, amount: u256) -> u256 {
            let config = self.payment_config.read();
            (amount * config.early_payment_discount_basis_points) / BASIS_POINTS
        }

        fn _is_token_supported(self: @ComponentState<TContractState>, token: ContractAddress) -> bool {
            let count = self.supported_tokens_count.read();
            let mut i = 0;
            while i < count {
                let supported_token = self.supported_tokens.read(i);
                if supported_token == token {
                    return true;
                }
                i += 1;
            }
            false
        }

        fn _execute_auto_payment(
            ref self: ComponentState<TContractState>,
            member: ContractAddress,
            mut auto_setup: AutoPaymentSetup,
        ) {
            // Update last payment date
            auto_setup.last_payment_date = get_block_timestamp();
            
            // Calculate next payment date
            auto_setup.next_payment_date = self._calculate_next_payment_date(auto_setup.frequency);
            
            // Save updated auto-payment setup
            self.auto_payment_setups.write(member, auto_setup);
            
            // Emit auto-payment executed event
            self.emit(Event::AutoPaymentExecuted(AutoPaymentExecuted {
                member,
                amount: auto_setup.amount,
                token: auto_setup.token,
                timestamp: get_block_timestamp(),
            }));
        }

        fn _get_member_count(self: @ComponentState<TContractState>) -> u32 {
            let contract_state = self.get_contract();
            contract_state.get_member_count()
        }

        fn _get_member_by_index(self: @ComponentState<TContractState>, index: u32) -> ContractAddress {
            let contract_state = self.get_contract();
            contract_state.get_member_by_index(index)
        }
    }
}
