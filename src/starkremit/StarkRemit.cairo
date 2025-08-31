use core::array::ArrayTrait;
use core::num::traits::Zero;
use openzeppelin::access::accesscontrol::AccessControlComponent;
use openzeppelin::access::ownable::OwnableComponent;
use openzeppelin::introspection::src5::SRC5Component;
use openzeppelin::upgrades::UpgradeableComponent;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
use starkremit_contract::base::errors::{
    GovernanceErrors, GroupErrors, KYCErrors, RegistrationErrors, TransferErrors, EmergencyErrors,
};
use starkremit_contract::base::events::*;
use starkremit_contract::base::types::{
    Agent, AgentStatus, ContributionRound, GovRole, KYCLevel, KycLevel, KycStatus, LoanRequest,
    LoanStatus, MemberContribution, ParameterBounds, ParameterHistory, RegistrationRequest,
    RegistrationStatus, RoundStatus, SavingsGroup, TimelockChange, TransferData, TransferHistory,
    TransferStatus, UserKycData, UserProfile, PenaltyConfig, MemberPenaltyRecord, PenaltyEventRecord, DistributionData, MemberShare, PenaltyEventType,
    AutoScheduleConfig, ScheduledRound, RoundData,
};
use starkremit_contract::interfaces::IStarkRemit;
use starkremit_contract::component::emergency::IEmergency;
use starkremit_contract::component::penalty::{IPenalty, IMainContractData as PenaltyMainContractData};
use starkremit_contract::component::auto_schedule::{IAutoSchedule, IMainContractData as AutoScheduleMainContractData};
use starkremit_contract::component::payment_flexibility::{PaymentConfig, PaymentFrequency, AutoPaymentSetup, PaymentStatus, PaymentRecord, IMainContractData as PaymentFlexibilityMainContractData};
// use starkremit_contract::component::member_profile::MemberProfile;
// use starkremit_contract::component::analytics::{
//     ContributionAnalytics, MemberAnalytics, RoundPerformanceMetrics, FinancialReport, SystemHealthMetrics
// };


const INTEREST_RATE: u256 = 500; // 5% in basis points (0.05 * 10000)
const LATE_PENALTY_RATE: u256 = 100; // 1% per day in basis points (0.01 * 10000)
const LOAN_TERM_DAYS: u64 = 30 * 24 * 60 * 60; // 30 days in seconds


#[starknet::contract]
pub mod StarkRemit {
    use starkremit_contract::component::agent::agent_component;
    use starkremit_contract::component::contribution::contribution::contribution_component;
    use starkremit_contract::component::kyc::kyc_component;
    use starkremit_contract::component::loan::loan_component;
    use starkremit_contract::component::savings_group::savings_group_component;
    use starkremit_contract::component::token_management::token_management_component;
    use starkremit_contract::component::transfer::transfer_component;
    use starkremit_contract::component::user_management::user_management_component;
    use starkremit_contract::component::emergency::emergency_component;
    use starkremit_contract::component::penalty::penalty_component;
    use starkremit_contract::component::payment_flexibility::payment_flexibility_component;
    use starkremit_contract::component::auto_schedule::auto_schedule_component;
    // use starkremit_contract::component::member_profile::member_profile_component;
    // use starkremit_contract::component::analytics::analytics_component;

    use super::*;

    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: SRC5Component, storage: src5, event: Src5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: agent_component, storage: agent_component, event: AgentEvent);
    component!(
        path: user_management_component,
        storage: user_management_component,
        event: UserManagementEvent,
    );
    component!(
        path: contribution_component, storage: contribution_component, event: ContributionEvent,
    );
    component!(path: kyc_component, storage: kyc_component, event: KycEvent);
    component!(path: loan_component, storage: loan_component, event: LoanEvent);
    component!(
        path: savings_group_component, storage: savings_group_component, event: SavingsGroupEvent,
    );
    component!(
        path: token_management_component,
        storage: token_management_component,
        event: TokenManagementEvent,
    );
    component!(path: transfer_component, storage: transfer_component, event: TransferEvent);
    component!(path: emergency_component, storage: emergency, event: EmergencyEvent);
    component!(path: penalty_component, storage: penalty, event: PenaltyEvent);
    component!(path: auto_schedule_component, storage: auto_schedule, event: AutoScheduleEvent);
    component!(path: payment_flexibility_component, storage: payment_flexibility, event: PaymentFlexibilityEvent);
        // component!(path: member_profile_component, storage: member_profile, event: MemberProfileEvent);
        // component!(path: analytics_component, storage: analytics, event: AnalyticsEvent);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Agent Component (internal use only - functions exposed via IStarkRemit)
    impl AgentComponentImpl = agent_component::AgentComponent<ContractState>;

    // User Management Component (internal use only - functions exposed via IStarkRemit)
    impl UserManagementImpl = user_management_component::UserManagement<ContractState>;

    // Contribution Component (internal use only - functions exposed via IStarkRemit)
    impl ContributionImpl = contribution_component::Contribution<ContractState>;

    // KYC Component (internal use only - functions exposed via IStarkRemit)
    impl KycImpl = kyc_component::KYC<ContractState>;

    // Loan Component (internal use only - functions exposed via IStarkRemit)
    impl LoanImpl = loan_component::Loan<ContractState>;

    // Savings Group Component (internal use only - functions exposed via IStarkRemit)
    impl SavingsGroupImpl = savings_group_component::SavingsGroupComponent<ContractState>;

    // Token Management Component (internal use only - functions exposed via IStarkRemit)
    impl TokenManagementImpl = token_management_component::TokenManagement<ContractState>;

    // Transfer Component (internal use only - functions exposed via IStarkRemit)
    impl TransferImpl = transfer_component::Transfer<ContractState>;

    // Emergency component internal methods
    impl EmergencyInternalImpl = emergency_component::InternalImpl<ContractState>;

    // Penalty Component 
    impl PenaltyInternalImpl = penalty_component::InternalImpl<ContractState>;

    // Auto Schedule Component (internal use only - functions exposed via IStarkRemit)
    impl AutoScheduleInternalImpl = auto_schedule_component::InternalImpl<ContractState>;
    
    // Payment Flexibility Component (internal use only - functions exposed via IStarkRemit)
    impl PaymentFlexibilityInternalImpl = payment_flexibility_component::InternalImpl<ContractState>;

    // Member Profile Component (internal use only - functions exposed via IStarkRemit)
    // impl MemberProfileImpl = member_profile_component::MemberProfileImpl<ContractState>;
    // impl MemberProfileInternalImpl = member_profile_component::InternalImpl<ContractState>;

    // Payment Flexibility Component (internal use only - functions exposed via IStarkRemit)
    // impl PaymentFlexibilityImpl = payment_flexibility_component::PaymentFlexibilityImpl<ContractState>;
    // impl PaymentFlexibilityInternalImpl = payment_flexibility_component::InternalImpl<ContractState>;

    // Analytics Component (internal use only - functions exposed via IStarkRemit)
    // impl AnalyticsImpl = analytics_component::AnalyticsImpl<ContractState>;
    // impl AnalyticsInternalImpl = analytics_component::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    const PROTOCOL_OWNER_ROLE: felt252 = selector!("PROTOCOL_OWNER");
    const ADMIN_ROLE: felt252 = selector!("ADMIN");

    // --- System Management Enums & Structs ---
    #[derive(Copy, Drop, Serde)]
    enum PermissionLevel {
        Read,
        Write,
        Admin,
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct MultiSigOperation {
        target_contract: ContractAddress,
        selector: felt252,
        calldata_len: u128,
        confirmations_count: u32,
        executed: bool,
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct UpgradeRecord {
        version: u64,
        class_hash: felt252,
        timestamp: u64,
        upgraded_by: ContractAddress,
    }

    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub struct AuditEntry {
        action: felt252,
        actor: ContractAddress,
        timestamp: u64,
        details: felt252,
    }
    #[allow(starknet::store_no_default_variant)]
    #[derive(Copy, Drop, Serde, starknet::Store)]
    pub enum MultiSigStatus {
        Pending,
        Approved,
        Executed,
        Rejected,
    }

    // --- System Management Events ---

    #[derive(Drop, starknet::Event)]
    pub struct AgentAuthorized {
        agent_address: ContractAddress,
        permission: felt252,
        authorized: bool,
        caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AgentPermissionUpdated {
        agent_address: ContractAddress,
        permission: felt252,
        authorized: bool,
        caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AgentPermissionRevoked {
        agent_address: ContractAddress,
        permission: felt252,
        revoked_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContractUpgradeInitiated {
        old_class_hash: felt252,
        new_class_hash: felt252,
        version: u64,
        caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContractUpgradeCompleted {
        old_class_hash: felt252,
        new_class_hash: felt252,
        version: u64,
        caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContractUpgradeRolledBack {
        old_class_hash: felt252,
        new_class_hash: felt252,
        target_version: u64,
        caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EmergencyPauseActivated {
        function_selector: felt252,
        caller: ContractAddress,
        expires_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EmergencyPauseDeactivated {
        function_selector: felt252,
        caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MultiSigOperationProposed {
        op_id: felt252,
        target_contract: ContractAddress,
        selector: felt252,
        proposer: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MultiSigOperationApproved {
        op_id: felt252,
        approver: ContractAddress,
        confirmations_count: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MultiSigOperationExecuted {
        op_id: felt252,
        executor: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MultiSigOperationRejected {
        op_id: felt252,
        rejector: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AuditTrailEntry {
        action: felt252,
        actor: ContractAddress,
        timestamp: u64,
        details: felt252,
    }

    // Event definitions
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        Src5Event: SRC5Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        // Component events (not flattened to avoid duplicates with main contract events)
        AgentEvent: agent_component::Event,
        UserManagementEvent: user_management_component::Event,
        ContributionEvent: contribution_component::Event,
        KycEvent: kyc_component::Event,
        LoanEvent: loan_component::Event,
        SavingsGroupEvent: savings_group_component::Event,
        TokenManagementEvent: token_management_component::Event,
        TransferEvent: transfer_component::Event,
        EmergencyEvent: emergency_component::Event,
        PenaltyEvent: penalty_component::Event,
        AutoScheduleEvent: auto_schedule_component::Event,
        PaymentFlexibilityEvent: payment_flexibility_component::Event,
        // System Management Events
        AgentAuthorized: AgentAuthorized,
        AgentPermissionUpdated: AgentPermissionUpdated,
        AgentPermissionRevoked: AgentPermissionRevoked,
        ContractUpgradeInitiated: ContractUpgradeInitiated,
        ContractUpgradeCompleted: ContractUpgradeCompleted,
        ContractUpgradeRolledBack: ContractUpgradeRolledBack,
        EmergencyPauseActivated: EmergencyPauseActivated,
        EmergencyPauseDeactivated: EmergencyPauseDeactivated,
        MultiSigOperationProposed: MultiSigOperationProposed,
        MultiSigOperationApproved: MultiSigOperationApproved,
        MultiSigOperationExecuted: MultiSigOperationExecuted,
        MultiSigOperationRejected: MultiSigOperationRejected,
        AuditTrailEntry: AuditTrailEntry,
        // Main contract events (not duplicated by components)
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
        // Governance Events
        AdminAssigned: AdminAssigned,
        AdminRevoked: AdminRevoked,
        ContractRegistered: ContractRegistered,
        SystemParamUpdated: SystemParamUpdated,
        FeeUpdated: FeeUpdated,
        UpdateScheduled: UpdateScheduled,
        UpdateExecuted: UpdateExecuted,
        UpdateCancelled: UpdateCancelled,
        // loan_id -> timestamp_of_last_payment
        EmergencyWithdrawalAll: EmergencyWithdrawalAll,
        EmergencyWithdrawalMember: EmergencyWithdrawalMember,
        RoundEmergencyCompleted: RoundEmergencyCompleted,
        RoundEmergencyCancelled: RoundEmergencyCancelled,
        RecipientChanged: RecipientChanged,
        TokensRecovered: TokensRecovered,
        FundsMigrated: FundsMigrated,
        MemberBanned: MemberBanned,
        MemberUnbanned: MemberUnbanned,
        PenaltyPoolDistributed: PenaltyPoolDistributed,
        // LateFeeApplied: LateFeeApplied,
        // StrikeAdded: StrikeAdded,
        // StrikeRemoved: StrikeRemoved,
        // AutoPaymentSetup: AutoPaymentSetup,
        // EarlyPaymentProcessed: EarlyPaymentProcessed,
        // GracePeriodExtended: GracePeriodExtended,
        // TokenValueConverted: TokenValueConverted,
        // MemberProfileUpdated: MemberProfileUpdated,
        // RollingScheduleMaintained: RollingScheduleMaintained,
    }


    // #[derive(Drop, starknet::Event)]
    // pub struct LateFeeApplied {
    //     pub member: ContractAddress,
    //     pub round_id: u256,
    //     pub fee_amount: u256,
    //     pub contribution_amount: u256,
    //     pub timestamp: u64,
    // }



    // #[derive(Drop, starknet::Event)]
    // pub struct StrikeAdded {
    //     pub member: ContractAddress,
    //     pub round_id: u256,
    //     pub current_strikes: u32,
    //     pub timestamp: u64,
    // }

    // #[derive(Drop, starknet::Event)]
    // pub struct StrikeRemoved {
    //     pub member: ContractAddress,
    //     pub removed_by: ContractAddress,
    //     pub new_strikes: u32,
    //     pub timestamp: u64,
    // }



    // #[derive(Drop, starknet::Event)]
    // pub struct AutoPaymentSetup {
    //     pub member: ContractAddress,
    //     pub token: ContractAddress,
    //     pub amount: u256,
    //     pub frequency: PaymentFrequency,
    //     pub next_payment_date: u64,
    //     pub timestamp: u64,
    // }

    // #[derive(Drop, starknet::Event)]
    // pub struct EarlyPaymentProcessed {
    //     pub member: ContractAddress,
    //     pub round_id: u256,
    //     pub original_amount: u256,
    //     pub discount_amount: u256,
    //     pub final_amount: u256,
    //     pub timestamp: u64,
    // }

    // #[derive(Drop, starknet::Event)]
    // pub struct GracePeriodExtended {
    //     pub member: ContractAddress,
    //     pub extension_hours: u64,
    //     pub total_extension: u64,
    //     pub extended_by: ContractAddress,
    //     pub timestamp: u64,
    // }

    // #[derive(Drop, starknet::Event)]
    // pub struct TokenValueConverted {
    //     pub member: ContractAddress,
    //     pub from_token: ContractAddress,
    //     pub to_token: ContractAddress,
    //     pub original_amount: u256,
    //     pub converted_amount: u256,
    //     pub from_price: u256,
    //     pub to_price: u256,
    //     pub timestamp: u64,
    // }

    // #[derive(Drop, starknet::Event)]
    // pub struct MemberProfileUpdated {
    //     pub member: ContractAddress,
    //     pub field: felt252,
    //     pub old_value: felt252,
    //     pub new_value: felt252,
    //     pub updated_by: ContractAddress,
    //     pub timestamp: u64,
    // }



    // #[derive(Drop, starknet::Event)]
    // pub struct RollingScheduleMaintained {
    //     pub rounds_created: u32,
    //     pub last_maintenance_timestamp: u64,
    // }

    // Contract storage definition
    #[storage]
    #[allow(starknet::colliding_storage_paths)]
    struct Storage {
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        agent_component: agent_component::Storage,
        #[substorage(v0)]
        user_management_component: user_management_component::Storage,
        #[substorage(v0)]
        contribution_component: contribution_component::Storage,
        #[substorage(v0)]
        kyc_component: kyc_component::Storage,
        #[substorage(v0)]
        loan_component: loan_component::Storage,
        #[substorage(v0)]
        savings_group_component: savings_group_component::Storage,
        #[substorage(v0)]
        token_management_component: token_management_component::Storage,
        #[substorage(v0)]
        transfer_component: transfer_component::Storage,
        #[substorage(v0)]
        emergency: emergency_component::Storage,
        #[substorage(v0)]
        penalty: penalty_component::Storage,
        #[substorage(v0)]
        auto_schedule: auto_schedule_component::Storage,
        #[substorage(v0)]
        payment_flexibility: payment_flexibility_component::Storage,
        // Emergency and Penalty System Storage
        emergency_approvals: Map<felt252, Map<ContractAddress, bool>>,
        // penalty_config: PenaltyConfig,
        // emergency_operations: Map<felt252, EmergencyOperation>,
        // Penalty System Storage
        // member_penalties: Map<ContractAddress, MemberPenaltyRecord>,
        // penalty_pool: u256,
        // penalty history stored as (member, index) -> event and per-member count
        // penalty_history: Map<(ContractAddress, u32), PenaltyEvent>,
        // penalty_history_count: Map<ContractAddress, u32>,
        // Auto-Schedule System Storage
        // auto_schedule_config: AutoScheduleConfig,
        // scheduled_rounds: Map<u256, ScheduledRound>,
        // round_schedule_index: u256,
        // last_schedule_maintenance: u64,
        // schedule_maintenance_interval: u64,
        // Member Profile Storage
        // member_profiles: Map<ContractAddress, MemberProfile>,
        // member_profile_count: u32,
        // Payment Flexibility Storage
        // payment_config: PaymentConfig,
        // auto_payment_setups: Map<ContractAddress, AutoPaymentSetup>,
        // Analytics Storage
        // contribution_analytics: ContributionAnalytics,
        // member_analytics: Map<ContractAddress, MemberAnalytics>,
        // last_analytics_update: u64,
        // System Management Storage
        agent_permissions: Map<(ContractAddress, felt252), bool>, // (agent, permission) -> granted
        paused_functions: Map<felt252, bool>, // function selector -> paused
        multi_sig_operations: Map<felt252, MultiSigOperation>, // op_id -> operation data
        multi_sig_approvals: Map<(felt252, ContractAddress), bool>, // (op_id, approver) -> approved
        multi_sig_status: Map<felt252, MultiSigStatus>, // op_id -> status
        multi_sig_required: u32, // Number of required approvals
        multi_sig_pending: Map<felt252, u32>, // op_id -> current approvals
        upgrade_history: Map<u32, UpgradeRecord>, // upgrade index -> record
        upgrade_count: u32, // number of upgrades
        audit_trail: Map<u256, AuditEntry>, // audit log
        audit_count: u256,
        emergency_pause_expiry: Map<felt252, u64>, // function selector -> expiry timestamp
        // Existing storage
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
        // Governance storage
        admin_roles: Map<ContractAddress, GovRole>, // User governance roles
        param_bounds: Map<felt252, ParameterBounds>, // Parameter bounds (min, max)
        system_params: Map<felt252, u256>, // System parameter values
        pending_changes: Map<felt252, TimelockChange>, // Pending parameter changes
        contract_registry: Map<felt252, ContractAddress>, // Contract registry mapping
        param_history: Map<(felt252, u32), ParameterHistory>, // Parameter change history
        param_history_count: Map<felt252, u32>, // Parameter history count per key
        timelock_duration: u64 // Timelock duration for parameter changes
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
        self.owner.write(owner);
        self.token_address.write(token_address);
        self.accesscontrol.initializer();
        self.accesscontrol._grant_role(PROTOCOL_OWNER_ROLE, owner);

        // initialize owner
        self.ownable.initializer(owner);

        // Initialize governance
        self.admin_roles.write(owner, GovRole::SuperAdmin);
        self.timelock_duration.write(86400); // 24 hours default timelock
        // Initialize emergency component
        self.emergency.initializer(owner);
        // Initialize penalty component
        self.penalty.initializer(owner);
        // Initialize auto-schedule component
        self.auto_schedule.initializer(owner);
        // Initialize payment flexibility component
        self.payment_flexibility.initializer(owner);
    }

    // Implementation of the StarkRemit interface with KYC functions
    #[abi(embed_v0)]
    impl IStarkRemitImpl of IStarkRemit::IStarkRemit<ContractState> {
        // --- Penalty Functions ---
        fn apply_late_fee(ref self: ContractState, member: ContractAddress, round_id: u256) {
            self.ownable.assert_only_owner();
            self.penalty.apply_late_fee(member, round_id);
        }

        fn add_strike(ref self: ContractState, member: ContractAddress, round_id: u256) {
            self.ownable.assert_only_owner();
            
            // Get current penalty record to check if member will be automatically banned
            let current_record = self.penalty.get_member_penalty_record(member);
            let penalty_config = self.penalty.get_penalty_config();
            let will_be_banned = current_record.strikes + 1 >= penalty_config.max_strikes;
            
            // Add strike in penalty component
            self.penalty.add_strike(member, round_id);
            
            // If member was automatically banned, remove them from main contract's member list
            if will_be_banned {
                self._remove_member_from_list(member);
                
                // Emit main contract event for automatic ban
                self.emit(Event::MemberBanned(MemberBanned {
                    member,
                    reason: 'max_strikes_reached',
                    strikes: current_record.strikes + 1,
                    banned_by: get_caller_address(),
                    timestamp: get_block_timestamp(),
                }));
            }
        }

        fn remove_strike(ref self: ContractState, member: ContractAddress) {
            self.ownable.assert_only_owner();
            
            // Get current penalty record to check if member will be automatically unbanned
            let current_record = self.penalty.get_member_penalty_record(member);
            let penalty_config = self.penalty.get_penalty_config();
            let will_be_unbanned = current_record.is_banned && current_record.strikes - 1 < penalty_config.max_strikes;
            
            // Remove strike in penalty component
            self.penalty.remove_strike(member);
            
            // If member was automatically unbanned, re-add them to main contract's member list
            if will_be_unbanned {
                self._add_member_to_list(member);
                
                // Emit main contract event for automatic unban
                self.emit(Event::MemberUnbanned(MemberUnbanned {
                    member,
                    unbanned_by: get_caller_address(),
                    timestamp: get_block_timestamp(),
                }));
            }
        }

        fn ban_member(ref self: ContractState, member: ContractAddress) {
            self.ownable.assert_only_owner();
            
            // First, update penalty state in component
            self.penalty.ban_member(member);
            
            // Then, remove member from main contract's member list
            self._remove_member_from_list(member);
            
            // Emit main contract event
            self.emit(Event::MemberBanned(MemberBanned {
                member,
                reason: 'admin_ban',
                strikes: self.penalty.get_member_penalty_record(member).strikes,
                banned_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            }));
        }

        fn unban_member(ref self: ContractState, member: ContractAddress) {
            self.ownable.assert_only_owner();
            
            // First, update penalty state in component
            self.penalty.unban_member(member);
            
            // Then, re-add member to main contract's member list
            self._add_member_to_list(member);
            
            // Emit main contract event
            self.emit(Event::MemberUnbanned(MemberUnbanned {
                member,
                unbanned_by: get_caller_address(),
                timestamp: get_block_timestamp(),
            }));
        }

        fn distribute_penalty_pool(ref self: ContractState) {
            self.ownable.assert_only_owner();
            
            // Get distribution data from penalty component
            let distribution_data = self.penalty.calculate_distribution_data();
            
            if distribution_data.total_amount == 0 {
                return; // No penalty pool to distribute
            }
            
            // Execute transfers using main contract's transfer function
            let mut distributed_count = 0;
            let mut i = 0;
            
            while i < distribution_data.member_shares.len() {
                let member_share = *distribution_data.member_shares.at(i);
                if member_share.share > 0 {
                    // Transfer tokens to member
                    self.transfer_tokens_to_member(member_share.member, member_share.share);
                    distributed_count += 1;
                }
                i += 1;
            }
            
            // Reset penalty pool in component after successful distribution
            self.penalty.reset_penalty_pool();
            
            // Emit main contract event
            self.emit(Event::PenaltyPoolDistributed(PenaltyPoolDistributed {
                total_amount: distribution_data.total_amount,
                recipient_count: distributed_count,
                distribution_type: 'proportional',
                timestamp: get_block_timestamp(),
            }));
        }

        
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
            let _ = get_caller_address();
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
            let _ = get_caller_address();
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
            assert(
                Self::is_user_registered(@self, user_address), RegistrationErrors::USER_NOT_FOUND,
            );

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
            assert(
                Self::is_user_registered(@self, user_address), RegistrationErrors::USER_NOT_FOUND,
            );

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
            assert(Self::is_user_registered(@self, caller), 'Sender not registered');
            assert(Self::is_user_registered(@self, recipient), 'Recipient not registered');

            // Enhanced KYC validation if enforcement is enabled
            if self.kyc_enforcement_enabled.read() {
                InternalFunctions::_validate_kyc_and_limits(@self, caller, amount);
                InternalFunctions::_validate_kyc_and_limits(@self, recipient, amount);

                // Additional KYC checks for large amounts
                if amount > 10000_000_000_000_000_000_000 { // > 10,000 tokens
                    let (_caller_status, caller_level) = Self::get_kyc_status(@self, caller);
                    let (_recipient_status, recipient_level) = Self::get_kyc_status(
                        @self, recipient,
                    );
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
                Self::is_agent_authorized(@self, caller, transfer_id),
                TransferErrors::AGENT_NOT_AUTHORIZED,
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
            let _ = get_caller_address();
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

            assert(group_id <= self.group_count.read(), GroupErrors::INVALID_GROUP_ID);
            let mut group = self.groups.read(group_id);

            assert(group.created_at > 0, GroupErrors::GROUP_NOT_CREATED);
            assert(group.is_active, GroupErrors::GROUP_NOT_ACTIVE);
            assert(!self.group_members.read((group_id, caller)), GroupErrors::ALREADY_MEMBER);
            assert(
                group.max_members > 0 && group.max_members <= 100, GroupErrors::INVALID_GROUP_SIZE,
            );
            assert(group.member_count < (group.max_members).into(), GroupErrors::GROUP_FULL);

            group.member_count += 1;
            assert(group.member_count >= 2, GroupErrors::INVALID_GROUP_SIZE);
            self.groups.write(group_id, group);

            self.group_members.write((group_id, caller), true);
        }

        fn view_group(self: @ContractState, group_id: u64) -> SavingsGroup {
            assert(group_id <= self.group_count.read(), GroupErrors::INVALID_GROUP_ID);

            let group = self.groups.read(group_id);
            assert(group.created_at > 0, GroupErrors::GROUP_NOT_CREATED);

            group
        }

        fn confirm_group_membership(self: @ContractState, group_id: u64) -> bool {
            assert(group_id <= self.group_count.read(), GroupErrors::INVALID_GROUP_ID);
            self.group_members.read((group_id, get_caller_address()))
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

        /// Assign a governance role to a user (SuperAdmin only)
        fn assign_admin_role(
            ref self: ContractState, user: ContractAddress, role: GovRole,
        ) -> bool {
            let caller = get_caller_address();
            assert(
                self.admin_roles.read(caller) == GovRole::SuperAdmin,
                GovernanceErrors::NOT_SUPERADMIN,
            );
            self.admin_roles.write(user, role);
            self.emit(AdminAssigned { user, role });
            true
        }
        /// Revoke a user's governance role (SuperAdmin only)
        fn revoke_admin_role(ref self: ContractState, user: ContractAddress) -> bool {
            let caller = get_caller_address();
            assert(
                self.admin_roles.read(caller) == GovRole::SuperAdmin,
                GovernanceErrors::NOT_SUPERADMIN,
            );
            self.admin_roles.write(user, GovRole::None);
            self.emit(AdminRevoked { user });
            true
        }
        /// Get the governance role of a user
        fn get_admin_role(self: @ContractState, user: ContractAddress) -> GovRole {
            self.admin_roles.read(user)
        }

        /// Check if user has minimum required role
        fn has_minimum_role(
            self: @ContractState, user: ContractAddress, required_role: GovRole,
        ) -> bool {
            let user_role = self.admin_roles.read(user);
            match required_role {
                GovRole::None => true,
                GovRole::Operator => user_role == GovRole::Operator
                    || user_role == GovRole::Admin
                    || user_role == GovRole::SuperAdmin,
                GovRole::Admin => user_role == GovRole::Admin || user_role == GovRole::SuperAdmin,
                GovRole::SuperAdmin => user_role == GovRole::SuperAdmin,
            }
        }

        /// Set parameter bounds for a system parameter (SuperAdmin only)
        fn set_parameter_bounds(
            ref self: ContractState, key: felt252, bounds: ParameterBounds,
        ) -> bool {
            let caller = get_caller_address();
            assert(
                self.admin_roles.read(caller) == GovRole::SuperAdmin,
                GovernanceErrors::NOT_SUPERADMIN,
            );
            self.param_bounds.write(key, bounds);
            true
        }
        /// Set a system parameter value (SuperAdmin only, checks bounds)
        fn set_system_parameter(ref self: ContractState, key: felt252, value: u256) -> bool {
            let caller = get_caller_address();
            assert(
                self.admin_roles.read(caller) == GovRole::SuperAdmin,
                GovernanceErrors::NOT_SUPERADMIN,
            );
            let bounds = self.param_bounds.read(key);
            assert(
                value >= bounds.min_value && value <= bounds.max_value,
                GovernanceErrors::OUT_OF_BOUNDS,
            );

            // Record history
            let old_value = self.system_params.read(key);
            let history_count = self.param_history_count.read(key);
            let history = ParameterHistory {
                old_value, new_value: value, changed_by: caller, changed_at: get_block_timestamp(),
            };
            self.param_history.write((key, history_count), history);
            self.param_history_count.write(key, history_count + 1);

            self.system_params.write(key, value);
            self.emit(SystemParamUpdated { key, value });
            true
        }

        /// Set parameter with timelock (SuperAdmin only)
        fn set_system_parameter_with_timelock(
            ref self: ContractState, key: felt252, value: u256,
        ) -> bool {
            self.schedule_parameter_update(key, value)
        }

        /// Get system parameter value
        fn get_system_parameter(self: @ContractState, key: felt252) -> u256 {
            self.system_params.read(key)
        }

        /// Get parameter bounds
        fn get_parameter_bounds(self: @ContractState, key: felt252) -> ParameterBounds {
            self.param_bounds.read(key)
        }
        /// Register a contract in the registry (Admin or higher)
        fn register_contract(
            ref self: ContractState, name: felt252, contract_address: ContractAddress,
        ) -> bool {
            let caller = get_caller_address();
            let role = self.admin_roles.read(caller);
            assert(
                role == GovRole::SuperAdmin || role == GovRole::Admin, GovernanceErrors::NOT_ADMIN,
            );
            assert(contract_address != 0.try_into().unwrap(), GovernanceErrors::ZERO_ADDRESS);
            //
            // Check if registry key already exists
            assert(!self.is_contract_registered(name), GovernanceErrors::REGISTRY_KEY_EXISTS);

            self.contract_registry.write(name, contract_address);
            self.emit(ContractRegistered { name, addr: contract_address });
            true
        }
        /// Get a contract address from the registry
        fn get_contract_address(self: @ContractState, name: felt252) -> ContractAddress {
            self.contract_registry.read(name)
        }

        /// Check if contract is registered
        fn is_contract_registered(self: @ContractState, name: felt252) -> bool {
            self.contract_registry.read(name) != 0.try_into().unwrap()
        }

        /// Update contract address in registry (Admin or higher)
        fn update_contract_address(
            ref self: ContractState, name: felt252, new_address: ContractAddress,
        ) -> bool {
            let caller = get_caller_address();
            let role = self.admin_roles.read(caller);
            assert(
                role == GovRole::SuperAdmin || role == GovRole::Admin, GovernanceErrors::NOT_ADMIN,
            );
            assert(new_address != 0.try_into().unwrap(), GovernanceErrors::ZERO_ADDRESS);
            assert(self.is_contract_registered(name), GovernanceErrors::PARAM_NOT_FOUND);

            self.contract_registry.write(name, new_address);
            self.emit(ContractRegistered { name, addr: new_address });
            true
        }
        
        /// Schedule a parameter update (SuperAdmin only, timelock)
        fn schedule_parameter_update(ref self: ContractState, key: felt252, value: u256) -> bool {
            let caller = get_caller_address();
            assert(
                self.admin_roles.read(caller) == GovRole::SuperAdmin,
                GovernanceErrors::NOT_SUPERADMIN,
            );
            let now = get_block_timestamp();
            let timelock_change = TimelockChange {
                key,
                value,
                proposer: caller,
                proposed_at: now,
                executable_at: now + self.timelock_duration.read(),
                is_active: true,
            };
            self.pending_changes.write(key, timelock_change);
            self.emit(UpdateScheduled { key, value, timestamp: now });
            true
        }

        /// Execute a scheduled parameter update (SuperAdmin only, after timelock)
        fn execute_timelock_update(ref self: ContractState, key: felt252) -> bool {
            let caller = get_caller_address();
            assert(
                self.admin_roles.read(caller) == GovRole::SuperAdmin,
                GovernanceErrors::NOT_SUPERADMIN,
            );
            let timelock_change = self.pending_changes.read(key);
            let now = get_block_timestamp();
            assert(timelock_change.is_active, GovernanceErrors::NOT_ALLOWED);
            assert(now >= timelock_change.executable_at, GovernanceErrors::TIMELOCK);

            let bounds = self.param_bounds.read(key);
            assert(
                timelock_change.value >= bounds.min_value
                    && timelock_change.value <= bounds.max_value,
                GovernanceErrors::OUT_OF_BOUNDS,
            );

            // Record history
            let old_value = self.system_params.read(key);
            let history_count = self.param_history_count.read(key);
            let history = ParameterHistory {
                old_value, new_value: timelock_change.value, changed_by: caller, changed_at: now,
            };
            self.param_history.write((key, history_count), history);
            self.param_history_count.write(key, history_count + 1);

            self.system_params.write(key, timelock_change.value);
            self.emit(UpdateExecuted { key, value: timelock_change.value });

            // Clear the pending change
            let empty_change = TimelockChange {
                key: 0,
                value: 0,
                proposer: 0.try_into().unwrap(),
                proposed_at: 0,
                executable_at: 0,
                is_active: false,
            };
            self.pending_changes.write(key, empty_change);
            true
        }

        /// Cancel a scheduled parameter update (SuperAdmin or proposer)
        fn cancel_timelock_update(ref self: ContractState, key: felt252) -> bool {
            let timelock_change = self.pending_changes.read(key);
            let caller = get_caller_address();
            let caller_role = self.admin_roles.read(caller);
            assert(
                caller == timelock_change.proposer || caller_role == GovRole::SuperAdmin,
                GovernanceErrors::NOT_ALLOWED,
            );
            assert(timelock_change.is_active, GovernanceErrors::NOT_ALLOWED);

            let empty_change = TimelockChange {
                key: 0,
                value: 0,
                proposer: 0.try_into().unwrap(),
                proposed_at: 0,
                executable_at: 0,
                is_active: false,
            };
            self.pending_changes.write(key, empty_change);
            self.emit(UpdateCancelled { key });
            true
        }

        /// Get timelock info
        fn get_timelock_info(self: @ContractState, key: felt252) -> TimelockChange {
            self.pending_changes.read(key)
        }
        /// Update fee (SuperAdmin only)
        fn update_fee(ref self: ContractState, fee_type: felt252, new_value: u256) -> bool {
            let caller = get_caller_address();
            assert(
                self.admin_roles.read(caller) == GovRole::SuperAdmin,
                GovernanceErrors::NOT_SUPERADMIN,
            );
            let bounds = self.param_bounds.read(fee_type);
            assert(
                new_value >= bounds.min_value && new_value <= bounds.max_value,
                GovernanceErrors::OUT_OF_BOUNDS,
            );

            // Record history
            let old_value = self.system_params.read(fee_type);
            let history_count = self.param_history_count.read(fee_type);
            let history = ParameterHistory {
                old_value, new_value, changed_by: caller, changed_at: get_block_timestamp(),
            };
            self.param_history.write((fee_type, history_count), history);
            self.param_history_count.write(fee_type, history_count + 1);

            self.system_params.write(fee_type, new_value);
            self.emit(FeeUpdated { fee_type, value: new_value });
            true
        }

        /// Get fee
        fn get_fee(self: @ContractState, fee_type: felt252) -> u256 {
            self.system_params.read(fee_type)
        }

        /// Get parameter history count
        fn get_parameter_history_count(self: @ContractState, key: felt252) -> u256 {
            self.param_history_count.read(key).into()
        }

        /// Get parameter history entry
        fn get_parameter_history(
            self: @ContractState, key: felt252, index: u256,
        ) -> ParameterHistory {
            let idx: u32 = index.try_into().unwrap();
            self.param_history.read((key, idx))
        }

        /// Get timelock duration
        fn get_timelock_duration(self: @ContractState) -> u64 {
            self.timelock_duration.read()
        }

        /// Emergency pause the entire contract with metadata
        fn emergency_pause_contract(ref self: ContractState, reason: felt252) {
            // Only pauser can pause
            let caller = get_caller_address();
            assert(self.agent_permissions.read((caller, 'PAUSER')), 'Not authorized pauser');
            
            self.emergency._pause_with_metadata(reason);
            
            self.emit(EmergencyPauseActivated { 
                function_selector: 0, // Global pause, not function-specific
                caller, 
                expires_at: 0 // No expiry for global pause
            });
        }

        /// Emergency unpause the entire contract
        fn emergency_unpause_contract(ref self: ContractState) {
            let caller = get_caller_address();
            assert(self.agent_permissions.read((caller, 'PAUSER')), 'Not authorized pauser');
            
            self.emergency._unpause_with_metadata_clear();
            
            self.emit(EmergencyPauseDeactivated { 
                function_selector: 0, // Global pause, not function-specific
                caller
            });
        }

        /// Emergency pause with metadata
        fn emergency_pause_with_metadata(ref self: ContractState, reason: felt252) {
            let caller = get_caller_address();
            assert(self.agent_permissions.read((caller, 'PAUSER')), 'Not authorized pauser');
            
            self.emergency._pause_with_metadata(reason);
            
            self.emit(EmergencyPauseActivated { 
                function_selector: 0, // Global pause, not function-specific
                caller, 
                expires_at: 0 // No expiry for global pause
            });
        }

        /// Emergency unpause with metadata clear
        fn emergency_unpause_with_metadata_clear(ref self: ContractState) {
            let caller = get_caller_address();
            assert(self.agent_permissions.read((caller, 'PAUSER')), 'Not authorized pauser');
            
            self.emergency._unpause_with_metadata_clear();
            
            self.emit(EmergencyPauseDeactivated { 
                function_selector: 0, // Global pause, not function-specific
                caller
            });
        }

        /// Emergency set pause metadata
        fn emergency_set_pause_meta(ref self: ContractState, reason: felt252) {
            let caller = get_caller_address();
            assert(self.agent_permissions.read((caller, 'PAUSER')), 'Not authorized pauser');
            
            self.emergency._set_pause_meta(reason);
        }

        /// Emergency set ban status
        fn emergency_set_ban(ref self: ContractState, member: ContractAddress, banned: bool) {
            let caller = get_caller_address();
            assert(self.agent_permissions.read((caller, 'PAUSER')), 'Not authorized pauser');
            
            self.emergency._set_ban(member, banned);
            
            if banned {
                self.emit(Event::MemberBanned(MemberBanned {
                    member,
                    reason: 'emergency_ban',
                    strikes: 0,
                    banned_by: caller,
                    timestamp: get_block_timestamp(),
                }));
            } else {
                self.emit(Event::MemberUnbanned(MemberUnbanned {
                    member,
                    unbanned_by: caller,
                    timestamp: get_block_timestamp(),
                }));
            }
        }

        // --- Auto-Schedule Functions ---
        fn setup_auto_schedule(ref self: ContractState, config: AutoScheduleConfig) {
            self.ownable.assert_only_owner();
            self.auto_schedule._setup_auto_schedule(config);
        }

        fn maintain_rolling_schedule(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.auto_schedule._maintain_rolling_schedule();
        }

        fn auto_activate_round(ref self: ContractState, round_id: u256) {
            self.ownable.assert_only_owner();
            self.auto_schedule._auto_activate_round(round_id);
        }

        fn auto_complete_expired_rounds(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.auto_schedule._auto_complete_expired_rounds();
        }

        fn modify_schedule(ref self: ContractState, round_id: u256, new_deadline: u64) {
            self.ownable.assert_only_owner();
            self.auto_schedule._modify_schedule(round_id, new_deadline);
        }

        // --- Payment Flexibility Functions ---
        fn setup_auto_payment(
            ref self: ContractState,
            member: ContractAddress,
            token: ContractAddress,
            amount: u256,
            frequency: PaymentFrequency,
        ) {
            self.ownable.assert_only_owner();
            self.payment_flexibility._setup_auto_payment(member, token, amount, frequency);
        }

        fn process_early_payment(
            ref self: ContractState,
            member: ContractAddress,
            round_id: u256,
            amount: u256,
        ) -> (u256, u256) {
            self.ownable.assert_only_owner();
            self.payment_flexibility._process_early_payment(member, round_id, amount)
        }

        fn extend_grace_period(
            ref self: ContractState,
            member: ContractAddress,
            extension_hours: u64,
        ) {
            self.ownable.assert_only_owner();
            self.payment_flexibility._extend_grace_period(member, extension_hours);
        }

        fn add_supported_token(ref self: ContractState, token: ContractAddress) {
            self.ownable.assert_only_owner();
            self.payment_flexibility._add_supported_token(token);
        }

        fn remove_supported_token(ref self: ContractState, token: ContractAddress) {
            self.ownable.assert_only_owner();
            self.payment_flexibility._remove_supported_token(token);
        }

        fn update_payment_config(ref self: ContractState, config: PaymentConfig) {
            self.ownable.assert_only_owner();
            self.payment_flexibility._update_payment_config(config);
        }

        fn process_auto_payments(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.payment_flexibility._process_auto_payments();
        }
    }



    // --- System Management Functions ---
    #[generate_trait]
    impl SystemManagement of SystemManagementTrait {
        fn authorize_agent(
            ref self: ContractState,
            agent_address: ContractAddress,
            permission: felt252,
            authorized: bool,
        ) {
            // Only ADMIN can authorize
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.agent_permissions.write((agent_address, permission), authorized);
            self
                .emit(
                    AgentPermissionUpdated {
                        agent_address, permission, authorized, caller: get_caller_address(),
                    },
                );
        }

        fn upgrade_contract(ref self: ContractState, new_class_hash: felt252) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
            // Save old class hash (for audit, not actual class hash here)
            let old_class_hash: felt252 = 0; // Placeholder, replace_class does not return old hash
            let class_hash: starknet::class_hash::ClassHash = new_class_hash.try_into().unwrap();
            starknet::syscalls::replace_class_syscall(class_hash).unwrap();
            let version = self.upgrade_count.read() + 1;
            self.upgrade_count.write(version);
            let record = UpgradeRecord {
                version: version.into(),
                class_hash: new_class_hash,
                timestamp: get_block_timestamp(),
                upgraded_by: get_caller_address(),
            };
            self.upgrade_history.write(version, record);
            self
                .emit(
                    ContractUpgradeCompleted {
                        old_class_hash,
                        new_class_hash,
                        version: version.into(),
                        caller: get_caller_address(),
                    },
                );
        }

        fn rollback_contract(ref self: ContractState, target_version: u32) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
            let current_version = self.upgrade_count.read();
            assert(target_version < current_version, 'Cannot roll  current version');
            let record = self.upgrade_history.read(target_version);
            let class_hash: starknet::class_hash::ClassHash = record.class_hash.try_into().unwrap();
            starknet::syscalls::replace_class_syscall(class_hash).unwrap();
            self.upgrade_count.write(target_version);
            self
                .emit(
                    ContractUpgradeRolledBack {
                        old_class_hash: 0, // Placeholder
                        new_class_hash: record.class_hash,
                        target_version: target_version.into(),
                        caller: get_caller_address(),
                    },
                );
        }

        fn emergency_pause_function(
            ref self: ContractState, function_selector: felt252, expires_at: u64,
        ) {
            // Only pauser can pause
            let caller = get_caller_address();
            assert(self.agent_permissions.read((caller, 'PAUSER')), 'Not authorized pauser');
            self.paused_functions.write(function_selector, true);
            self.emergency_pause_expiry.write(function_selector, expires_at);
            self.emit(EmergencyPauseActivated { function_selector, caller, expires_at });
        }

        fn emergency_unpause_function(ref self: ContractState, function_selector: felt252) {
            let caller = get_caller_address();
            assert(self.agent_permissions.read((caller, 'PAUSER')), 'Not authorized pauser');
            self.paused_functions.write(function_selector, false);
            self.emit(EmergencyPauseDeactivated { function_selector, caller });
        }

        fn set_pauser(ref self: ContractState, pauser_address: ContractAddress, is_pauser: bool) {
            self.accesscontrol.assert_only_role(ADMIN_ROLE);
            self.agent_permissions.write((pauser_address, 'PAUSER'), is_pauser);
        }

        fn set_multi_sig_signer(
            ref self: ContractState, signer_address: ContractAddress, is_signer: bool,
        ) {
            self.accesscontrol.assert_only_role(PROTOCOL_OWNER_ROLE);
            self.agent_permissions.write((signer_address, 'MULTISIG'), is_signer);
        }

        fn propose_critical_operation(
            ref self: ContractState,
            op_id: felt252,
            target_contract: ContractAddress,
            selector: felt252,
        ) {
            let caller = get_caller_address();
            assert(self.agent_permissions.read((caller, 'MULTISIG')), 'Not a multisig signer');
            let op = MultiSigOperation {
                target_contract, selector, calldata_len: 0, confirmations_count: 1, executed: false,
            };
            self.multi_sig_operations.write(op_id, op);
            self.multi_sig_approvals.write((op_id, caller), true);
            self.multi_sig_pending.write(op_id, 1);
            self.multi_sig_status.write(op_id, MultiSigStatus::Pending);
            self
                .emit(
                    MultiSigOperationProposed {
                        op_id, target_contract, selector, proposer: caller,
                    },
                );
        }

        fn confirm_critical_operation(ref self: ContractState, op_id: felt252) {
            let caller = get_caller_address();
            assert(self.agent_permissions.read((caller, 'MULTISIG')), 'Not a multisig signer');
            let mut op = self.multi_sig_operations.read(op_id);
            assert(!op.executed, 'Already executed');
            assert(!self.multi_sig_approvals.read((op_id, caller)), 'Already confirmed');
            op.confirmations_count += 1;
            self.multi_sig_operations.write(op_id, op);
            self.multi_sig_approvals.write((op_id, caller), true);
            let pending = self.multi_sig_pending.read(op_id) + 1;
            self.multi_sig_pending.write(op_id, pending);
            self
                .emit(
                    MultiSigOperationApproved {
                        op_id, approver: caller, confirmations_count: op.confirmations_count,
                    },
                );
        }

        fn execute_critical_operation(ref self: ContractState, op_id: felt252) {
            let caller = get_caller_address();
            assert(self.agent_permissions.read((caller, 'MULTISIG')), 'Not a multisig signer');
            let mut op = self.multi_sig_operations.read(op_id);
            assert(!op.executed, 'Already executed');
            let required = self.multi_sig_required.read();
            let pending = self.multi_sig_pending.read(op_id);
            assert(pending >= required, 'Not enough confirmations');
            let updated_op = MultiSigOperation {
                target_contract: op.target_contract,
                selector: op.selector,
                calldata_len: op.calldata_len,
                confirmations_count: op.confirmations_count,
                executed: true,
            };
            self.multi_sig_operations.write(op_id, updated_op);
            self.multi_sig_status.write(op_id, MultiSigStatus::Executed);
            self.emit(MultiSigOperationExecuted { op_id, executor: caller });
        }

        fn get_operation_status(
            self: @ContractState, op_id: felt252,
        ) -> (MultiSigStatus, u32, bool) {
            let status = self.multi_sig_status.read(op_id);
            let op = self.multi_sig_operations.read(op_id);
            (status, op.confirmations_count, op.executed)
        }

        fn is_function_paused(self: @ContractState, function_selector: felt252) -> bool {
            self.paused_functions.read(function_selector)
        }

        fn log_security_action(
            ref self: ContractState, action: felt252, actor: ContractAddress, details: felt252,
        ) {
            let count = self.audit_count.read();
            let entry = AuditEntry { action, actor, timestamp: get_block_timestamp(), details };
            self.audit_trail.write(count, entry);
            self.audit_count.write(count + 1);
            self.emit(AuditTrailEntry { action, actor, timestamp: get_block_timestamp(), details });
        }
    }

    // --- Emergency Functions ---
    #[generate_trait]
    impl Emergency of EmergencyTrait {

        fn emergency_withdraw_all(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.emergency.assert_paused(); // Only callable when paused

            // Business Logic: Calculate proportional withdrawal based on member contributions
            let total_contract_balance = self.get_contract_token_balance();
            assert(total_contract_balance > 0, EmergencyErrors::NO_FUNDS_TO_WITHDRAW);

            // Get all active members and their contribution ratios
            let mut total_contributions = 0;
            let mut member_shares = ArrayTrait::new();

            // Calculate total contributions across all rounds
            let mut round_id = 1;
            while round_id <= self.round_ids.read() {
                let round = self.rounds.read(round_id);
                if round.status == RoundStatus::Active {
                    total_contributions += round.total_contributions;
                }
                round_id += 1;
            }

            // Calculate each member's proportional share
            let mut member_index = 0;
            while member_index < self.member_count.read() {
                let member_address = self.member_by_index.read(member_index);
                if self.members.read(member_address) {
                    let member_total_contribution = self
                        .calculate_member_total_contribution(member_address);
                    if member_total_contribution > 0 {
                        let proportional_share = (member_total_contribution
                            * total_contract_balance)
                            / total_contributions;
                        member_shares.append((member_address, proportional_share));
                    }
                }
                member_index += 1;
            }

            // Execute proportional withdrawals
            let mut shares_index = 0;
            while shares_index < member_shares.len() {
                let (member, share) = member_shares[shares_index];
                if *share > 0 {
                    self.transfer_tokens_to_member(*member, *share);
                }
                shares_index += 1;
            }

            // Emit event for audit trail
            self
                .emit(
                    Event::EmergencyWithdrawalAll(
                        EmergencyWithdrawalAll {
                            total_amount: total_contract_balance,
                            member_count: member_shares.len().try_into().unwrap(),
                            executed_by: get_caller_address(),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn emergency_withdraw_member(ref self: ContractState, member: ContractAddress) {
            self.ownable.assert_only_owner();
            self.emergency.assert_paused();

            // Business Logic: Withdraw member's specific contributions
            assert(self.members.read(member), EmergencyErrors::MEMBER_NOT_EXISTS);

            let member_contribution = self.calculate_member_total_contribution(member);
            assert(member_contribution > 0, EmergencyErrors::MEMBER_NO_CONTRIBUTIONS);

            // Transfer member's contributions back
            self.transfer_tokens_to_member(member, member_contribution);

            // Update member status - remove from active members
            self.members.write(member, false);
            self.member_count.write(self.member_count.read() - 1);

            self
                .emit(
                    Event::EmergencyWithdrawalMember(
                        EmergencyWithdrawalMember {
                            member,
                            amount: member_contribution,
                            executed_by: get_caller_address(),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn emergency_complete_round(ref self: ContractState, round_id: u256) {
            self.ownable.assert_only_owner();
            self.emergency.assert_paused();

            // Business Logic: Force complete a stuck round
            let mut round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, EmergencyErrors::ROUND_NOT_ACTIVE);

            // Check if round has contributions
            if round.total_contributions > 0 {
                // Transfer funds to recipient
                self.transfer_tokens_to_member(round.recipient, round.total_contributions);

                // Update round status
                round.status = RoundStatus::Completed;
                self.rounds.write(round_id, round);

                // Update analytics
                self.update_round_analytics(round_id, RoundStatus::Completed);

                self
                    .emit(
                        Event::RoundEmergencyCompleted(
                            RoundEmergencyCompleted {
                                round_id,
                                recipient: round.recipient,
                                amount: round.total_contributions,
                                completed_by: get_caller_address(),
                                timestamp: get_block_timestamp(),
                            },
                        ),
                    );
            } else {
                // No contributions - just cancel the round
                round.status = RoundStatus::Cancelled;
                self.rounds.write(round_id, round);

                self
                    .emit(
                        Event::RoundEmergencyCancelled(
                            RoundEmergencyCancelled {
                                round_id,
                                cancelled_by: get_caller_address(),
                                reason: 'no_contributions',
                                timestamp: get_block_timestamp(),
                            },
                        ),
                    );
            }
        }

        fn emergency_change_recipient(
            ref self: ContractState, round_id: u256, new_recipient: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            self.emergency.assert_paused();

            // Business Logic: Change recipient due to member issues
            assert(!new_recipient.is_zero(), EmergencyErrors::INVALID_RECIPIENT);
            assert(self.members.read(new_recipient), EmergencyErrors::RECIPIENT_NOT_MEMBER);

            let mut round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, EmergencyErrors::ROUND_NOT_ACTIVE);
            assert(round.recipient != new_recipient, EmergencyErrors::RECIPIENT_ALREADY_SET);

            let old_recipient = round.recipient;
            round.recipient = new_recipient;
            self.rounds.write(round_id, round);

            self
                .emit(
                    Event::RecipientChanged(
                        RecipientChanged {
                            round_id,
                            old_recipient,
                            new_recipient,
                            changed_by: get_caller_address(),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn emergency_cancel_round(ref self: ContractState, round_id: u256) {
            self.ownable.assert_only_owner();
            self.emergency.assert_paused();

            // Business Logic: Cancel round and refund all contributions
            let round = self.rounds.read(round_id);
            assert(round.status == RoundStatus::Active, EmergencyErrors::ROUND_NOT_ACTIVE);

            if round.total_contributions > 0 {
                // Refund contributions proportionally to contributors
                self.refund_round_contributions(round_id);
            }

            // Update round status
            let mut updated_round = round;
            updated_round.status = RoundStatus::Cancelled;
            self.rounds.write(round_id, updated_round);

            self
                .emit(
                    Event::RoundEmergencyCancelled(
                        RoundEmergencyCancelled {
                            round_id,
                            cancelled_by: get_caller_address(),
                            reason: 'emergency_cancellation',
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn emergency_recover_tokens(ref self: ContractState, token: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self.emergency.assert_paused();

            // Business Logic: Recover accidentally sent tokens
            assert(!token.is_zero(), EmergencyErrors::INVALID_TOKEN_ADDRESS);
            assert(amount > 0, EmergencyErrors::INVALID_AMOUNT);

            // Calculate unallocated balance: total_contract_balance - total_allocated_tokens
            let total_contract_balance = self.get_contract_token_balance_specific(token);
            let total_allocated_tokens = self._calculate_total_allocated_tokens(token);
            let unallocated_balance = total_contract_balance - total_allocated_tokens;
            
            // Ensure we only recover unallocated tokens
            assert(unallocated_balance >= amount, EmergencyErrors::INSUFFICIENT_BALANCE);

            // Transfer tokens to owner
            let owner = self.ownable.owner();
            self.transfer_specific_tokens_to_address(token, owner, amount);

            self
                .emit(
                    Event::TokensRecovered(
                        TokensRecovered {
                            token,
                            amount,
                            recovered_by: get_caller_address(),
                            recipient: owner,
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

        fn emergency_migrate_funds(ref self: ContractState, new_contract: ContractAddress) {
            self.ownable.assert_only_owner();
            self.emergency.assert_paused();

            // Business Logic: Migrate all funds to new contract
            assert(!new_contract.is_zero(), EmergencyErrors::INVALID_CONTRACT_ADDRESS);
            assert(new_contract != starknet::get_contract_address(), EmergencyErrors::CANNOT_MIGRATE_TO_SELF);
            
            // Verify the target contract is registered in the contract registry
            // or implements a specific interface
            let registered_migration_target = self.contract_registry.read('migration_target');
            assert(
                new_contract == registered_migration_target || registered_migration_target.is_zero(),
                EmergencyErrors::INVALID_MIGRATION_TARGET
            );

            let total_balance = self.get_contract_token_balance();
            assert(total_balance > 0, EmergencyErrors::NO_FUNDS_TO_MIGRATE);

            // Transfer all funds to new contract
            self.transfer_tokens_to_address(new_contract, total_balance);

            self
                .emit(
                    Event::FundsMigrated(
                        FundsMigrated {
                            new_contract,
                            amount: total_balance,
                            migrated_by: get_caller_address(),
                            timestamp: get_block_timestamp(),
                        },
                    ),
                );
        }

    }

    // Implementation of IMainContractData trait for penalty component
    impl MainContractDataImpl of PenaltyMainContractData<ContractState> {
        fn get_member_contribution_data(self: @ContractState, round_id: u256, member: ContractAddress) -> MemberContribution {
            let contribution = self.member_contributions.read((round_id, member));
            MemberContribution {
                member,
                amount: contribution.amount,
                contributed_at: contribution.contributed_at,
            }
        }
        
        fn get_round_data(self: @ContractState, round_id: u256) -> RoundData {
            let round = self.rounds.read(round_id);
            RoundData {
                deadline: round.deadline,
                status: round.status,
                total_contributions: round.total_contributions,
            }
        }
        
        fn get_member_status(self: @ContractState, member: ContractAddress) -> bool {
            self.members.read(member)
        }
        
        fn get_member_count(self: @ContractState) -> u32 {
            self.member_count.read()
        }
        
        fn get_round_ids(self: @ContractState) -> u256 {
            self.round_ids.read()
        }
        
        fn get_member_by_index(self: @ContractState, index: u32) -> ContractAddress {
            self.member_by_index.read(index)
        }
    }

    // Implementation of IMainContractData trait for auto-schedule component
    impl AutoScheduleMainContractDataImpl of AutoScheduleMainContractData<ContractState> {
        fn get_member_count(self: @ContractState) -> u32 {
            self.member_count.read()
        }
        
        fn get_member_by_index(self: @ContractState, index: u32) -> ContractAddress {
            self.member_by_index.read(index)
        }
        
        fn get_current_round_id(self: @ContractState) -> u256 {
            self.round_ids.read()
        }
        
        fn create_round(ref self: ContractState, recipient: ContractAddress, deadline: u64) -> u256 {
            // Create a new round using existing round creation logic
            let round_id = self.round_ids.read() + 1;
            let round = ContributionRound {
                round_id,
                recipient,
                deadline,
                status: RoundStatus::Scheduled,
                total_contributions: 0,
            };
            self.rounds.write(round_id, round);
            self.round_ids.write(round_id);
            round_id
        }
    }


      // Implementation of Member Profile Component Interface
    // #[abi(embed_v0)]
    // impl MemberProfileImpl of IMemberProfile<ContractState> {
    //     fn create_member_profile(ref self: ContractState, member: ContractAddress) {
    //         self.ownable.assert_only_owner();

    //         let profile = MemberProfile {
    //             join_date: get_block_timestamp(),
    //             total_contributions: 0,
    //             missed_contributions: 0,
    //             credit_score: 100,
    //             last_recipient_round: 0,
    //             reliability_rating: 100,
    //             preferred_payment_method: 'default',
    //             communication_preferences: 'email',
    //         };

    //         self.member_profiles.write(member, profile);
    //         self.member_profile_count.write(self.member_profile_count.read() + 1);
    //     }

    //     fn update_reliability_rating(
    //         ref self: ContractState, member: ContractAddress, new_rating: u8,
    //     ) {
    //         self.ownable.assert_only_owner();

    //         assert(new_rating <= 100, 'Invalid rating: must be 0-100');

    //         let mut profile = self.member_profiles.read(member);
    //         profile.reliability_rating = new_rating;
    //         self.member_profiles.write(member, profile);
    //     }

    //     fn get_member_profile(self: @ContractState, member: ContractAddress) -> MemberProfile {
    //         self.member_profiles.read(member)
    //     }
    // }

    // // Implementation of Payment Flexibility Component Interface
    // #[abi(embed_v0)]
    // impl PaymentFlexibilityImpl of IPaymentFlexibility<ContractState> {
    //     fn setup_auto_payment(
    //         ref self: ContractState,
    //         token: ContractAddress,
    //         amount: u256,
    //         frequency: PaymentFrequency,
    //     ) {
    //         self.ownable.assert_only_owner();

    //         // Business Logic: Setup automatic recurring payments for a member
    //         let caller = get_caller_address();
    //         let payment_config = self.payment_config.read();

    //         // Validate token is supported
    //         assert(self.is_token_supported(token), 'Token not supported');
    //         assert(amount > 0, 'Invalid payment amount');

    //         // Check if member already has auto-payment setup
    //         let existing_setup = self.auto_payment_setups.read(caller);
    //         assert(!existing_setup.is_active, 'Auto-payment already active');

    //         // Calculate next payment date based on frequency
    //         let next_payment_date = self.calculate_next_payment_date(frequency);

    //         // Create auto-payment setup
    //         let auto_payment = AutoPaymentSetup {
    //             member: caller, token, amount, frequency, next_payment_date, is_active: true,
    //         };

    //         self.auto_payment_setups.write(caller, auto_payment);

    //         self
    //             .emit(
    //                 Event::AutoPaymentSetup(
    //                     AutoPaymentSetup {
    //                         member: caller,
    //                         token,
    //                         amount,
    //                         frequency,
    //                         next_payment_date,
    //                         timestamp: get_block_timestamp(),
    //                     },
    //                 ),
    //             );
    //     }

    //     fn process_early_payment(ref self: ContractState, round_id: u256, amount: u256) {
    //         self.ownable.assert_only_owner();

    //         // Business Logic: Process early payment with discount
    //         let caller = get_caller_address();
    //         let payment_config = self.payment_config.read();
    //         let round = self.rounds.read(round_id);

    //         // Validate round is active
    //         assert(round.status == RoundStatus::Active, 'Round not active');
    //         assert(get_block_timestamp() < round.deadline, 'Round deadline passed');

    //         // Calculate early payment discount
    //         let discount_amount = (amount * payment_config.early_payment_discount_basis_points)
    //             / 10000;
    //         let final_amount = amount - discount_amount;

    //         // Process the early payment
    //         self.process_contribution(round_id, caller, final_amount);

    //         // Update member profile for early payment bonus
    //         let mut profile = self.member_profiles.read(caller);
    //         profile
    //             .reliability_rating = self
    //             .calculate_reliability_bonus(profile.reliability_rating, true);
    //         self.member_profiles.write(caller, profile);

    //         self
    //             .emit(
    //                 Event::EarlyPaymentProcessed(
    //                     EarlyPaymentProcessed {
    //                         member: caller,
    //                         round_id,
    //                         original_amount: amount,
    //                         discount_amount,
    //                         final_amount,
    //                         timestamp: get_block_timestamp(),
    //                     },
    //                 ),
    //             );
    //     }

    //     fn extend_grace_period(
    //         ref self: ContractState, member: ContractAddress, extension_hours: u64,
    //     ) {
    //         self.ownable.assert_only_owner();

    //         // Business Logic: Extend grace period for specific member
    //         assert(self.members.read(member), 'Member does not exist');
    //         assert(extension_hours > 0, 'Invalid extension hours');
    //         assert(extension_hours <= 168, 'Extension cannot exceed 1 week'); // Max 7 days

    //         // Get current grace period extension
    //         let current_extension = self.grace_period_extensions.read(member);
    //         let new_extension = current_extension + extension_hours;

    //         // Update grace period extension
    //         self.grace_period_extensions.write(member, new_extension);

    //         self
    //             .emit(
    //                 Event::GracePeriodExtended(
    //                     GracePeriodExtended {
    //                         member,
    //                         extension_hours,
    //                         total_extension: new_extension,
    //                         extended_by: get_caller_address(),
    //                         timestamp: get_block_timestamp(),
    //                     },
    //                 ),
    //             );
    //     }

    //     fn convert_token_value(
    //         ref self: ContractState,
    //         from_token: ContractAddress,
    //         to_token: ContractAddress,
    //         amount: u256,
    //     ) -> u256 {
    //         // Business Logic: Convert token value using oracle
    //         let payment_config = self.payment_config.read();
    //         let oracle_address = payment_config.usd_oracle_address;

    //         assert(!oracle_address.is_zero(), 'Oracle address not set');
    //         assert(from_token != to_token, 'Same token conversion not allowed');

    //         // Get token prices from oracle (simplified - would integrate with real oracle)
    //         let from_price = self.get_token_price_from_oracle(from_token);
    //         let to_price = self.get_token_price_from_oracle(to_token);

    //         assert(from_price > 0 && to_price > 0, 'Invalid token prices');

    //         // Convert amount: (amount * from_price) / to_price
    //         let converted_amount = (amount * from_price) / to_price;

    //         self
    //             .emit(
    //                 Event::TokenValueConverted(
    //                     TokenValueConverted {
    //                         from_token,
    //                         to_token,
    //                         original_amount: amount,
    //                         converted_amount,
    //                         from_price,
    //                         to_price,
    //                         timestamp: get_block_timestamp(),
    //                     },
    //                 ),
    //             );

    //         converted_amount
    //     }

    //     fn get_payment_status(
    //         ref self: ContractState, member: ContractAddress, round_id: u256,
    //     ) -> PaymentStatus {
    //         // Business Logic: Determine payment status based on contribution timing
    //         let round = self.rounds.read(round_id);
    //         let member_contribution = self.member_contributions.read((round_id, member));
    //         let current_time = get_block_timestamp();
    //         let penalty_config = self.penalty_config.read();

    //         if member_contribution.amount == 0 {
    //             // No payment made
    //             if current_time > round.deadline + (penalty_config.grace_period_hours * 3600) {
    //                 return PaymentStatus::Missed;
    //             } else if current_time > round.deadline {
    //                 return PaymentStatus::Late;
    //             } else {
    //                 return PaymentStatus::Pending;
    //             }
    //         } else {
    //             // Payment made
    //             if current_time <= round.deadline {
    //                 return PaymentStatus::Paid;
    //             } else if current_time <= round.deadline
    //                 + (penalty_config.grace_period_hours * 3600) {
    //                 return PaymentStatus::Late;
    //             } else {
    //                 return PaymentStatus::Overpaid; // Payment made after grace period
    //             }
    //         }
    //     }
    // }

    // Implementation of Analytics Component Interface
    // #[abi(embed_v0)]
    // impl AnalyticsImpl of IAnalytics<ContractState> {
    //     fn generate_contribution_report(self: @ContractState) -> ContributionAnalytics {
    //         let mut analytics = self.contribution_analytics.read(); // Reads from cached analytics

    //         // Calculate real-time statistics from actual data if cache is stale or not used
    //         // For a real-time report, you might recompute everything here, or update the cache
    //         // by calling an internal function. For this example, we assume
    //         // `cached_contribution_analytics`
    //         // is updated by other functions.

    //         // Example of re-calculating if not using a cache:
    //         let mut total_rounds_count = 0;
    //         let mut successful_rounds_count = 0;
    //         let mut failed_rounds_count = 0;

    //         let mut round_id = 1;
    //         let max_round_id = self.round_ids.read(); // Assuming this tracks total rounds created
    //         while round_id <= max_round_id { // Iterates through all scheduled rounds
    //             let round = self.rounds.read(round_id); // Reads round data
    //             total_rounds_count += 1;

    //             match round.status { // Checks the status of the round
    //                 RoundStatus::Completed => successful_rounds_count += 1,
    //                 RoundStatus::Cancelled => failed_rounds_count += 1,
    //                 _ => {} // Ignore Scheduled or Active rounds for "completed" or "failed" counts
    //             }
    //             round_id += 1;
    //         }

    //         // Update analytics with real data
    //         analytics.total_rounds = total_rounds_count;
    //         analytics.successful_rounds = successful_rounds_count;
    //         analytics.failed_rounds = failed_rounds_count;
    //         analytics.total_penalties_collected = self.penalty_pool.read(); // Reads total penalties
    //         // member_reliability_distribution would need more complex aggregation logic

    //         analytics
    //     }

    //     fn get_member_performance(
    //         self: @ContractState, member: ContractAddress,
    //     ) -> MemberAnalytics {
    //         let mut analytics = MemberAnalytics { // Initializes a new MemberAnalytics struct
    //             total_contributions: 0,
    //             on_time_payments: 0,
    //             late_payments: 0,
    //             missed_payments: 0,
    //             reliability_score: 0,
    //             last_updated: 0,
    //         };

    //         // Calculate from actual contribution data
    //         let mut round_id = 1;
    //         let max_round_id = self.round_ids.read(); // Assuming this tracks total rounds created
    //         while round_id <= max_round_id { // Iterates through all scheduled rounds
    //             let round = self.rounds.read(round_id); // Reads round data
    //             // Assuming a mapping for member contributions per round: Map<(u256,
    //             // ContractAddress), ContributionDetail>
    //             let contribution = self.member_contributions.read((round_id, member));

    //             if contribution.amount > 0 {
    //                 analytics.total_contributions += contribution.amount;

    //                 if contribution
    //                     .contributed_at <= round
    //                     .deadline { // Check against round deadline
    //                     analytics.on_time_payments += 1;
    //                 } else {
    //                     analytics.late_payments += 1;
    //                 }
    //             } else if round.status == RoundStatus::Completed
    //                 || round.status == RoundStatus::Cancelled {
    //                 // Only count as missed if the round has concluded and no contribution was made
    //                 analytics.missed_payments += 1;
    //             }

    //             round_id += 1;
    //         }

    //         // Calculate reliability score
    //         let total_evaluated_rounds = analytics.on_time_payments
    //             + analytics.late_payments
    //             + analytics.missed_payments;
    //         if total_evaluated_rounds > 0 {
    //             analytics.reliability_score = (analytics.on_time_payments * 100)
    //                 / total_evaluated_rounds;
    //         }

    //         analytics.last_updated = get_block_timestamp();
    //         analytics
    //     }

    //     fn calculate_system_health(self: @ContractState) -> u8 {
    //         let analytics = self.contribution_analytics.read();

    //         if analytics.total_rounds == 0 {
    //             return 100; // Perfect health if no rounds yet
    //         }

    //         // Calculate health based on success rate
    //         let success_rate = (analytics.successful_rounds * 100) / analytics.total_rounds;
    //         success_rate.try_into().unwrap()
    //     }
    // }

    // Helper functions for enhanced business logic
    // impl HelperFunctions of HelperFunctionsTrait {
    //     fn get_contract_token_balance(self: @ContractState) -> u256 {
    //         // Get contract's balance of the primary token
    //         let token_address = self.token_address.read();
    //         let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    //         erc20_dispatcher.balance_of(starknet::get_contract_address())
    //     }

    //     fn get_contract_token_balance_specific(
    //         self: @ContractState, token: ContractAddress,
    //     ) -> u256 {
    //         // Get contract's balance of a specific token
    //         let erc20_dispatcher = IERC20Dispatcher { contract_address: token };
    //         erc20_dispatcher.balance_of(starknet::get_contract_address())
    //     }

    //     fn transfer_tokens_to_member(
    //         ref self: ContractState, member: ContractAddress, amount: u256,
    //     ) {
    //         // Transfer tokens to a member
    //         let token_address = self.token_address.read();
    //         let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    //         assert(erc20_dispatcher.transfer(member, amount), 'Transfer failed');
    //     }

    //     fn transfer_tokens_to_address(
    //         ref self: ContractState, recipient: ContractAddress, amount: u256,
    //     ) {
    //         // Transfer tokens to any address
    //         let token_address = self.token_address.read();
    //         let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
    //         assert(erc20_dispatcher.transfer(recipient, amount), 'Transfer failed');
    //     }

    //     fn transfer_specific_tokens_to_address(
    //         ref self: ContractState,
    //         token: ContractAddress,
    //         recipient: ContractAddress,
    //         amount: u256,
    //     ) {
    //         // Transfer specific tokens to an address
    //         let erc20_dispatcher = IERC20Dispatcher { contract_address: token };
    //         assert(erc20_dispatcher.transfer(recipient, amount), 'Transfer failed');
    //     }

    //     fn calculate_member_total_contribution(
    //         self: @ContractState, member: ContractAddress,
    //     ) -> u256 {
    //         // Calculate total contributions across all rounds for a member
    //         let mut total = 0;
    //         let mut round_id = 1;
    //         while round_id <= self.round_ids.read() {
    //             let contribution = self.member_contributions.read((round_id, member));
    //             total += contribution.amount;
    //             round_id += 1;
    //         }
    //         total
    //     }

    //     fn refund_round_contributions(ref self: ContractState, round_id: u256) {
    //         // Refund all contributions for a specific round
    //         let mut member_index = 0;
    //         while member_index < self.member_count.read() {
    //             let member = self.member_by_index.read(member_index);
    //             if self.members.read(member) {
    //                 let contribution = self.member_contributions.read((round_id, member));
    //                 if contribution.amount > 0 {
    //                     self.transfer_tokens_to_member(member, contribution.amount);
    //                 }
    //             }
    //             member_index += 1;
    //         }
    //     }

    //     fn update_round_analytics(ref self: ContractState, round_id: u256, status: RoundStatus) {
    //         // Update analytics when round status changes
    //         let mut analytics = self.contribution_analytics.read();

    //         match status {
    //             RoundStatus::Completed => {
    //                 analytics.successful_rounds += 1;
    //                 analytics.total_rounds += 1;
    //             },
    //             RoundStatus::Cancelled => {
    //                 analytics.failed_rounds += 1;
    //                 analytics.total_rounds += 1;
    //             },
    //             _ => {},
    //         }

    //         self.contribution_analytics.write(analytics);
    //     }

    //     fn is_token_supported(self: @ContractState, token: ContractAddress) -> bool {
    //         // Check if token is supported for payments
    //         let payment_config = self.payment_config.read();
    //         let supported_tokens = payment_config.supported_tokens;

    //         let mut i = 0;
    //         while i < supported_tokens.len() {
    //             if supported_tokens[i] == token {
    //                 return true;
    //             }
    //             i += 1;
    //         }
    //         false
    //     }

    //     fn calculate_next_payment_date(self: @ContractState, frequency: PaymentFrequency) -> u64 {
    //         // Calculate next payment date based on frequency
    //         let current_time = get_block_timestamp();

    //         match frequency {
    //             PaymentFrequency::Once => current_time,
    //             PaymentFrequency::Daily => current_time + 86400, // 24 hours
    //             PaymentFrequency::Weekly => current_time + 604800, // 7 days
    //             PaymentFrequency::Monthly => current_time + 2592000 // 30 days
    //         }
    //     }

    //     fn process_contribution(
    //         ref self: ContractState, round_id: u256, member: ContractAddress, amount: u256,
    //     ) {
    //         // Process a contribution for a round
    //         let mut round = self.rounds.read(round_id);
    //         round.total_contributions += amount;
    //         self.rounds.write(round_id, round);

    //         // Update member contribution record
    //         let contribution = MemberContribution {
    //             member, amount, contributed_at: get_block_timestamp(),
    //         };
    //         self.member_contributions.write((round_id, member), contribution);
    //     }

    //     fn calculate_reliability_bonus(
    //         self: @ContractState, current_rating: u8, is_early: bool,
    //     ) -> u8 {
    //         // Calculate reliability rating bonus for early payments
    //         if is_early && current_rating < 100 {
    //             return current_rating + 5; // +5 points for early payment
    //         }
    //         current_rating
    //     }

    //     fn get_token_price_from_oracle(self: @ContractState, token: ContractAddress) -> u256 {
    //         // Get token price from oracle (simplified implementation)
    //         // In real implementation, this would call an oracle contract
    //         // For now, return a default price
    //         1000000000000000000 // 1.0 in wei format
    //     }

    //     fn is_round_scheduled(self: @ContractState, round_id: u256) -> bool {
    //         let scheduled_round = self
    //             .scheduled_rounds
    //             .read(round_id); // Reads the scheduled round data
    //         // Checks if the round_id field of the struct is non-zero, indicating it has been set
    //         scheduled_round.round_id > 0
    //     }

    //     // Ensure all components update related state consistently
    //     fn complete_round(ref self: ContractState, round_id: u256) {
    //         self.ownable.assert_only_owner(); // Or triggered by an authorized keeper
    //         self.emergency.assert_not_paused(); // Round completion should happen when not paused

    //         let mut round = self.rounds.read(round_id); // Reads the round data
    //         assert(
    //             round.status == RoundStatus::Active, 'Round not active',
    //         ); // Ensures round is in active state
    //         assert(
    //             get_block_timestamp() >= round.deadline, 'Round not expired',
    //         ); // Ensures deadline has passed

    //         // Update round status to Completed
    //         round.status = RoundStatus::Completed;
    //         self.rounds.write(round_id, round); // Writes the updated round status

    //         // Update scheduled round if it exists
    //         if self.is_round_scheduled(round_id) {
    //             let mut scheduled_round = self.scheduled_rounds.read(round_id);
    //             scheduled_round.status = RoundStatus::Completed;
    //             self.scheduled_rounds.write(round_id, scheduled_round);
    //         }

    //         // Update analytics related to this round
    //         self
    //             .update_round_analytics(
    //                 round_id, RoundStatus::Completed,
    //             ); // Calls internal analytics helper

    //         // Transfer funds to the designated recipient
    //         let total_contributions_for_round = self
    //             .enhanced_contribution_internal
    //             ._get_total_contributions_for_round(round_id); // Get total contributions
    //         self
    //             .transfer_tokens_to_member(
    //                 round.recipient, total_contributions_for_round,
    //             ); // Calls internal token transfer helper

    //         // Apply penalties for missed contributions in this round
    //         self
    //             .penalty_internal
    //             ._apply_missed_contribution_penalties(round_id); // Calls internal penalty helper

    //         self
    //             .emit(
    //                 Event::RoundCompleted(
    //                     RoundCompleted {
    //                         round_id,
    //                         recipient: round.recipient,
    //                         total_amount: total_contributions_for_round,
    //                         member_count: self.member_count.read(),
    //                         completion_time: get_block_timestamp(),
    //                     },
    //                 ),
    //             ); // Emits an event
    //     }

    //     // Add penalty pool distribution logic
    //     fn distribute_penalty_pool(ref self: ContractState) {
    //         self.ownable.assert_only_owner(); // Only owner should trigger distribution
    //         self.emergency.assert_not_paused(); // Distribution should happen when not paused

    //         let penalty_pool_amount = self.penalty_pool.read(); // Reads the total penalty pool
    //         if penalty_pool_amount == 0 {
    //             return;
    //         }

    //         let mut total_compliant_contributions = 0;
    //         let mut compliant_members_list = array![]; // Use Array to collect compliant members

    //         // Calculate total contributions from compliant members and collect their addresses
    //         let mut member_index = 0;
    //         let total_members = self
    //             .member_count
    //             .read(); // Assuming member_count tracks total registered members
    //         while member_index < total_members {
    //             let member_address = self
    //                 .member_by_index
    //                 .read(member_index); // Get member address by index
    //             let member_profile = self
    //                 .member_profiles
    //                 .read(member_address); // Read member profile

    //             // A member is compliant if not banned and has a good credit score (example)
    //             if !member_profile.is_banned
    //                 && member_profile.credit_score >= 80 { // Assuming is_banned in MemberProfile
    //                 let member_contribution = self
    //                     .calculate_member_total_contribution(
    //                         member_address,
    //                     ); // Calls internal helper
    //                 total_compliant_contributions += member_contribution;
    //                 compliant_members_list.append(member_address);
    //             }
    //             member_index += 1;
    //         }

    //         if total_compliant_contributions > 0 {
    //             // Distribute penalty pool proportionally
    //             let mut distributed_count = 0;
    //             let mut i = 0;
    //             while i < compliant_members_list.len() {
    //                 let member_address = *compliant_members_list.at(i);
    //                 let member_contribution = self
    //                     .calculate_member_total_contribution(
    //                         member_address,
    //                     ); // Calls internal helper
    //                 let share = (member_contribution * penalty_pool_amount)
    //                     / total_compliant_contributions;

    //                 if share > 0 {
    //                     self
    //                         .transfer_tokens_to_member(
    //                             member_address, share,
    //                         ); // Calls internal token transfer helper
    //                     distributed_count += 1;
    //                 }
    //                 i += 1;
    //             }

    //             // Reset penalty pool
    //             self.penalty_pool.write(0); // Resets the penalty pool

    //             self
    //                 .emit(
    //                     Event::PenaltyPoolDistributed(
    //                         PenaltyPoolDistributed {
    //                             total_amount: penalty_pool_amount,
    //                             recipient_count: distributed_count,
    //                             distribution_type: 'proportional',
    //                             timestamp: get_block_timestamp(),
    //                         },
    //                     ),
    //                 ); // Emits an event
    //         }
    //     }
    // }

    // // Implementation of Internal Traits for Enhanced Components
    // impl PenaltyInternalImpl of PenaltyInternalTrait<ContractState> {
    //     fn _apply_late_fee(
    //         ref self: ContractState, member: ContractAddress, round_id: u256, amount: u256,
    //     ) {
    //         // Call the existing penalty function
    //         self.penalty.apply_late_fee(member, round_id);
    //     }

    //     fn _add_strike(ref self: ContractState, member: ContractAddress, round_id: u256) {
    //         // Call the existing penalty function
    //         self.penalty.add_strike(member, round_id);
    //     }

    //     fn _remove_strike(ref self: ContractState, member: ContractAddress) {
    //         // Call the existing penalty function
    //         self.penalty.remove_strike(member);
    //     }

    //     fn _ban_member(ref self: ContractState, member: ContractAddress) {
    //         // Call the existing penalty function
    //         self.penalty.ban_member(member);
    //     }

    //     fn _unban_member(ref self: ContractState, member: ContractAddress) {
    //         // Call the existing penalty function
    //         self.penalty.unban_member(member);
    //     }

    //     fn _apply_missed_contribution_penalties(ref self: ContractState, round_id: u256) {
    //         // Apply penalties for missed contributions in a round
    //         let round = self.rounds.read(round_id);
    //         let mut member_index = 0;
    //         let total_members = self.member_count.read();

    //         while member_index < total_members {
    //             let member_address = self.member_by_index.read(member_index);
    //             if self.members.read(member_address) {
    //                 let contribution = self.member_contributions.read((round_id, member_address));
    //                 if contribution.amount == 0 {
    //                     // Member missed contribution - apply penalty
    //                     self.penalty.add_strike(member_address, round_id);
    //                 }
    //             }
    //             member_index += 1;
    //         }
    //     }
    // }

    // impl EnhancedContributionInternalImpl of EnhancedContributionInternalTrait<ContractState> {
    //     fn _process_contribution(
    //         ref self: ContractState, round_id: u256, member: ContractAddress, amount: u256,
    //     ) {
    //         // Process a contribution for a round
    //         let mut round = self.rounds.read(round_id);
    //         round.total_contributions += amount;
    //         self.rounds.write(round_id, round);

    //         // Update member contribution record
    //         let contribution = MemberContribution {
    //             member, amount, contributed_at: get_block_timestamp(),
    //         };
    //         self.member_contributions.write((round_id, member), contribution);
    //     }

    //     fn _get_total_contributions_for_round(self: @ContractState, round_id: u256) -> u256 {
    //         let round = self.rounds.read(round_id);
    //         round.total_contributions
    //     }

    //     fn _is_contribution_late(
    //         self: @ContractState, round_id: u256, member: ContractAddress,
    //     ) -> bool {
    //         let round = self.rounds.read(round_id);
    //         let contribution = self.member_contributions.read((round_id, member));
    //         if contribution.amount == 0 {
    //             return false; // No contribution made
    //         }

    //         let current_time = get_block_timestamp();
    //         current_time > round.deadline
    //     }
    // }

    // impl MemberProfileInternalImpl of MemberProfileInternalTrait<ContractState> {
    //     fn _update_profile_after_contribution(
    //         ref self: ContractState, member: ContractAddress, amount: u256,
    //     ) {
    //         let mut profile = self.member_profiles.read(member);

    //         // Update contribution statistics
    //         profile.total_contributions += amount;

    //         // Update credit score based on payment timing
    //         let current_time = get_block_timestamp();
    //         let round = self.get_current_active_round();
    //         if round > 0 {
    //             let round_data = self.rounds.read(round);
    //             if current_time <= round_data.deadline {
    //                 // On-time payment - boost credit score
    //                 if profile.credit_score < 100 {
    //                     profile.credit_score += 2;
    //                 }
    //             }
    //         }

    //         self.member_profiles.write(member, profile);
    //     }

    //     fn _calculate_member_total_contribution(
    //         self: @ContractState, member: ContractAddress,
    //     ) -> u256 {
    //         self.calculate_member_total_contribution(member)
    //     }

    //     fn _update_reliability_rating(
    //         ref self: ContractState, member: ContractAddress, new_rating: u8,
    //     ) {
    //         let mut profile = self.member_profiles.read(member);
    //         profile.reliability_rating = new_rating;
    //         self.member_profiles.write(member, profile);
    //     }
    // }

    // impl AnalyticsInternalImpl of AnalyticsInternalTrait<ContractState> {
    //     fn _update_round_analytics(ref self: ContractState, round_id: u256, status: RoundStatus) {
    //         self.update_round_analytics(round_id, status);
    //     }

    //     fn _update_member_performance_for_round(ref self: ContractState, round_id: u256) {
    //         // Update member performance analytics for a specific round
    //         let round = self.rounds.read(round_id);
    //         let mut member_index = 0;
    //         let total_members = self.member_count.read();

    //         while member_index < total_members {
    //             let member_address = self.member_by_index.read(member_index);
    //             if self.members.read(member_address) {
    //                 let contribution = self.member_contributions.read((round_id, member_address));
    //                 let mut member_analytics = self.member_analytics.read(member_address);

    //                 if contribution.amount > 0 {
    //                     member_analytics.total_contributions += contribution.amount;
    //                     if contribution.contributed_at <= round.deadline {
    //                         member_analytics.on_time_payments += 1;
    //                     } else {
    //                         member_analytics.late_payments += 1;
    //                     }
    //                 } else if round.status == RoundStatus::Completed
    //                     || round.status == RoundStatus::Cancelled {
    //                     member_analytics.missed_payments += 1;
    //                 }

    //                 member_analytics.last_updated = get_block_timestamp();
    //                 self.member_analytics.write(member_address, member_analytics);
    //             }
    //             member_index += 1;
    //         }
    //     }

    //     fn _calculate_system_health(self: @ContractState) -> u8 {
    //         self.calculate_system_health()
    //     }
    // }

    // impl TokenTransferInternalImpl of TokenTransferInternalTrait<ContractState> {
    //     fn _transfer_tokens_to_member(
    //         ref self: ContractState, member: ContractAddress, amount: u256,
    //     ) {
    //         self.transfer_tokens_to_member(member, amount);
    //     }

    //     fn _transfer_tokens_to_address(
    //         ref self: ContractState, recipient: ContractAddress, amount: u256,
    //     ) {
    //         self.transfer_tokens_to_address(recipient, amount);
    //     }

    //     fn _transfer_specific_tokens_to_address(
    //         ref self: ContractState,
    //         token: ContractAddress,
    //         recipient: ContractAddress,
    //         amount: u256,
    //     ) {
    //         self.transfer_specific_tokens_to_address(token, recipient, amount);
    //     }
    // }

        // Internal helper functions
        #[generate_trait]
        impl InternalFunctions of InternalFunctionsTrait {
            fn _validate_kyc_and_limits(self: @ContractState, user: ContractAddress, amount: u256) {
                // Check KYC validity
                assert(IStarkRemitImpl::is_kyc_valid(self, user), KYCErrors::INVALID_KYC_STATUS);
    
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
    
            fn _calculate_total_allocated_tokens(self: @ContractState, token: ContractAddress) -> u256 {
                // Calculate total allocated tokens = member balances + tokens locked in ongoing rounds
                let mut total_allocated = 0_u256;
                
                // Get the primary token address for comparison
                let primary_token = self.token_address.read();
                assert(token == primary_token, 'Only primary token supported');
                
                // If this is the primary token, calculate allocated tokens
                if token == primary_token {
                    // Add member balances for the primary token
                    let member_count = self.member_count.read();
                    let mut i = 0_u32;
                    while i < member_count {
                        let member = self.member_by_index.read(i);
                        if self.members.read(member) {
                            let member_balance = self.balances.read(member);
                            total_allocated += member_balance;
                        }
                        i += 1;
                    }
                    
                    // Add tokens locked in ongoing rounds (active rounds with contributions)
                    let current_round_id = self.round_ids.read();
                    if current_round_id > 0 {
                        let mut round_id = 1_u256;
                        while round_id <= current_round_id {
                            let round = self.rounds.read(round_id);
                            // Only count active rounds that have contributions
                            if round.status == RoundStatus::Active && round.total_contributions > 0 {
                                total_allocated += round.total_contributions;
                            }
                            round_id += 1;
                        }
                    }
                }
                total_allocated
            }
    
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
    
            // Helper functions for emergency operations
            fn get_contract_token_balance(self: @ContractState) -> u256 {
                // Get contract's balance of the primary token
                let token_address = self.token_address.read();
                let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
                erc20_dispatcher.balance_of(starknet::get_contract_address())
            }
    
            fn get_contract_token_balance_specific(
                self: @ContractState, token: ContractAddress,
            ) -> u256 {
                // Get contract's balance of a specific token
                let erc20_dispatcher = IERC20Dispatcher { contract_address: token };
                erc20_dispatcher.balance_of(starknet::get_contract_address())
            }
    
            fn transfer_tokens_to_member(
                ref self: ContractState, member: ContractAddress, amount: u256,
            ) {
                // Transfer tokens to a member
                let token_address = self.token_address.read();
                let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
                assert(erc20_dispatcher.transfer(member, amount), 'Transfer failed');
            }
    
            fn transfer_tokens_to_address(
                ref self: ContractState, recipient: ContractAddress, amount: u256,
            ) {
                // Transfer tokens to any address
                let token_address = self.token_address.read();
                let erc20_dispatcher = IERC20Dispatcher { contract_address: token_address };
                assert(erc20_dispatcher.transfer(recipient, amount), 'Transfer failed');
            }
    
            fn transfer_specific_tokens_to_address(
                ref self: ContractState,
                token: ContractAddress,
                recipient: ContractAddress,
                amount: u256,
            ) {
                // Transfer specific tokens to an address
                let erc20_dispatcher = IERC20Dispatcher { contract_address: token };
                assert(erc20_dispatcher.transfer(recipient, amount), 'Transfer failed');
            }
    
            fn calculate_member_total_contribution(
                self: @ContractState, member: ContractAddress,
            ) -> u256 {
                // Calculate total contributions across all rounds for a member
                let mut total = 0;
                let mut round_id = 1;
                while round_id <= self.round_ids.read() {
                    let contribution = self.member_contributions.read((round_id, member));
                    total += contribution.amount;
                    round_id += 1;
                }
                total
            }
    
            fn refund_round_contributions(ref self: ContractState, round_id: u256) {
                // Refund all contributions for a specific round
                let mut member_index = 0;
                while member_index < self.member_count.read() {
                    let member = self.member_by_index.read(member_index);
                    if self.members.read(member) {
                        let contribution = self.member_contributions.read((round_id, member));
                        if contribution.amount > 0 {
                            self.transfer_tokens_to_member(member, contribution.amount);
                        }
                    }
                    member_index += 1;
                }
            }
    
            fn update_round_analytics(ref self: ContractState, round_id: u256, status: RoundStatus) {
                // Update analytics when round status changes
                // This is a simplified implementation since analytics component is commented out
                // In a full implementation, this would update the analytics storage
            }

            // Private helper function to remove member from member list
            fn _remove_member_from_list(ref self: ContractState, member: ContractAddress) {
                // Check if member is currently active
                if !self.members.read(member) {
                    return; // Already removed
                }
                
                // Mark member as inactive
                self.members.write(member, false);
                
                // Decrease member count
                let current_count = self.member_count.read();
                self.member_count.write(current_count - 1);
                
                // Find and remove member from member_by_index
                let mut i = 0;
                let total_members = current_count;
                
                while i < total_members {
                    let member_at_index = self.member_by_index.read(i);
                    if member_at_index == member {
                        // Found the member, remove by setting to zero address
                        self.member_by_index.write(i, 0.try_into().unwrap());
                        break;
                    }
                    i += 1;
                }
            }

            // Private helper function to add member back to member list
            fn _add_member_to_list(ref self: ContractState, member: ContractAddress) {
                // Check if member is already active
                if self.members.read(member) {
                    return; // Already active
                }
                
                // Mark member as active
                self.members.write(member, true);
                
                // Increase member count
                let current_count = self.member_count.read();
                self.member_count.write(current_count + 1);
                
                // Add member to member_by_index at the end
                self.member_by_index.write(current_count, member);
            }
        }    
}
