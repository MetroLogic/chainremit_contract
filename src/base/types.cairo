use starknet::ContractAddress;
use core::serde::Serde;
use core::array::{ArrayTrait, Array};


/// User profile structure containing user information
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct UserProfile {
    /// User's contract address
    pub address: ContractAddress,
    /// User's contract address (alias for compatibility)
    pub user_address: ContractAddress,
    /// User's email hash for uniqueness verification
    pub email_hash: felt252,
    /// User's phone number hash for uniqueness verification
    pub phone_hash: felt252,
    /// User's full name
    pub full_name: felt252,
    /// User's preferred currency
    // pub preferred_currency: felt252,
    /// KYC verification level
    pub kyc_level: KYCLevel,
    /// Registration timestamp
    pub registration_timestamp: u64,
    /// Whether the user is active
    pub is_active: bool,
    /// User's country code
    pub country_code: felt252,
}

/// KYC verification levels
#[derive(Copy, Drop, Serde, starknet::Store, Debug, PartialEq)]
pub enum KYCLevel {
    /// No verification
    #[default]
    None,
    /// Basic verification (email/phone)
    Basic,
    /// Advanced verification (ID documents)
    Advanced,
    /// Full verification (all requirements met)
    Full,
}

/// Registration status for tracking user onboarding progress
#[derive(Copy, Drop, Serde, starknet::Store, Debug, PartialEq)]
pub enum RegistrationStatus {
    /// Registration not started
    #[default]
    NotStarted,
    /// Registration in progress
    InProgress,
    /// Registration completed successfully
    Completed,
    /// Registration failed validation
    Failed,
    /// Registration suspended due to issues
    Suspended,
}

/// User registration request structure
#[derive(Copy, Drop, Serde)]
pub struct RegistrationRequest {
    /// User's email hash
    pub email_hash: felt252,
    /// User's phone number hash
    pub phone_hash: felt252,
    /// User's full name
    pub full_name: felt252,
    /// User's preferred currency
    // pub preferred_currency: felt252,
    /// User's country code
    pub country_code: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Debug)]
pub enum KycLevel {
    #[default]
    None,
    Basic,
    Enhanced,
    Premium,
}

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Debug)]
pub enum KycStatus {
    #[default]
    Pending,
    Approved,
    Rejected,
    Expired,
    Suspended,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct UserKycData {
    pub user: ContractAddress,
    pub level: KycLevel,
    pub status: KycStatus,
    pub verification_hash: felt252,
    pub verified_at: u64,
    pub expires_at: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TransactionLimits {
    pub daily_limit: u256,
    pub single_tx_limit: u256,
}

/// Transfer status for tracking transfer lifecycle
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Debug)]
pub enum TransferStatus {
    #[default]
    None,
    Pending,
    Completed,
    Cancelled,
    Expired,
    PartialComplete,
    CashOutRequested,
    CashOutCompleted,
}

/// Transfer data structure for managing transfers
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TransferData {
    /// Unique transfer ID
    pub transfer_id: u256,
    /// Sender address
    pub sender: ContractAddress,
    /// Recipient address
    pub recipient: ContractAddress,
    /// Transfer amount
    pub amount: u256,
    /// Current status of the transfer
    pub status: TransferStatus,
    /// Timestamp when transfer was created
    pub created_at: u64,
    /// Timestamp when transfer was last updated
    pub updated_at: u64,
    /// Expiry timestamp for the transfer
    pub expires_at: u64,
    /// Agent assigned for cash-out (if applicable)
    pub assigned_agent: ContractAddress,
    /// Amount that has been partially completed
    pub partial_amount: u256,
    /// Additional metadata/notes
    pub metadata: felt252,
}

/// Transfer history entry for comprehensive tracking
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TransferHistory {
    /// Transfer ID this history entry belongs to
    pub transfer_id: u256,
    /// Action performed (created, completed, cancelled, etc.)
    pub action: felt252,
    /// Address that performed the action
    pub actor: ContractAddress,
    /// Timestamp when action was performed
    pub timestamp: u64,
    /// Previous status before this action
    pub previous_status: TransferStatus,
    /// New status after this action
    pub new_status: TransferStatus,
    /// Additional details about the action
    pub details: felt252,
}

/// Agent status for tracking agent availability
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Debug)]
pub enum AgentStatus {
    #[default]
    Active,
    Inactive,
    Suspended,
}

/// Agent data structure for managing cash-out agents
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Agent {
    /// Agent's address
    pub agent_address: ContractAddress,
    /// Agent's name/identifier
    pub name: felt252,
    /// Current status of the agent
    pub status: AgentStatus,
    /// Primary currency the agent handles
    // pub primary_currency: felt252,
    // /// Secondary currency the agent handles (optional)
    // pub secondary_currency: felt252,
    /// Primary region the agent operates in
    pub primary_region: felt252,
    /// Secondary region the agent operates in (optional)
    pub secondary_region: felt252,
    /// Commission rate (in basis points, e.g., 100 = 1%)
    pub commission_rate: u256,
    /// Number of completed transactions
    pub completed_transactions: u256,
    /// Total volume handled by the agent
    pub total_volume: u256,
    /// Timestamp when agent was registered
    pub registered_at: u64,
    /// Timestamp of last activity
    pub last_active: u64,
    /// Agent rating (0-1000, where 1000 is perfect)
    pub rating: u256,
}

/// Contribution round data structure
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ContributionRound {
    /// Unique round ID
    pub round_id: u256,
    /// Recipient for this round
    pub recipient: ContractAddress,
    /// Deadline for contributions
    pub deadline: u64,
    /// Total contributions collected
    pub total_contributions: u256,
    /// Current status of the round
    pub status: RoundStatus,
}

/// Member contribution data
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct MemberContribution {
    /// Member who made the contribution
    pub member: ContractAddress,
    /// Amount contributed
    pub amount: u256,
    /// Timestamp when contribution was made
    pub contributed_at: u64,
}

/// Savings group data structure
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct SavingsGroup {
    /// Unique group ID
    pub id: u64,
    /// Address that created the group
    pub creator: ContractAddress,
    /// Maximum number of members allowed
    pub max_members: u8,
    /// Current member count
    pub member_count: u32,
    /// Total savings in the group
    pub total_savings: u256,
    /// Timestamp when group was created
    pub created_at: u64,
    /// Whether the group is active
    pub is_active: bool,
}


// Enum for the status of a contribution round
#[derive(Copy, Drop, Serde, PartialEq, starknet::Store, Debug)]
pub enum RoundStatus {
    Scheduled,
    #[default]
    Active,
    Completed,
    Cancelled,
}
// Struct for a contribution round

// Struct for a member's contribution

#[derive(PartialEq, Copy, Drop, Serde, starknet::Store, Debug)]
pub enum LoanStatus {
    #[default]
    Pending,
    Approved,
    Reject,
    Completed,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct LoanRequest {
    pub id: u256,
    pub requester: ContractAddress,
    pub amount: u256,
    pub status: LoanStatus,
    pub created_at: u64,
}

/// Governance role hierarchy for admin system
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Debug)]
pub enum GovRole {
    #[default]
    /// No special permissions
    None,
    /// Operator: limited permissions
    Operator,
    /// Admin: can register contracts, manage some params
    Admin,
    /// SuperAdmin: full control, can assign/revoke roles, update all params
    SuperAdmin,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ParameterBounds {
    pub min_value: u256,
    pub max_value: u256,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TimelockChange {
    pub key: felt252,
    pub value: u256,
    pub proposer: ContractAddress,
    pub proposed_at: u64,
    pub executable_at: u64,
    pub is_active: bool,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ParameterHistory {
    pub old_value: u256,
    pub new_value: u256,
    pub changed_by: ContractAddress,
    pub changed_at: u64,
}

// Penalty configuration structure
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PenaltyConfig {
    pub late_fee_percentage: u256,        // Late fee as basis points (e.g., 250 = 2.5%)
    pub grace_period_hours: u64,          // Grace period before late fees apply
    pub max_strikes: u32,                 // Maximum strikes before automatic ban
    pub security_deposit_multiplier: u256, // Security deposit amount in tokens
    pub penalty_pool_enabled: bool,       // Whether penalty pool distribution is enabled
}

// Member penalty record structure
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct MemberPenaltyRecord {
    pub total_penalties_paid: u256,       // Total penalties paid by member
    pub strikes: u32,                     // Current strike count
    pub is_banned: bool,                  // Whether member is currently banned
    pub last_penalty_date: u64,           // Timestamp of last penalty
    pub last_strike_date: u64,            // Timestamp of last strike
    pub total_rounds_missed: u32,         // Total rounds where contribution was missed
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct AutoScheduleConfig {
    pub round_duration_days: u64,
    pub start_date: u64,
    pub auto_activation_enabled: bool,
    pub auto_completion_enabled: bool,
    pub rolling_schedule_count: u8 // Maintain 2-3 future rounds
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct ScheduledRound {
    pub round_id: u256,
    pub recipient: ContractAddress,
    pub scheduled_start: u64,
    pub scheduled_deadline: u64,
    pub status: RoundStatus,
    pub auto_generated: bool,
}

// Penalty event structure for history tracking
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct PenaltyEventRecord {
    pub member: ContractAddress,          // Member who received penalty
    pub round_id: u256,                   // Round where penalty occurred
    pub event_type: PenaltyEventType,     // Type of penalty event
    pub amount: u256,                     // Penalty amount
    pub timestamp: u64,                   // When penalty occurred
    pub admin: ContractAddress,           // Admin who applied penalty
}

// Distribution data structure for penalty pool distribution
// Note: This struct is not stored, only used for calculations
#[derive(Clone, Drop, Serde)]
pub struct DistributionData {
    pub total_amount: u256,               // Total penalty pool amount
    pub member_shares: Array<MemberShare>, // Array of member shares
    pub total_compliant_contributions: u256, // Total contributions from compliant members
}

// Individual member share structure
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct MemberShare {
    pub member: ContractAddress,          // Member address
    pub share: u256,                      // Share amount to receive
    pub contribution: u256,               // Member's total contribution
}

// Penalty event types
#[allow(starknet::store_no_default_variant)]
#[derive(Copy, Drop, Serde, starknet::Store)]
pub enum PenaltyEventType {
    LateFee,
    Strike,
    Ban,
    Unban,
    StrikeRemoved,
}

#[derive(Copy, Drop, starknet::Store)]
pub struct RoundData {
    pub deadline: u64,
    pub status: RoundStatus,
    pub total_contributions: u256,
}