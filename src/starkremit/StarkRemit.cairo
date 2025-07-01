use core::num::traits::Zero;
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::introspection::src5::SRC5Component;
use openzeppelin::upgrades::UpgradeableComponent;
use openzeppelin::upgrades::interface::IUpgradeable;
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use starknet::{
    ContractAddress, contract_address_const, get_block_timestamp, get_caller_address,
    get_contract_address,
};
use starkremit_contract::base::errors::{
    ERC20Errors, GroupErrors, GovernanceErrors, KYCErrors, MintBurnErrors, RegistrationErrors, TransferErrors,
};
use starkremit_contract::base::events::*;
use starkremit_contract::base::types::{
        AdminRole, 
    Agent, AgentStatus, ContributionRound, KYCLevel, KycLevel, KycStatus, LoanRequest, LoanStatus,
    MemberContribution, RegistrationRequest, RegistrationStatus, RoundStatus, SavingsGroup,
    TransferData, TransferHistory, TransferStatus, ParameterBounds, ParameterHistory, TimelockChange,
        UserKycData, UserProfile,
,
    };
use starkremit_contract::interfaces::{IERC20, IGovernance, IStarkRemit};


const INTEREST_RATE: u256 = 500; // 5% in basis points (0.05 * 10000)
const LATE_PENALTY_RATE: u256 = 100; // 1% per day in basis points (0.01 * 10000)
const LOAN_TERM_DAYS: u64 = 30 * 24 * 60 * 60; // 30 days in seconds


#[starknet::contract]
pub mod StarkRemit {
    use super::*;

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: Src5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    const PROTOCOL_OWNER_ROLE: felt252 = selector!("PROTOCOL_OWNER");
    const ADMIN_ROLE: felt252 = selector!("ADMIN");
    // Fixed point scalar for accurate currency conversion calculations
    // Equivalent to 10^18, standard for 18 decimal places
    const FIXED_POINT_SCALER: u256 = 1_000_000_000_000_000_000;

    // Governance constants
    const TIMELOCK_DURATION: u64 = 172800; // 48 hours in seconds
    const MAX_TIMELOCK_DURATION: u64 = 604800; // 7 days in seconds

    // Event definitions
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        Src5Event: SRC5Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        Transfer: Transfer, // Standard ERC20 transfer event
        Approval: Approval, // Standard ERC20 approval event
        ExchangeRateUpdated: ExchangeRateUpdated, // Event for exchange rate updates
        TokenConverted: TokenConverted, // Event for token conversions
        UserRegistered: UserRegistered, // Event for user registration
        UserProfileUpdated: UserProfileUpdated, // Event for profile updates
        UserDeactivated: UserDeactivated, // Event for user deactivation
        UserReactivated: UserReactivated, // Event for user reactivation
        KYCLevelUpdated: KYCLevelUpdated, // Event for KYC level updates
        KycStatusUpdated: KycStatusUpdated, // Event for KYC status updates
        KycEnforcementEnabled: KycEnforcementEnabled, // Event for KYC enforcement
        // Transfer Administration Events
        TransferCreated: TransferCreated, // Event for transfer creation
        TransferCancelled: TransferCancelled, // Event for transfer cancellation
        TransferCompleted: TransferCompleted, // Event for transfer completion
        TransferPartialCompleted: TransferPartialCompleted, // Event for partial completion
        TransferExpired: TransferExpired, // Event for transfer expiry
        CashOutRequested: CashOutRequested, // Event for cash-out request
        CashOutCompleted: CashOutCompleted, // Event for cash-out completion
        AgentAssigned: AgentAssigned, // Event for agent assignment
        AgentRegistered: AgentRegistered, // Event for agent registration
        AgentStatusUpdated: AgentStatusUpdated, // Event for agent status updates
        TransferHistoryRecorded: TransferHistoryRecorded, // Event for history recording
        // contribution
        ContributionMade: ContributionMade,
        RoundDisbursed: RoundDisbursed,
        RoundCompleted: RoundCompleted,
        ContributionMissed: ContributionMissed,
        MemberAdded: MemberAdded,
        // Savings Group
        GroupCreated: GroupCreated, // New savings group created
        MemberJoined: MemberJoined, // User joined a savings group
        // Token Supply Events
        Minted: Minted,
        Burned: Burned,
        MinterAdded: MinterAdded,
        MinterRemoved: MinterRemoved,
        MaxSupplyUpdated: MaxSupplyUpdated,
        LoanRequested: LoanRequested,
        LatePayment: LatePayment,
        LoanRepaid: LoanRepaid,
        // loan_id -> timestamp_of_last_payment
    }

        KycEnforcementEnabled: KycEnforcementEnabled, // Event for KYC enforcement
        // Governance Events
        AdminRoleAssigned: AdminRoleAssigned,
        AdminRoleRevoked: AdminRoleRevoked,
        SystemParameterUpdated: SystemParameterUpdated,
        FeeUpdated: FeeUpdated,
        ContractRegistered: ContractRegistered,
        ContractUpdated: ContractUpdated,
        TimelockScheduled: TimelockScheduled,
        TimelockExecuted: TimelockExecuted,
        TimelockCancelled: TimelockCancelled,
        SystemPaused: SystemPaused,
        SystemUnpaused: SystemUnpaused,
        ParameterBoundsSet: ParameterBoundsSet,
    }

    // Standard ERC20 Transfer event
    // Emitted when tokens are transferred between addresses
    #[derive(Copy, Drop, starknet::Event)]
    pub struct Transfer {
        #[key]
        from: ContractAddress, // Source address
        #[key]
        to: ContractAddress, // Destination address
        value: u256 // Amount transferred
    }

    // Standard ERC20 Approval event
    // Emitted when approval is granted to spend tokens
    #[derive(Copy, Drop, starknet::Event)]
    pub struct Approval {
        #[key]
        owner: ContractAddress, // Token owner
        #[key]
        spender: ContractAddress, // Approved spender
        value: u256 // Approved amount
    }

    // Event emitted when a user is assigned a currency
    #[derive(Copy, Drop, starknet::Event)]
    pub struct CurrencyAssigned {
        #[key]
        user: ContractAddress, // User receiving the currency
        currency: felt252, // Currency identifier
        amount: u256 // Amount assigned
    }

    // Event emitted when a token is converted between currencies
    #[derive(Copy, Drop, starknet::Event)]
    pub struct TokenConverted {
        #[key]
        user: ContractAddress, // User performing the conversion
        from_currency: felt252, // Source currency
        to_currency: felt252, // Target currency
        amount_in: u256, // Input amount
        amount_out: u256 // Output amount after conversion
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct KycStatusUpdated {
        #[key]
        user: ContractAddress,
        old_status: KycStatus,
        new_status: KycStatus,
        old_level: KycLevel,
        new_level: KycLevel,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct KycEnforcementEnabled {
        enabled: bool,
        updated_by: ContractAddress,
    }

    // Governance Events
    #[derive(Copy, Drop, starknet::Event)]
    pub struct AdminRoleAssigned {
        #[key]
        user: ContractAddress,
        role: AdminRole,
        assigned_by: ContractAddress,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct AdminRoleRevoked {
        #[key]
        user: ContractAddress,
        old_role: AdminRole,
        revoked_by: ContractAddress,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct SystemParameterUpdated {
        #[key]
        key: felt252,
        old_value: u256,
        new_value: u256,
        updated_by: ContractAddress,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct FeeUpdated {
        #[key]
        fee_type: felt252,
        old_value: u256,
        new_value: u256,
        updated_by: ContractAddress,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct ContractRegistered {
        #[key]
        name: felt252,
        contract_address: ContractAddress,
        registered_by: ContractAddress,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct ContractUpdated {
        #[key]
        name: felt252,
        old_address: ContractAddress,
        new_address: ContractAddress,
        updated_by: ContractAddress,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct TimelockScheduled {
        #[key]
        key: felt252,
        value: u256,
        proposer: ContractAddress,
        executable_at: u64,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct TimelockExecuted {
        #[key]
        key: felt252,
        value: u256,
        executed_by: ContractAddress,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct TimelockCancelled {
        #[key]
        key: felt252,
        cancelled_by: ContractAddress,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct SystemPaused {
        paused_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct SystemUnpaused {
        unpaused_by: ContractAddress,
        timestamp: u64,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct ParameterBoundsSet {
        #[key]
        key: felt252,
        min_value: u256,
        max_value: u256,
        set_by: ContractAddress,
    }

    // Contract storage definition
    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        owner: ContractAddress, // Admin address for contract management
        oracle_address: ContractAddress, // Address of the oracle contract for exchange rates
        token_address: ContractAddress, // Address of the token contract
        // ERC20 standard storage
        admin: ContractAddress, // Admin with special privileges
        name: felt252, // Token name
        symbol: felt252, // Token symbol
        decimals: u8, // Token decimals (precision)
        total_supply: u256, // Total token supply
        balances: Map<ContractAddress, u256>, // User token balances
        allowances: Map<(ContractAddress, ContractAddress), u256>, // Spending allowances
        // User registration storage
        user_profiles: Map<ContractAddress, UserProfile>, // User profile data
        email_registry: Map<
            felt252, ContractAddress,
        >, // Email hash to address mapping for uniqueness
        phone_registry: Map<
            felt252, ContractAddress,
        >, // Phone hash to address mapping for uniqueness
        registration_status: Map<ContractAddress, RegistrationStatus>, // User registration status
        total_users: u256, // Total number of registered users
        registration_enabled: bool, // Whether registration is currently enabled
        // KYC storage
        kyc_enforcement_enabled: bool,
        user_kyc_data: Map<ContractAddress, UserKycData>,
        // Transaction limits stored per level (0=None, 1=Basic, 2=Enhanced, 3=Premium)
        daily_limits: Map<u8, u256>,
        single_limits: Map<u8, u256>,
        daily_usage: Map<ContractAddress, u256>,
        last_reset: Map<ContractAddress, u64>,
        // Governance storage
        user_roles: Map<ContractAddress, AdminRole>, // User admin roles
        system_params: Map<felt252, u256>, // System parameters
        param_bounds: Map<felt252, ParameterBounds>, // Parameter bounds
        contract_registry: Map<felt252, ContractAddress>, // Contract registry
        pending_timelock_changes: Map<felt252, TimelockChange>, // Pending timelock changes
        param_history_count: Map<felt252, u256>, // Parameter history count
        param_history: Map<(felt252, u256), ParameterHistory>, // Parameter history
        system_fees: Map<felt252, u256>, // System fees
        system_paused: bool, // System pause state
        timelock_required_params: Map<felt252, bool> // Parameters requiring timelock
        // Transfer Administration storage
        transfers: Map<u256, TransferData>, // Transfer ID to Transfer mapping
        next_transfer_id: u256, // Counter for generating unique transfer IDs
        user_sent_transfers: Map<
            (ContractAddress, u32), u256,
        >, // User's sent transfers (user, index) -> transfer_id
        user_sent_count: Map<ContractAddress, u32>, // Count of transfers sent by user
        user_received_transfers: Map<
            (ContractAddress, u32), u256,
        >, // User's received transfers (user, index) -> transfer_id
        user_received_count: Map<ContractAddress, u32>, // Count of transfers received by user
        // Agent Management storage
        agents: Map<ContractAddress, Agent>, // Agent address to Agent mapping
        agent_exists: Map<ContractAddress, bool>, // Check if agent exists
        agent_by_region: Map<
            (felt252, u32), ContractAddress,
        >, // Agents by region (region, index) -> agent_address
        agent_region_count: Map<felt252, u32>, // Count of agents by region
        // Transfer History storage
        transfer_history: Map<
            (u256, u32), TransferHistory,
        >, // Transfer history (transfer_id, index) -> history
        transfer_history_count: Map<u256, u32>, // Count of history entries per transfer
        actor_history: Map<
            (ContractAddress, u32), (u256, u32),
        >, // Actor's history (actor, index) -> (transfer_id, history_index)
        actor_history_count: Map<ContractAddress, u32>, // Count of history entries by actor
        action_history: Map<
            (felt252, u32), (u256, u32),
        >, // Action history (action, index) -> (transfer_id, history_index)
        action_history_count: Map<felt252, u32>, // Count of history entries by action
        // Statistics storage
        total_transfers: u256, // Total number of transfers created
        total_completed_transfers: u256, // Total completed transfers
        total_cancelled_transfers: u256, // Total cancelled transfers
        total_expired_transfers: u256, // Total expired transfer
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
        group_count: u64, // Counter used to assign unique group IDs
        // Token Supply Management
        max_supply: u256, // Maximum total supply of the token
        minters: Map<ContractAddress, bool>, // Addresses authorized to mint tokens
        loan_count: u256,
        loans: Map<u256, LoanRequest>,
        loan_request: Map<ContractAddress, bool>, // Track if a user has an active loan request
        active_loan: Map<ContractAddress, bool>, // Track active loan 
        // Loan repayment tracking
        loan_repayments: Map<u256, u256>, // loan_id -> amount_repaid
        loan_due_dates: Map<u256, u64>, // loan_id -> due_date_timestamp
        loan_interest_rates: Map<u256, u256>, // loan_id -> interest_rate_at_approval
        loan_penalties: Map<u256, u256>, // loan_id -> total_penalties_incurred
        loan_last_payment: Map<u256, u64>,
    }

    // Contract constructor
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress, // Admin address
        oracle_address: ContractAddress, // Oracle contract address
        token_address: ContractAddress // Address of the token contract
    ) {
        self.oracle_address.write(oracle_address);

        // Initialize KYC with default settings
        self.kyc_enforcement_enabled.write(false);
        self._set_default_transaction_limits();

        // Initialize governance
        self.user_roles.write(admin, AdminRole::SuperAdmin);
        self.system_paused.write(false);
        self._initialize_default_parameters();
        self._initialize_timelock_required_params();

        // Emit transfer event for initial supply
        let zero_address: ContractAddress = 0.try_into().unwrap();
        self.emit(Transfer { from: zero_address, to: admin, value: initial_supply });
        self.owner.write(owner);
        self.token_address.write(token_address);
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(PROTOCOL_OWNER_ROLE, owner);
    }

    // Implementation of the StarkRemit interface with KYC functions
    #[abi(embed_v0)]
    impl IStarkRemitImpl of IStarkRemit::IStarkRemit<ContractState> {
        fn grant_admin_role(ref self: ContractState, admin: ContractAddress) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.accesscontrol._grant_role(ADMIN_ROLE, admin);
            self.admin.write(admin);
        }

        fn get_owner(self: @ContractState) -> ContractAddress {
            self.owner.read()
        }

        /// Register a new user with the platform
        /// Validates all data and prevents duplicate registrations
        fn register_user(ref self: ContractState, registration_data: RegistrationRequest) -> bool {
            let caller = get_caller_address();

            // Validate caller is not zero address
            assert(!caller.is_zero(), RegistrationErrors::ZERO_ADDRESS);

            // Check if registration is enabled
            //assert(self.registration_enabled.read(), 'Registration disabled');

            // Check if user is already registered

            //         assert(!self.registration_status.read(user_address),
            //         RegistrationErrors::USER_ALREADY_REGISTERED);
            //     },
            //     RegistrationStatus::Suspended => {
            //         assert(false, RegistrationErrors::USER_SUSPENDED);
            //     },
            //     _ => {} // Allow registration for NotStarted, InProgress, or Failed
            // }

            // Validate registration data
            // assert(
            //     self.validate_registration_data(registration_data),
            //     RegistrationErrors::INCOMPLETE_DATA,
            // );

            // Check for duplicate email
            let existing_email_user = self.email_registry.read(registration_data.email_hash);
            assert(existing_email_user.is_zero(), RegistrationErrors::EMAIL_ALREADY_EXISTS);

            // Check for duplicate phone
            let existing_phone_user = self.phone_registry.read(registration_data.phone_hash);
            assert(existing_phone_user.is_zero(), RegistrationErrors::PHONE_ALREADY_EXISTS);

            // Set registration status to in progress
            self.registration_status.write(caller, RegistrationStatus::InProgress);

            // Create user profile
            let current_timestamp = get_block_timestamp();
            let user_profile = UserProfile {
                address: caller,
                user_address: caller,
                email_hash: registration_data.email_hash,
                phone_hash: registration_data.phone_hash,
                full_name: registration_data.full_name,
                kyc_level: KYCLevel::None,
                registration_timestamp: current_timestamp,
                is_active: true,
                country_code: registration_data.country_code,
            };

            // Store user profile
            self.user_profiles.write(caller, user_profile);

            // Register email and phone for uniqueness
            self.email_registry.write(registration_data.email_hash, caller);
            self.phone_registry.write(registration_data.phone_hash, caller);

            // Update registration status to completed
            self.registration_status.write(caller, RegistrationStatus::Completed);

            // Increment total users
            let current_total = self.total_users.read();
            self.total_users.write(current_total + 1);

            // Emit registration event
            self
                .emit(
                    UserRegistered {
                        user_address: caller,
                        email_hash: registration_data.email_hash,
                        registration_timestamp: current_timestamp,
                    },
                );

            true
        }

        /// Get user profile by address
        fn get_user_profile(self: @ContractState, user_address: ContractAddress) -> UserProfile {
            let status = self.registration_status.read(user_address);
            match status {
                RegistrationStatus::Completed => {},
                _ => { assert(false, RegistrationErrors::USER_NOT_FOUND); },
            }

            self.user_profiles.read(user_address)
        }

        /// Update user profile information
        /// Only the user themselves can update their profile
        fn update_user_profile(ref self: ContractState, updated_profile: UserProfile) -> bool {
            let caller = get_caller_address();

            // Verify caller is the profile owner
            assert(updated_profile.user_address == caller, 'Cannot update other profile');

            // Verify user is registered and active
            let status = self.registration_status.read(caller);
            match status {
                RegistrationStatus::Completed => {},
                _ => { assert(false, RegistrationErrors::USER_NOT_FOUND); },
            }

            let current_profile = self.user_profiles.read(caller);
            assert(current_profile.is_active, RegistrationErrors::USER_INACTIVE);

            // Validate that core immutable fields haven't changed
            assert(updated_profile.address == current_profile.address, 'Cannot change address');
            assert(
                updated_profile.registration_timestamp == current_profile.registration_timestamp,
                'Cannot change timestamp',
            );

            // If email or phone changed, check for duplicates
            if updated_profile.email_hash != current_profile.email_hash {
                let zero_address: ContractAddress = 0.try_into().unwrap();
                let existing_email_user = self.email_registry.read(updated_profile.email_hash);
                assert(existing_email_user.is_zero(), RegistrationErrors::EMAIL_ALREADY_EXISTS);

                // Update email registry
                self.email_registry.write(current_profile.email_hash, zero_address);
                self.email_registry.write(updated_profile.email_hash, caller);
            }

            if updated_profile.phone_hash != current_profile.phone_hash {
                let zero_address: ContractAddress = 0.try_into().unwrap();
                let existing_phone_user = self.phone_registry.read(updated_profile.phone_hash);
                assert(existing_phone_user.is_zero(), RegistrationErrors::PHONE_ALREADY_EXISTS);

                // Update phone registry
                self.phone_registry.write(current_profile.phone_hash, zero_address);
                self.phone_registry.write(updated_profile.phone_hash, caller);
            }

            // Store updated profile
            self.user_profiles.write(caller, updated_profile);

            // Emit update event
            self
                .emit(
                    UserProfileUpdated { user_address: caller, updated_fields: 'profile_updated' },
                );

            true
        }

        /// Check if user is registered
        fn is_user_registered(self: @ContractState, user_address: ContractAddress) -> bool {
            let status = self.registration_status.read(user_address);
            match status {
                RegistrationStatus::Completed => true,
                _ => false,
            }
        }

        /// Get user registration status
        fn get_registration_status(
            self: @ContractState, user_address: ContractAddress,
        ) -> RegistrationStatus {
            self.registration_status.read(user_address)
        }

        /// Update KYC status for a user (admin only)
        fn update_kyc_status(
            ref self: ContractState,
            user: ContractAddress,
            status: KycStatus,
            level: KycLevel,
            verification_hash: felt252,
            expires_at: u64,
        ) -> bool {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            let current_data = self.user_kyc_data.read(user);
            let old_status = current_data.status;
            let old_level = current_data.level;

            let updated_data = UserKycData {
                user,
                level,
                status,
                verification_hash,
                verified_at: get_block_timestamp(),
                expires_at,
            };

            self.user_kyc_data.write(user, updated_data);

            self
                .emit(
                    KycStatusUpdated {
                        user, old_status, new_status: status, old_level, new_level: level,
                    },
                );

            true
        }

        /// Get KYC status for a user
        fn get_kyc_status(self: @ContractState, user: ContractAddress) -> (KycStatus, KycLevel) {
            let kyc_data = self.user_kyc_data.read(user);
            let current_time = get_block_timestamp();

            // Check if KYC has expired
            if kyc_data.expires_at > 0 && current_time > kyc_data.expires_at {
                return (KycStatus::Expired, kyc_data.level);
            }

            (kyc_data.status, kyc_data.level)
        }

        /// Check if user's KYC is valid
        fn is_kyc_valid(self: @ContractState, user: ContractAddress) -> bool {
            let kyc_data = self.user_kyc_data.read(user);
            let current_time = get_block_timestamp();

            match kyc_data.status {
                KycStatus::Approved => {
                    if kyc_data.expires_at > current_time {
                        true
                    } else {
                        false
                    }
                },
                _ => false,
            }
        }

        /// Set KYC enforcement (admin only)
        fn set_kyc_enforcement(ref self: ContractState, enabled: bool) -> bool {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            self.kyc_enforcement_enabled.write(enabled);
            self.emit(KycEnforcementEnabled { enabled, updated_by: caller });

            true
        }

        /// Check if KYC enforcement is enabled
        fn is_kyc_enforcement_enabled(self: @ContractState) -> bool {
            self.kyc_enforcement_enabled.read()
        }

        /// Suspend user's KYC (admin only)
        fn suspend_user_kyc(ref self: ContractState, user: ContractAddress) -> bool {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            let mut kyc_data = self.user_kyc_data.read(user);
            let old_status = kyc_data.status;

            kyc_data.status = KycStatus::Suspended;
            self.user_kyc_data.write(user, kyc_data);

            self
                .emit(
                    KycStatusUpdated {
                        user,
                        old_status,
                        new_status: KycStatus::Suspended,
                        old_level: kyc_data.level,
                        new_level: kyc_data.level,
                    },
                );

            true
        }

        /// Reinstate user's KYC (admin only)
        fn reinstate_user_kyc(ref self: ContractState, user: ContractAddress) -> bool {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            let mut kyc_data = self.user_kyc_data.read(user);
            let old_status = kyc_data.status;

            // Only allow reinstatement from suspended status
            assert(old_status == KycStatus::Suspended, KYCErrors::INVALID_KYC_STATUS);

            kyc_data.status = KycStatus::Approved;
            self.user_kyc_data.write(user, kyc_data);

            self
                .emit(
                    KycStatusUpdated {
                        user,
                        old_status,
                        new_status: KycStatus::Approved,
                        old_level: kyc_data.level,
                        new_level: kyc_data.level,
                    },
                );

            true
        }

        /// Update user KYC level (admin only)
        fn update_kyc_level(
            ref self: ContractState, user_address: ContractAddress, kyc_level: KYCLevel,
        ) -> bool {
            let caller = get_caller_address();

            // Verify caller is admin
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            // Verify user is registered
            assert(self.is_user_registered(user_address), RegistrationErrors::USER_NOT_FOUND);

            let mut user_profile = self.user_profiles.read(user_address);
            let old_level = user_profile.kyc_level;

            // Update KYC level
            user_profile.kyc_level = kyc_level;
            self.user_profiles.write(user_address, user_profile);

            // Emit KYC update event
            self
                .emit(
                    KYCLevelUpdated {
                        user_address, old_level, new_level: kyc_level, admin: caller,
                    },
                );

            true
        }

        /// Deactivate user account (admin only)
        fn deactivate_user(ref self: ContractState, user_address: ContractAddress) -> bool {
            let caller = get_caller_address();

            // Verify caller is admin
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            // Verify user is registered
            assert(self.is_user_registered(user_address), RegistrationErrors::USER_NOT_FOUND);

            let mut user_profile = self.user_profiles.read(user_address);
            user_profile.is_active = false;
            self.user_profiles.write(user_address, user_profile);

            // Update registration status
            self.registration_status.write(user_address, RegistrationStatus::Suspended);

            // Emit deactivation event
            self.emit(UserDeactivated { user_address, admin: caller });

            true
        }

        /// Reactivate user account (admin only)
        fn reactivate_user(ref self: ContractState, user_address: ContractAddress) -> bool {
            let caller = get_caller_address();

            // Verify caller is admin
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            // Verify user exists
            let status = self.registration_status.read(user_address);
            match status {
                RegistrationStatus::Suspended => {},
                _ => { assert(false, 'User not suspended'); },
            }

            let mut user_profile = self.user_profiles.read(user_address);
            user_profile.is_active = true;
            self.user_profiles.write(user_address, user_profile);

            // Update registration status
            self.registration_status.write(user_address, RegistrationStatus::Completed);

            // Emit reactivation event
            self.emit(UserReactivated { user_address, admin: caller });

            true
        }

        /// Get total registered users count
        fn get_total_users(self: @ContractState) -> u256 {
            self.total_users.read()
        }

        // Transfer Administration Functions
        /// Initiate a new transfer (enhanced version of create_transfer)
        /// Provides comprehensive validation, error handling, and enhanced features
        fn initiate_transfer(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
            expires_at: u64,
            metadata: felt252,
        ) -> u256 {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let zero_address: ContractAddress = 0.try_into().unwrap();

            // Enhanced input validation
            assert(recipient != zero_address, TransferErrors::INVALID_TRANSFER_AMOUNT);
            assert(recipient != caller, 'Cannot transfer to self');
            assert(amount > 0, TransferErrors::INVALID_TRANSFER_AMOUNT);
            assert(expires_at > current_time, 'Expiry must be in future');
            assert(
                expires_at <= current_time + 86400 * 30, 'Expiry too far in future',
            ); // Max 30 days

            // Enhanced user validation
            assert(self.is_user_registered(caller), 'Sender not registered');
            assert(self.is_user_registered(recipient), 'Recipient not registered');

            // Enhanced KYC validation if enforcement is enabled
            if self.kyc_enforcement_enabled.read() {
                InternalFunctions::_validate_kyc_and_limits(@self, caller, amount);
                InternalFunctions::_validate_kyc_and_limits(@self, recipient, amount);

                // Additional KYC checks for large amounts
                if amount > 10000_000_000_000_000_000_000 { // > 10,000 tokens
                    let (_caller_status, caller_level) = self.get_kyc_status(caller);
                    let (_recipient_status, recipient_level) = self.get_kyc_status(recipient);
                    assert(
                        caller_level == KycLevel::Enhanced || caller_level == KycLevel::Premium,
                        'KYC level insufficient',
                    );
                    assert(
                        recipient_level == KycLevel::Enhanced
                            || recipient_level == KycLevel::Premium,
                        'Recipient KYC insufficient',
                    );
                }
            }

            // assert(sender_balance >= amount, ERC20Errors::INSUFFICIENT_BALANCE);

            // Check for sufficient balance with buffer (2% minimum remaining balance for fees)
            // let min_remaining = amount / 50; // 2% buffer
            // assert(sender_balance >= amount + min_remaining, 'Insufficient balance buffer');

            // Generate transfer ID with enhanced security
            let transfer_id = self.next_transfer_id.read();
            self.next_transfer_id.write(transfer_id + 1);

            // Create enhanced transfer with additional metadata
            let transfer = TransferData {
                transfer_id,
                sender: caller,
                recipient,
                amount,
                status: TransferStatus::Pending,
                created_at: current_time,
                updated_at: current_time,
                expires_at,
                assigned_agent: zero_address,
                partial_amount: 0,
                metadata,
            };

            // Store transfer with enhanced validation
            self.transfers.write(transfer_id, transfer);

            // Update user indices with overflow protection
            let sender_count = self.user_sent_count.read(caller);
            assert(sender_count < 4294967295, 'Max transfers per user exceeded'); // u32 max
            self.user_sent_transfers.write((caller, sender_count), transfer_id);
            self.user_sent_count.write(caller, sender_count + 1);

            let recipient_count = self.user_received_count.read(recipient);
            assert(recipient_count < 4294967295, 'Max transfers per user exceeded');
            self.user_received_transfers.write((recipient, recipient_count), transfer_id);
            self.user_received_count.write(recipient, recipient_count + 1);

            // Update statistics with overflow protection
            let total = self.total_transfers.read();
            self.total_transfers.write(total + 1);

            // Record detailed history with enhanced metadata
            InternalFunctions::_record_transfer_history(
                ref self,
                transfer_id,
                'initiated',
                caller,
                TransferStatus::Pending,
                TransferStatus::Pending,
                'Transfer initiated',
            );

            // Record usage for KYC limits with enhanced tracking
            if self.kyc_enforcement_enabled.read() {
                InternalFunctions::_record_daily_usage(ref self, caller, amount);
            }

            // Emit enhanced event
            self
                .emit(
                    TransferCreated { transfer_id, sender: caller, recipient, amount, expires_at },
                );

            transfer_id
        }

        /// Create a new transfer
        fn create_transfer(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256,
            // currency: felt252,
            expires_at: u64,
            metadata: felt252,
        ) -> u256 {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let zero_address: ContractAddress = 0.try_into().unwrap();

            // Validate inputs
            assert(recipient != zero_address, TransferErrors::INVALID_TRANSFER_AMOUNT);
            assert(amount > 0, TransferErrors::INVALID_TRANSFER_AMOUNT);
            assert(expires_at > current_time, 'Expiry must be in future');

            // Validate KYC if enforcement is enabled
            if self.kyc_enforcement_enabled.read() {
                self._validate_kyc_and_limits(caller, amount);
                self._validate_kyc_and_limits(recipient, amount);
            }

            // Check sender has sufficient balance

            // assert(sender_balance >= amount, ERC20Errors::INSUFFICIENT_BALANCE);

            // Generate transfer ID
            let transfer_id = self.next_transfer_id.read();
            self.next_transfer_id.write(transfer_id + 1);

            // Create transfer
            let transfer = TransferData {
                transfer_id,
                sender: caller,
                recipient,
                amount,
                status: TransferStatus::Pending,
                created_at: current_time,
                updated_at: current_time,
                expires_at,
                assigned_agent: zero_address,
                partial_amount: 0,
                metadata,
            };

            // Store transfer
            self.transfers.write(transfer_id, transfer);

            // Update user indices
            let sender_count = self.user_sent_count.read(caller);
            self.user_sent_transfers.write((caller, sender_count), transfer_id);
            self.user_sent_count.write(caller, sender_count + 1);

            let recipient_count = self.user_received_count.read(recipient);
            self.user_received_transfers.write((recipient, recipient_count), transfer_id);
            self.user_received_count.write(recipient, recipient_count + 1);

            // Update statistics
            let total = self.total_transfers.read();
            self.total_transfers.write(total + 1);

            // Record history
            InternalFunctions::_record_transfer_history(
                ref self,
                transfer_id,
                'created',
                caller,
                TransferStatus::Pending,
                TransferStatus::Pending,
                'Transfer created',
            );
            // Emit event
            self
                .emit(
                    TransferCreated { transfer_id, sender: caller, recipient, amount, expires_at },
                );

            transfer_id
        }

        /// Cancel an existing transfer
        fn cancel_transfer(ref self: ContractState, transfer_id: u256) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            // Get transfer and validate it exists
            let mut transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);

            // Validate transfer can be cancelled
            assert(
                transfer.status == TransferStatus::Pending, TransferErrors::INVALID_TRANSFER_STATUS,
            );
            assert(transfer.sender == caller, TransferErrors::UNAUTHORIZED_TRANSFER_OP);

            // Update transfer status
            transfer.status = TransferStatus::Cancelled;
            transfer.updated_at = current_time;
            self.transfers.write(transfer_id, transfer);

            // Update statistics
            let cancelled_count = self.total_cancelled_transfers.read();
            self.total_cancelled_transfers.write(cancelled_count + 1);

            // Record history
            InternalFunctions::_record_transfer_history(
                ref self,
                transfer_id,
                'cancelled',
                caller,
                TransferStatus::Pending,
                TransferStatus::Cancelled,
                'Transfer cancelled by sender',
            );

            // Emit event
            self
                .emit(
                    TransferCancelled {
                        transfer_id,
                        cancelled_by: caller,
                        timestamp: current_time,
                        reason: 'user_cancelled',
                    },
                );

            true
        }

        /// Complete a transfer (mark as completed)
        fn complete_transfer(ref self: ContractState, transfer_id: u256) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            // Get transfer and validate it exists
            let mut transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);

            // Validate transfer can be completed
            assert(
                transfer.status == TransferStatus::Pending
                    || transfer.status == TransferStatus::PartialComplete,
                TransferErrors::INVALID_TRANSFER_STATUS,
            );

            // Only recipient or assigned agent can complete
            let zero_address: ContractAddress = 0.try_into().unwrap();
            let is_authorized = caller == transfer.recipient
                || (transfer.assigned_agent != zero_address && caller == transfer.assigned_agent);
            assert(is_authorized, TransferErrors::UNAUTHORIZED_TRANSFER_OP);

            // Update transfer status
            transfer.status = TransferStatus::Completed;
            transfer.updated_at = current_time;
            self.transfers.write(transfer_id, transfer);

            // Transfer funds to recipient
            // let recipient_balance = self
            //     .currency_balances
            //     .read((transfer.recipient, transfer.currency));
            // let amount_to_transfer = transfer.amount - transfer.partial_amount;
            // self
            //     .currency_balances
            //     .write(
            //         (transfer.recipient, transfer.currency), recipient_balance +
            //         amount_to_transfer,
            //     );

            // Update statistics
            let completed_count = self.total_completed_transfers.read();
            self.total_completed_transfers.write(completed_count + 1);

            // Update agent statistics if applicable
            if transfer.assigned_agent != zero_address {
                let mut agent = self.agents.read(transfer.assigned_agent);
                agent.completed_transactions += 1;
                agent.total_volume += transfer.amount;
                agent.last_active = current_time;
                self.agents.write(transfer.assigned_agent, agent);
            }

            // Record history
            InternalFunctions::_record_transfer_history(
                ref self,
                transfer_id,
                'completed',
                caller,
                TransferStatus::Pending,
                TransferStatus::Completed,
                'Transfer completed',
            );

            // Emit event
            self
                .emit(
                    TransferCompleted {
                        transfer_id, completed_by: caller, timestamp: current_time,
                    },
                );

            true
        }

        /// Partially complete a transfer
        fn partial_complete_transfer(
            ref self: ContractState, transfer_id: u256, partial_amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            // Get transfer and validate it exists
            let mut transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);

            // Validate transfer can be partially completed
            assert(
                transfer.status == TransferStatus::Pending
                    || transfer.status == TransferStatus::PartialComplete,
                TransferErrors::INVALID_TRANSFER_STATUS,
            );

            // Only recipient or assigned agent can complete
            let zero_address: ContractAddress = 0.try_into().unwrap();
            let is_authorized = caller == transfer.recipient
                || (transfer.assigned_agent != zero_address && caller == transfer.assigned_agent);
            assert(is_authorized, TransferErrors::UNAUTHORIZED_TRANSFER_OP);

            // Validate partial amount
            assert(partial_amount > 0, TransferErrors::INVALID_TRANSFER_AMOUNT);
            assert(
                transfer.partial_amount + partial_amount <= transfer.amount,
                TransferErrors::PARTIAL_AMOUNT_EXCEEDS,
            );

            // Update transfer
            transfer.partial_amount += partial_amount;
            transfer.updated_at = current_time;

            // Update status if fully completed
            if transfer.partial_amount == transfer.amount {
                transfer.status = TransferStatus::Completed;
            } else {
                transfer.status = TransferStatus::PartialComplete;
            }

            self.transfers.write(transfer_id, transfer);

            // Transfer funds to recipient
            // let recipient_balance = self
            //     .currency_balances
            //     .read((transfer.recipient, transfer.currency));
            // self
            //     .currency_balances
            //     .write((transfer.recipient, transfer.currency), recipient_balance +
            //     partial_amount);

            // Record history
            InternalFunctions::_record_transfer_history(
                ref self,
                transfer_id,
                'partial_completed',
                caller,
                TransferStatus::Pending,
                transfer.status,
                'Transfer partially completed',
            );

            // Emit event
            self
                .emit(
                    TransferPartialCompleted {
                        transfer_id,
                        partial_amount,
                        total_amount: transfer.amount,
                        timestamp: current_time,
                    },
                );

            true
        }

        /// Request cash-out for a transfer
        fn request_cash_out(ref self: ContractState, transfer_id: u256) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            // Get transfer and validate it exists
            let mut transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);

            // Validate transfer can request cash-out
            assert(
                transfer.status == TransferStatus::Pending, TransferErrors::INVALID_TRANSFER_STATUS,
            );
            assert(caller == transfer.recipient, TransferErrors::UNAUTHORIZED_TRANSFER_OP);

            // Update transfer status
            transfer.status = TransferStatus::CashOutRequested;
            transfer.updated_at = current_time;
            self.transfers.write(transfer_id, transfer);

            // Record history
            InternalFunctions::_record_transfer_history(
                ref self,
                transfer_id,
                'cash_out_requested',
                caller,
                TransferStatus::Pending,
                TransferStatus::CashOutRequested,
                'Cash-out requested by recipient',
            );

            // Emit event
            self
                .emit(
                    CashOutRequested { transfer_id, requested_by: caller, timestamp: current_time },
                );

            true
        }

        /// Complete cash-out (agent only)
        fn complete_cash_out(ref self: ContractState, transfer_id: u256) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            // Get transfer and validate it exists
            let mut transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);

            // Validate transfer can complete cash-out
            assert(
                transfer.status == TransferStatus::CashOutRequested,
                TransferErrors::INVALID_TRANSFER_STATUS,
            );

            // Must be assigned agent
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(
                transfer.assigned_agent != zero_address, TransferErrors::INVALID_AGENT_ASSIGNMENT,
            );
            assert(caller == transfer.assigned_agent, TransferErrors::UNAUTHORIZED_TRANSFER_OP);

            // Validate agent is authorized
            assert(
                self.is_agent_authorized(caller, transfer_id), TransferErrors::AGENT_NOT_AUTHORIZED,
            );

            // Update transfer status
            transfer.status = TransferStatus::CashOutCompleted;
            transfer.updated_at = current_time;
            self.transfers.write(transfer_id, transfer);

            // Update statistics
            let completed_count = self.total_completed_transfers.read();
            self.total_completed_transfers.write(completed_count + 1);

            // Update agent statistics
            let mut agent = self.agents.read(transfer.assigned_agent);
            agent.completed_transactions += 1;
            agent.total_volume += transfer.amount;
            agent.last_active = current_time;
            self.agents.write(transfer.assigned_agent, agent);

            // Record history
            InternalFunctions::_record_transfer_history(
                ref self,
                transfer_id,
                'cash_out_completed',
                caller,
                TransferStatus::CashOutRequested,
                TransferStatus::CashOutCompleted,
                'Cash-out completed by agent',
            );

            // Emit event
            self.emit(CashOutCompleted { transfer_id, agent: caller, timestamp: current_time });

            true
        }

        /// Get transfer details
        fn get_transfer(self: @ContractState, transfer_id: u256) -> TransferData {
            let transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);
            transfer
        }

        /// Get transfers by sender
        fn get_transfers_by_sender(
            self: @ContractState, sender: ContractAddress, limit: u32, offset: u32,
        ) -> Array<TransferData> {
            let mut transfers = ArrayTrait::new();
            let total_count = self.user_sent_count.read(sender);

            let mut i = offset;
            let mut count = 0;

            while i < total_count && count < limit {
                let transfer_id = self.user_sent_transfers.read((sender, i));
                let transfer = self.transfers.read(transfer_id);
                transfers.append(transfer);
                count += 1;
                i += 1;
            }

            transfers
        }

        /// Get transfers by recipient
        fn get_transfers_by_recipient(
            self: @ContractState, recipient: ContractAddress, limit: u32, offset: u32,
        ) -> Array<TransferData> {
            let mut transfers = ArrayTrait::new();
            let total_count = self.user_received_count.read(recipient);

            let mut i = offset;
            let mut count = 0;

            while i < total_count && count < limit {
                let transfer_id = self.user_received_transfers.read((recipient, i));
                let transfer = self.transfers.read(transfer_id);
                transfers.append(transfer);
                count += 1;
                i += 1;
            }

            transfers
        }

        /// Get transfers by status (simplified implementation)
        fn get_transfers_by_status(
            self: @ContractState, status: TransferStatus, limit: u32, offset: u32,
        ) -> Array<TransferData> {
            let mut transfers = ArrayTrait::new();
            // This is a simplified implementation
            // In production, you'd want proper indexing by status
            transfers
        }

        /// Get expired transfers (simplified implementation)
        fn get_expired_transfers(
            self: @ContractState, limit: u32, offset: u32,
        ) -> Array<TransferData> {
            let mut transfers = ArrayTrait::new();
            // This is a simplified implementation
            // In production, you'd want proper indexing by expiry
            transfers
        }

        /// Process expired transfers (admin only)
        fn process_expired_transfers(ref self: ContractState, limit: u32) -> u32 {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            // This is a simplified implementation
            // In production, you'd iterate through transfers and mark expired ones
            0
        }

        /// Assign agent to transfer (admin only)
        fn assign_agent_to_transfer(
            ref self: ContractState, transfer_id: u256, agent: ContractAddress,
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            // Get transfer and validate it exists
            let mut transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);

            // Validate agent exists and is active
            assert(self.agent_exists.read(agent), TransferErrors::AGENT_NOT_FOUND);
            let agent_data = self.agents.read(agent);
            assert(agent_data.status == AgentStatus::Active, TransferErrors::AGENT_NOT_ACTIVE);

            // Update transfer
            transfer.assigned_agent = agent;
            transfer.updated_at = current_time;
            self.transfers.write(transfer_id, transfer);

            // Record history
            InternalFunctions::_record_transfer_history(
                ref self,
                transfer_id,
                'agent_assigned',
                caller,
                transfer.status,
                transfer.status,
                'Agent assigned to transfer',
            );

            // Emit event
            self
                .emit(
                    AgentAssigned {
                        transfer_id, agent, assigned_by: caller, timestamp: current_time,
                    },
                );

            true
        }

        // Agent Management Functions
        /// Register a new agent (admin only)
        fn register_agent(
            ref self: ContractState,
            agent_address: ContractAddress,
            name: felt252,
            // primary_currency: felt252,
            // secondary_currency: felt252,
            primary_region: felt252,
            secondary_region: felt252,
            commission_rate: u256,
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            // Check if agent already exists
            assert(!self.agent_exists.read(agent_address), TransferErrors::AGENT_ALREADY_EXISTS);

            // Create agent
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

        /// Update agent status (admin only)
        fn update_agent_status(
            ref self: ContractState, agent_address: ContractAddress, status: AgentStatus,
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            // Check if agent exists
            assert(self.agent_exists.read(agent_address), TransferErrors::AGENT_NOT_FOUND);

            let mut agent = self.agents.read(agent_address);
            let old_status = agent.status;

            // Update status
            agent.status = status;
            agent.last_active = current_time;
            self.agents.write(agent_address, agent);

            // Emit event
            self
                .emit(
                    AgentStatusUpdated {
                        agent: agent_address,
                        old_status,
                        new_status: status,
                        updated_by: caller,
                        timestamp: current_time,
                    },
                );

            true
        }

        /// Get agent details
        fn get_agent(self: @ContractState, agent_address: ContractAddress) -> Agent {
            assert(self.agent_exists.read(agent_address), TransferErrors::AGENT_NOT_FOUND);
            self.agents.read(agent_address)
        }

        /// Get agents by status
        fn get_agents_by_status(
            self: @ContractState, status: AgentStatus, limit: u32, offset: u32,
        ) -> Array<Agent> {
            let mut agents = ArrayTrait::new();
            // Since we don't have a comprehensive agent list, we'll need to iterate through regions
            // This is a simplified implementation - in production you might want a better indexing
            // system
            let mut _count = 0;
            let mut _found = 0;

            // For now, return empty array as we don't have a comprehensive agent index
            // In a production system, you'd want to maintain a separate agent index
            agents
        }

        /// Get agents by region
        fn get_agents_by_region(
            self: @ContractState, region: felt252, limit: u32, offset: u32,
        ) -> Array<Agent> {
            let mut agents = ArrayTrait::new();
            let total_count = self.agent_region_count.read(region);

            let mut i = offset;
            let mut count = 0;

            while i < total_count && count < limit {
                let agent_address = self.agent_by_region.read((region, i));
                let agent = self.agents.read(agent_address);
                agents.append(agent);
                count += 1;
                i += 1;
            }

            agents
        }

        /// Check if agent is authorized for transfer
        fn is_agent_authorized(
            self: @ContractState, agent: ContractAddress, transfer_id: u256,
        ) -> bool {
            // Check if agent exists and is active
            if !self.agent_exists.read(agent) {
                return false;
            }

            let agent_data = self.agents.read(agent);
            if agent_data.status != AgentStatus::Active {
                return false;
            }

            // Get transfer to check if agent is assigned
            let transfer = self.transfers.read(transfer_id);
            if transfer.transfer_id == 0 {
                return false;
            }

            // Agent must be assigned to this transfer
            agent == transfer.assigned_agent
        }

        // Transfer History Functions
        /// Get transfer history
        fn get_transfer_history(
            self: @ContractState, transfer_id: u256, limit: u32, offset: u32,
        ) -> Array<TransferHistory> {
            let mut history = ArrayTrait::new();
            let total_count = self.transfer_history_count.read(transfer_id);

            let mut i = offset;
            let mut count = 0;

            while i < total_count && count < limit {
                let history_entry = self.transfer_history.read((transfer_id, i));
                history.append(history_entry);
                count += 1;
                i += 1;
            }

            history
        }

        /// Search transfer history by actor
        fn search_history_by_actor(
            self: @ContractState, actor: ContractAddress, limit: u32, offset: u32,
        ) -> Array<TransferHistory> {
            let mut history = ArrayTrait::new();
            let total_count = self.actor_history_count.read(actor);

            let mut i = offset;
            let mut count = 0;

            while i < total_count && count < limit {
                let (transfer_id, history_index) = self.actor_history.read((actor, i));
                let history_entry = self.transfer_history.read((transfer_id, history_index));
                history.append(history_entry);
                count += 1;
                i += 1;
            }

            history
        }

        /// Search transfer history by action
        fn search_history_by_action(
            self: @ContractState, action: felt252, limit: u32, offset: u32,
        ) -> Array<TransferHistory> {
            let mut history = ArrayTrait::new();
            let total_count = self.action_history_count.read(action);

            let mut i = offset;
            let mut count = 0;

            while i < total_count && count < limit {
                let (transfer_id, history_index) = self.action_history.read((action, i));
                let history_entry = self.transfer_history.read((transfer_id, history_index));
                history.append(history_entry);
                count += 1;
                i += 1;
            }

            history
        }

        /// Get transfer statistics
        fn get_transfer_statistics(self: @ContractState) -> (u256, u256, u256, u256) {
            (
                self.total_transfers.read(),
                self.total_completed_transfers.read(),
                self.total_cancelled_transfers.read(),
                self.total_expired_transfers.read(),
            )
        }

        /// Get agent statistics
        fn get_agent_statistics(
            self: @ContractState, agent: ContractAddress,
        ) -> (u256, u256, u256) {
            assert(self.agent_exists.read(agent), TransferErrors::AGENT_NOT_FOUND);
            let agent_data = self.agents.read(agent);
            (agent_data.completed_transactions, agent_data.total_volume, agent_data.rating)
        }

        // Contribution Management
        fn contribute_round(ref self: ContractState, round_id: u256, amount: u256) {
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

            self.emit(ContributionMade { round_id, member: caller, amount });
        }

        fn complete_round(ref self: ContractState, round_id: u256) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            let mut round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, 'Round is not active');

            round.status = RoundStatus::Completed;
            self.rounds.write(round_id, round);

            self.emit(RoundCompleted { round_id });
        }

        fn add_round_to_schedule(
            ref self: ContractState, recipient: ContractAddress, deadline: u64,
        ) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            let round_id = self.round_ids.read() + 1;
            self.round_ids.write(round_id);

            self.rotation_schedule.write(round_id, recipient);

            let round = ContributionRound {
                round_id, recipient, deadline, total_contributions: 0, status: RoundStatus::Active,
            };

            self.rounds.write(round_id, round);
        }

        fn is_member(self: @ContractState, address: ContractAddress) -> bool {
            self.members.read(address)
        }

        fn check_missed_contributions(ref self: ContractState, round_id: u256) {
            let round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, 'Round is not active');
            assert(get_block_timestamp() > round.deadline, 'Round deadline not passed');
        }

        fn get_all_members(self: @ContractState) -> Array<ContractAddress> {
            let mut members = ArrayTrait::new();
            let count = self.member_count.read();
            let mut i = 0;

            while i < count {
                let member = self.member_by_index.read(i);
                members.append(member);
                i += 1;
            }

            members
        }

        fn add_member(ref self: ContractState, address: ContractAddress) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            assert(!self.is_member(address), 'Already a member');

            self.members.write(address, true);
            let count = self.member_count.read();
            self.member_by_index.write(count, address);
            self.member_count.write(count + 1);
        }

        fn disburse_round_contribution(ref self: ContractState, round_id: u256) {
            let caller = get_caller_address();
            self.accesscontrol.assert_only_role(ADMIN_ROLE);

            let round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Completed, 'Round not completed');

            self
                .emit(
                    RoundDisbursed {
                        round_id, recipient: round.recipient, amount: round.total_contributions,
                    },
                );
        }

        // Savings Group Functions
        fn create_group(ref self: ContractState, max_members: u8) -> u64 {
            let caller = get_caller_address();
            let group_id = self._new_group_id();

            let group = SavingsGroup {
                id: group_id,
                creator: caller,
                max_members,
                member_count: 1,
                total_savings: 0,
                created_at: get_block_timestamp(),
                is_active: true,
            };

            self.groups.write(group_id, group);
            self.group_members.write((group_id, caller), true);

            group_id
        }

        fn join_group(ref self: ContractState, group_id: u64) {
            let caller = get_caller_address();
            let group = self.groups.read(group_id);
            assert(group.is_active, GroupErrors::GROUP_NOT_ACTIVE);
            assert(!self.group_members.read((group_id, caller)), GroupErrors::ALREADY_MEMBER);

            self.group_members.write((group_id, caller), true);
        }

        fn requestLoan(ref self: ContractState, requester: ContractAddress, amount: u256) -> u256 {
            let caller = get_caller_address();

            // Validate caller is not zero address
            assert(!caller.is_zero(), RegistrationErrors::ZERO_ADDRESS);
            // assert(self.is_user_registered(requester), RegistrationErrors::USER_NOT_FOUND);
            // assert(self.is_kyc_valid(requester), KYCErrors::INVALID_KYC_STATUS);
            assert(amount > 0, 'loan amount is zero');
            // Ensure the user has no active loans
            assert(!self.active_loan.read(requester), 'User already has an active loan');
            // Ensure the user has not requested a loan already
            assert(!self.loan_request.read(requester), 'has pending loan request');

            // // Validate registration data
            // assert(
            //     self.validate_registration_data(registration_data),
            //     RegistrationErrors::INCOMPLETE_DATA,
            // );

            let created_at = get_block_timestamp();
            // Generate a unique loan requst ID
            let loan_id: u256 = self.loan_count.read();

            let loan = LoanRequest {
                id: loan_id,
                requester: requester,
                amount: amount,
                status: LoanStatus::Pending,
                created_at: created_at,
            };

            self.loan_count.write(loan_id + 1);
            self.loans.write(loan_id, loan);
            self.active_loan.write(requester, false);
            self.loan_request.write(requester, true);

            // Emit an event
            self
                .emit(
                    LoanRequested {
                        id: loan_id, requester: requester, amount: amount, created_at: created_at,
                    },
                );

            loan_id
        }


        // approve a loan
        fn approveLoan(ref self: ContractState, loan_id: u256) -> u256 {
            // Ensure only the admin can approve a loan
            let caller = get_caller_address();
            let created_at = get_block_timestamp();
            assert(caller == self.owner.read(), 'caller is not owner');

            let loan = self.loans.entry(loan_id).read();
            assert(self.loan_request.entry(loan.requester).read(), 'no loan request');
            assert(loan.status == LoanStatus::Pending, 'loan request is not pending');
            assert(loan.amount > 0, 'loan amount is zero');

            let loan = LoanRequest {
                id: loan.id,
                requester: loan.requester,
                amount: loan.amount,
                status: LoanStatus::Approved,
                created_at: loan.created_at,
            };
            // Update the active loan status
            self.active_loan.write(loan.requester, true);
            self.loan_request.write(loan.requester, false);
            // Update the loan status to approved
            self.loans.write(loan_id, loan);
            self
                .emit(
                    LoanRequested {
                        id: loan.id,
                        requester: loan.requester,
                        amount: loan.amount,
                        created_at: created_at,
                    },
                );

            // Emit an event
            // self.emit(LoanApproved { id: loan.id, auth: admin, created_at: created_at });

            loan_id
        }


        fn rejectLoan(ref self: ContractState, loan_id: u256) -> u256 {
            // Ensure only the admin can approve a loan
            let caller = get_caller_address();
            assert(caller == self.owner.read(), 'caller is not owner');
            let created_at = get_block_timestamp();
            let loan = self.loans.entry(loan_id).read();
            // assert(self.loan_request.entry(loan.requester).read(), 'no loan request');
            // assert(loan.status == LoanStatus::Pending, 'loan request is not pending');

            let loan = LoanRequest {
                id: loan.id,
                requester: loan.requester,
                amount: loan.amount,
                created_at: loan.created_at,
                status: LoanStatus::Reject,
            };
            // Update the active loan status
            self.active_loan.write(loan.requester, false);
            self.loan_request.write(loan.requester, false);
            // Update the loan status to approved
            self.loans.write(loan_id, loan);
            self
                .emit(
                    LoanRequested {
                        id: loan.id,
                        requester: loan.requester,
                        amount: loan.amount,
                        created_at: created_at,
                    },
                );
            // Emit an event
            // self.emit(LoanReject { id: loan.id, auth: admin, created_at: created_at });

            loan_id
        }

        fn getLoan(self: @ContractState, loan_id: u256) -> LoanRequest {
            let loan = self.loans.read(loan_id);
            assert(loan.id == loan_id, 'Loan request not found');
            loan
        }
        fn get_loan_count(self: @ContractState) -> u256 {
            self.loan_count.read()
        }
        fn get_user_active_Loan(self: @ContractState, user: ContractAddress) -> bool {
            self.active_loan.entry(user).read()
        }

        fn has_active_loan_request(self: @ContractState, user: ContractAddress) -> bool {
            self.loan_request.entry(user).read()
        }


        //loan repayment

        fn repay_loan(ref self: ContractState, loan_id: u256, amount: u256) -> (u256, u256) {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();

            // Get loan and validate using getLoan for consistent behavior
            let mut loan = self.getLoan(loan_id);

            assert(loan.status == LoanStatus::Approved, 'Loan is not approved');
            assert(loan.requester == caller, 'Not the loan owner');
            assert(amount > 0, 'Amount must be positive');

            // Get repayment details
            let amount_repaid = self.loan_repayments.read(loan_id);
            let due_date = self.loan_due_dates.read(loan_id);
            let interest_rate = self.loan_interest_rates.read(loan_id);
            let last_payment = self.loan_last_payment.read(loan_id);

            // Calculate current balance (principal + interest - amount_repaid + penalties)
            let days_elapsed = (current_time - last_payment).into()
                / 864; // Convert to days * 100 (for better precision)
            let interest = (loan.amount * interest_rate * days_elapsed) / (100 * 365 * 100);

            // Calculate late penalties if any
            let mut penalty = 0;

            if current_time > due_date {
                let days_late = ((current_time - due_date).into() / 864) + 1;
                penalty = (loan.amount * LATE_PENALTY_RATE * days_late) / (100 * 100 * 100);
                self.loan_penalties.write(loan_id, self.loan_penalties.read(loan_id) + penalty);

                self
                    .emit(
                        LatePayment {
                            loan_id, days_late, penalty_amount: penalty, timestamp: current_time,
                        },
                    );
            }

            let total_balance = loan.amount + interest + penalty - amount_repaid;
            let actual_payment = if amount > total_balance {
                total_balance
            } else {
                amount
            };
            let new_amount_repaid = amount_repaid + actual_payment;
            let remaining_balance = total_balance - actual_payment;

            self.loan_repayments.write(loan_id, new_amount_repaid);
            self.loan_last_payment.write(loan_id, current_time);

            let is_fully_repaid = remaining_balance == 0;
            if is_fully_repaid {
                loan.status = LoanStatus::Completed;
                self.loans.write(loan_id, loan);
                self.active_loan.write(caller, false);
            }

            self
                .emit(
                    LoanRepaid {
                        loan_id,
                        amount: actual_payment,
                        remaining_balance,
                        is_fully_repaid,
                        timestamp: current_time,
                    },
                );

            (actual_payment, remaining_balance)
        }
    }

    // Implementation of the Governance interface
    #[abi(embed_v0)]
    impl IGovernanceImpl of IGovernance::IGovernance<ContractState> {
        fn assign_admin_role(
            ref self: ContractState, user: ContractAddress, role: AdminRole,
        ) -> bool {
            self._require_minimum_role(AdminRole::SuperAdmin);
            self._require_system_not_paused();

            let _ = self.user_roles.read(user);
            self.user_roles.write(user, role);

            let caller = get_caller_address();
            self.emit(AdminRoleAssigned { user, role, assigned_by: caller });
            true
        }

        fn revoke_admin_role(ref self: ContractState, user: ContractAddress) -> bool {
            self._require_minimum_role(AdminRole::SuperAdmin);
            self._require_system_not_paused();

            let old_role = self.user_roles.read(user);
            self.user_roles.write(user, AdminRole::None);

            let caller = get_caller_address();
            self.emit(AdminRoleRevoked { user, old_role, revoked_by: caller });
            true
        }

        fn get_admin_role(self: @ContractState, user: ContractAddress) -> AdminRole {
            self.user_roles.read(user)
        }

        fn has_minimum_role(
            self: @ContractState, user: ContractAddress, required_role: AdminRole,
        ) -> bool {
            let user_role = self.user_roles.read(user);
            self._role_hierarchy_value(user_role) >= self._role_hierarchy_value(required_role)
        }

        fn set_system_parameter(ref self: ContractState, key: felt252, value: u256) -> bool {
            // Check if parameter requires timelock
            if self.timelock_required_params.read(key) {
                assert(false, GovernanceErrors::REQUIRES_TIMELOCK);
            }

            self._require_minimum_role(AdminRole::Admin);
            self._require_system_not_paused();
            self._validate_parameter_bounds(key, value);

            let old_value = self.system_params.read(key);
            self._record_parameter_history(key, old_value, value);
            self.system_params.write(key, value);

            let caller = get_caller_address();
            self
                .emit(
                    SystemParameterUpdated { key, old_value, new_value: value, updated_by: caller },
                );
            true
        }

        fn set_system_parameter_with_timelock(
            ref self: ContractState, key: felt252, value: u256,
        ) -> bool {
            self._require_minimum_role(AdminRole::Admin);
            self._require_system_not_paused();
            self._validate_parameter_bounds(key, value);

            self.schedule_parameter_update(key, value)
        }

        fn get_system_parameter(self: @ContractState, key: felt252) -> u256 {
            self.system_params.read(key)
        }

        fn set_parameter_bounds(
            ref self: ContractState, key: felt252, bounds: ParameterBounds,
        ) -> bool {
            self._require_minimum_role(AdminRole::SuperAdmin);
            self._require_system_not_paused();

            assert(bounds.min_value <= bounds.max_value, GovernanceErrors::INVALID_BOUNDS);
            self.param_bounds.write(key, bounds);

            let caller = get_caller_address();
            self
                .emit(
                    ParameterBoundsSet {
                        key,
                        min_value: bounds.min_value,
                        max_value: bounds.max_value,
                        set_by: caller,
                    },
                );
            true
        }

        fn get_parameter_bounds(self: @ContractState, key: felt252) -> ParameterBounds {
            self.param_bounds.read(key)
        }

        fn register_contract(
            ref self: ContractState, name: felt252, contract_address: ContractAddress,
        ) -> bool {
            self._require_minimum_role(AdminRole::Admin);
            self._require_system_not_paused();

            // Check if already registered
            let existing = self.contract_registry.read(name);
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(existing == zero_address, GovernanceErrors::REGISTRY_KEY_EXISTS);

            self.contract_registry.write(name, contract_address);

            let caller = get_caller_address();
            self.emit(ContractRegistered { name, contract_address, registered_by: caller });
            true
        }

        fn update_contract_address(
            ref self: ContractState, name: felt252, new_address: ContractAddress,
        ) -> bool {
            self._require_minimum_role(AdminRole::SuperAdmin);
            self._require_system_not_paused();

            let old_address = self.contract_registry.read(name);
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(old_address != zero_address, GovernanceErrors::PARAM_NOT_FOUND);

            self.contract_registry.write(name, new_address);

            let caller = get_caller_address();
            self.emit(ContractUpdated { name, old_address, new_address, updated_by: caller });
            true
        }

        fn get_contract_address(self: @ContractState, name: felt252) -> ContractAddress {
            self.contract_registry.read(name)
        }

        fn is_contract_registered(self: @ContractState, name: felt252) -> bool {
            let address = self.contract_registry.read(name);
            let zero_address: ContractAddress = 0.try_into().unwrap();
            address != zero_address
        }

        fn schedule_parameter_update(ref self: ContractState, key: felt252, value: u256) -> bool {
            self._require_minimum_role(AdminRole::Admin);
            self._require_system_not_paused();
            self._validate_parameter_bounds(key, value);

            let current_time = get_block_timestamp();
            let executable_at = current_time + TIMELOCK_DURATION;

            let timelock_change = TimelockChange {
                key,
                value,
                proposer: get_caller_address(),
                proposed_at: current_time,
                executable_at,
                is_active: true,
            };

            self.pending_timelock_changes.write(key, timelock_change);

            self
                .emit(
                    TimelockScheduled { key, value, proposer: get_caller_address(), executable_at },
                );
            true
        }

        fn execute_timelock_update(ref self: ContractState, key: felt252) -> bool {
            self._require_minimum_role(AdminRole::Admin);
            self._require_system_not_paused();

            let timelock_change = self.pending_timelock_changes.read(key);
            assert(timelock_change.is_active, GovernanceErrors::TIMELOCK_NOT_FOUND);

            let current_time = get_block_timestamp();
            assert(
                current_time >= timelock_change.executable_at, GovernanceErrors::TIMELOCK_NOT_READY,
            );

            // Execute the change
            let old_value = self.system_params.read(key);
            self._record_parameter_history(key, old_value, timelock_change.value);
            self.system_params.write(key, timelock_change.value);

            // Clear the timelock
            let empty_timelock = TimelockChange {
                key: 0,
                value: 0,
                proposer: 0.try_into().unwrap(),
                proposed_at: 0,
                executable_at: 0,
                is_active: false,
            };
            self.pending_timelock_changes.write(key, empty_timelock);

            let caller = get_caller_address();
            self.emit(TimelockExecuted { key, value: timelock_change.value, executed_by: caller });
            self
                .emit(
                    SystemParameterUpdated {
                        key, old_value, new_value: timelock_change.value, updated_by: caller,
                    },
                );
            true
        }

        fn cancel_timelock_update(ref self: ContractState, key: felt252) -> bool {
            let timelock_change = self.pending_timelock_changes.read(key);
            assert(timelock_change.is_active, GovernanceErrors::TIMELOCK_NOT_FOUND);

            let caller = get_caller_address();
            let can_cancel = caller == timelock_change.proposer
                || self.has_minimum_role(caller, AdminRole::SuperAdmin);
            assert(can_cancel, GovernanceErrors::UNAUTHORIZED_CANCEL);

            // Clear the timelock
            let empty_timelock = TimelockChange {
                key: 0,
                value: 0,
                proposer: 0.try_into().unwrap(),
                proposed_at: 0,
                executable_at: 0,
                is_active: false,
            };
            self.pending_timelock_changes.write(key, empty_timelock);

            self.emit(TimelockCancelled { key, cancelled_by: caller });
            true
        }

        fn get_timelock_info(self: @ContractState, key: felt252) -> TimelockChange {
            self.pending_timelock_changes.read(key)
        }

        fn pause_system(ref self: ContractState) -> bool {
            self._require_minimum_role(AdminRole::SuperAdmin);

            self.system_paused.write(true);
            let caller = get_caller_address();
            self.emit(SystemPaused { paused_by: caller, timestamp: get_block_timestamp() });
            true
        }

        fn unpause_system(ref self: ContractState) -> bool {
            self._require_minimum_role(AdminRole::SuperAdmin);

            self.system_paused.write(false);
            let caller = get_caller_address();
            self.emit(SystemUnpaused { unpaused_by: caller, timestamp: get_block_timestamp() });
            true
        }

        fn is_system_paused(self: @ContractState) -> bool {
            self.system_paused.read()
        }

        fn update_fee(ref self: ContractState, fee_type: felt252, new_value: u256) -> bool {
            self._require_minimum_role(AdminRole::Admin);
            self._require_system_not_paused();

            let old_value = self.system_fees.read(fee_type);
            self.system_fees.write(fee_type, new_value);

            let caller = get_caller_address();
            self.emit(FeeUpdated { fee_type, old_value, new_value, updated_by: caller });
            true
        }

        fn get_fee(self: @ContractState, fee_type: felt252) -> u256 {
            self.system_fees.read(fee_type)
        }

        fn get_parameter_history_count(self: @ContractState, key: felt252) -> u256 {
            self.param_history_count.read(key)
        }

        fn get_parameter_history(
            self: @ContractState, key: felt252, index: u256,
        ) -> ParameterHistory {
            self.param_history.read((key, index))
        }

        fn get_timelock_duration(self: @ContractState) -> u64 {
            TIMELOCK_DURATION
        }

        fn requires_timelock(self: @ContractState, key: felt252) -> bool {
            self.timelock_required_params.read(key)
        }
    }

    // Internal helper functions
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _validate_kyc_and_limits(self: @ContractState, user: ContractAddress, amount: u256) {
            // Check KYC validity
            assert(self.is_kyc_valid(user), KYCErrors::INVALID_KYC_STATUS);

            // Check transaction limits
            let kyc_data = self.user_kyc_data.read(user);
            let level_u8 = self._kyc_level_to_u8(kyc_data.level);

            // Check single transaction limit
            let single_limit = self.single_limits.read(level_u8);
            assert(amount <= single_limit, KYCErrors::SINGLE_TX_LIMIT_EXCEEDED);

            // Check daily limit
            let daily_limit = self.daily_limits.read(level_u8);
            let current_usage = self._get_daily_usage(user);
            assert(current_usage + amount <= daily_limit, KYCErrors::DAILY_LIMIT_EXCEEDED);
        }

        fn _get_daily_usage(self: @ContractState, user: ContractAddress) -> u256 {
            let current_time = get_block_timestamp();
            let last_reset = self.last_reset.read(user);

            // Reset if it's a new day (86400 seconds = 24 hours)
            if current_time > last_reset + 86400 {
                return 0;
            }

            self.daily_usage.read(user)
        }

        fn _record_daily_usage(ref self: ContractState, user: ContractAddress, amount: u256) {
            let current_time = get_block_timestamp();
            let last_reset = self.last_reset.read(user);

            if current_time > last_reset + 86400 {
                // Reset for new day
                self.daily_usage.write(user, amount);
                self.last_reset.write(user, current_time);
            } else {
                // Add to current day usage
                let current_usage = self.daily_usage.read(user);
                self.daily_usage.write(user, current_usage + amount);
            }
        }

        fn _kyc_level_to_u8(self: @ContractState, level: KycLevel) -> u8 {
            match level {
                KycLevel::None => 0,
                KycLevel::Basic => 1,
                KycLevel::Enhanced => 2,
                KycLevel::Premium => 3,
            }
        }

        fn _set_default_transaction_limits(ref self: ContractState) {
            // None level - very restricted
            self.daily_limits.write(0, 100_000_000_000_000_000); // 0.1 tokens
            self.single_limits.write(0, 50_000_000_000_000_000); // 0.05 tokens

            // Basic level - moderate limits
            self.daily_limits.write(1, 1000_000_000_000_000_000_000); // 1,000 tokens
            self.single_limits.write(1, 500_000_000_000_000_000_000); // 500 tokens

            // Enhanced level - higher limits
            self.daily_limits.write(2, 10000_000_000_000_000_000_000); // 10,000 tokens
            self.single_limits.write(2, 5000_000_000_000_000_000_000); // 5,000 tokens

            // Premium level - maximum limits
            self.daily_limits.write(3, 100000_000_000_000_000_000_000); // 100,000 tokens
            self.single_limits.write(3, 50000_000_000_000_000_000_000); // 50,000 tokens
        }

        // Governance helper functions
        fn _require_minimum_role(self: @ContractState, required_role: AdminRole) {
            let caller = get_caller_address();
            let caller_role = self.user_roles.read(caller);
            assert(
                self
                    ._role_hierarchy_value(caller_role) >= self
                    ._role_hierarchy_value(required_role),
                GovernanceErrors::INSUFFICIENT_ROLE,
            );
        }

        fn _require_system_not_paused(self: @ContractState) {
            assert(!self.system_paused.read(), GovernanceErrors::SYSTEM_PAUSED);
        }

        fn _role_hierarchy_value(self: @ContractState, role: AdminRole) -> u8 {
            match role {
                AdminRole::None => 0,
                AdminRole::Operator => 1,
                AdminRole::KYCManager => 2,
                AdminRole::Admin => 3,
                AdminRole::SuperAdmin => 4,
            }
        }

        fn _validate_parameter_bounds(self: @ContractState, key: felt252, value: u256) {
            let bounds = self.param_bounds.read(key);
            if bounds.max_value > 0 { // Only validate if bounds are set
                assert(value >= bounds.min_value, GovernanceErrors::PARAM_OUT_OF_BOUNDS);
                assert(value <= bounds.max_value, GovernanceErrors::PARAM_OUT_OF_BOUNDS);
            }
        }

        fn _record_parameter_history(
            ref self: ContractState, key: felt252, old_value: u256, new_value: u256,
        ) {
            let count = self.param_history_count.read(key);
            let history = ParameterHistory {
                old_value,
                new_value,
                changed_by: get_caller_address(),
                changed_at: get_block_timestamp(),
            };
            self.param_history.write((key, count), history);
            self.param_history_count.write(key, count + 1);
        }

        fn _initialize_default_parameters(ref self: ContractState) {
            // Initialize default system parameters
            let gas_fee_key: felt252 = 'GAS_FEE';
            let service_fee_key: felt252 = 'SERVICE_FEE';
            let max_tx_amount_key: felt252 = 'MAX_TX_AMOUNT';

            self.system_params.write(gas_fee_key, 1000000000000000); // 0.001 tokens
            self.system_params.write(service_fee_key, 500000000000000); // 0.0005 tokens
            self.system_params.write(max_tx_amount_key, 1000000000000000000000000); // 1M tokens

            // Set parameter bounds
            self
                .param_bounds
                .write(
                    gas_fee_key,
                    ParameterBounds {
                        min_value: 0, max_value: 10000000000000000 // 0.01 tokens max
                    },
                );
            self
                .param_bounds
                .write(
                    service_fee_key,
                    ParameterBounds {
                        min_value: 0, max_value: 5000000000000000 // 0.005 tokens max
                    },
                );
            self
                .param_bounds
                .write(
                    max_tx_amount_key,
                    ParameterBounds {
                        min_value: 1000000000000000000, // 1 token min
                        max_value: 10000000000000000000000000 // 10M tokens max
                    },
                );
        }

        fn _initialize_timelock_required_params(ref self: ContractState) {
            // Parameters that require timelock for changes
            let max_tx_amount_key: felt252 = 'MAX_TX_AMOUNT';
            let critical_param_key: felt252 = 'CRITICAL_PARAM';

            self.timelock_required_params.write(max_tx_amount_key, true);
            self.timelock_required_params.write(critical_param_key, true);
        }
    }

    // Multi-currency functions
    #[generate_trait]
    impl MultiCurrencyFunctions of MultiCurrencyFunctionsTrait {
        // Registers a new supported currency
        // Only callable by admin
        fn register_currency(ref self: ContractState, currency: felt252) {
            let caller = get_caller_address();
            // Validate caller is admin
            assert(caller == self.admin.read(), ERC20Errors::NotAdmin); // "Only admin" in felt252

            // Register the currency
            self.supported_currencies.write(currency, true);
        }

        // Converts tokens from one currency to another
        // Returns the amount of tokens received in the target currency
        fn convert_currency(

        fn _record_transfer_history(
            ref self: ContractState,
            transfer_id: u256,
            action: felt252,
            actor: ContractAddress,
            previous_status: TransferStatus,
            new_status: TransferStatus,
            details: felt252,
        ) {
            let current_time = get_block_timestamp();

            // Create history entry
            let history = TransferHistory {
                transfer_id,
                action,
                actor,
                timestamp: current_time,
                previous_status,
                new_status,
                details,
            };

            // Store in transfer history
            let history_count = self.transfer_history_count.read(transfer_id);
            self.transfer_history.write((transfer_id, history_count), history);
            self.transfer_history_count.write(transfer_id, history_count + 1);

            // Store in actor history
            let actor_count = self.actor_history_count.read(actor);
            self.actor_history.write((actor, actor_count), (transfer_id, history_count));
            self.actor_history_count.write(actor, actor_count + 1);

            // Store in action history
            let action_count = self.action_history_count.read(action);
            self.action_history.write((action, action_count), (transfer_id, history_count));
            self.action_history_count.write(action, action_count + 1);

            // Emit event
            self
                .emit(
                    TransferHistoryRecorded { transfer_id, action, actor, timestamp: current_time },
                );
        }

        // Generates and stores a new unique group ID for a savings group
        // Returns the newly generated group ID
        fn _new_group_id(ref self: ContractState) -> u64 {
            let group_id = self.group_count.read();

            self.group_count.write(group_id + 1);

            group_id
        }
    }
}
