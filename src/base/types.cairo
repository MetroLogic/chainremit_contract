use starknet::ContractAddress;


/// User profile structure containing user information
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct UserProfile {
    /// User's wallet address
    pub address: ContractAddress,
    /// User's email hash for uniqueness verification
    pub email_hash: felt252,
    /// User's phone number hash for uniqueness verification
    pub phone_hash: felt252,
    /// User's full name
    pub full_name: felt252,
    /// User's preferred currency
    pub preferred_currency: felt252,
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
#[derive(Copy, Drop, Serde, starknet::Store)]
pub enum KYCLevel {
    /// No verification
    None,
    /// Basic verification (email/phone)
    Basic,
    /// Advanced verification (ID documents)
    Advanced,
    /// Full verification (all requirements met)
    Full,
}

/// Registration status for tracking user onboarding progress
#[derive(Copy, Drop, Serde, starknet::Store)]
pub enum RegistrationStatus {
    /// Registration not started
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
    pub preferred_currency: felt252,
    /// User's country code
    pub country_code: felt252,
}

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum KycLevel {
    #[default]
    None,
    Basic,
    Enhanced,
    Premium,
}

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
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
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum TransferStatus {
    #[default]
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
pub struct Transfer {
    /// Unique transfer ID
    pub transfer_id: u256,
    /// Sender address
    pub sender: ContractAddress,
    /// Recipient address
    pub recipient: ContractAddress,
    /// Transfer amount
    pub amount: u256,
    /// Currency of the transfer
    pub currency: felt252,
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
    /// Transfer ID this history belongs to
    pub transfer_id: u256,
    /// Action performed (created, updated, cancelled, etc.)
    pub action: felt252,
    /// Who performed the action
    pub actor: ContractAddress,
    /// Timestamp of the action
    pub timestamp: u64,
    /// Previous status before this action
    pub previous_status: TransferStatus,
    /// New status after this action
    pub new_status: TransferStatus,
    /// Additional details about the action
    pub details: felt252,
}

/// Agent status for managing cash-out agents
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum AgentStatus {
    #[default]
    Active,
    Inactive,
    Suspended,
    Terminated,
}

/// Agent data structure for cash-out operations
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct Agent {
    /// Agent's address
    pub agent_address: ContractAddress,
    /// Agent's name/identifier
    pub name: felt252,
    /// Current status of the agent
    pub status: AgentStatus,
    /// Primary currency this agent handles
    pub primary_currency: felt252,
    /// Secondary currency this agent handles (0 if none)
    pub secondary_currency: felt252,
    /// Primary region this agent covers
    pub primary_region: felt252,
    /// Secondary region this agent covers (0 if none)
    pub secondary_region: felt252,
    /// Commission rate (as percentage in basis points)
    pub commission_rate: u256,
    /// Total completed transactions
    pub completed_transactions: u256,
    /// Total volume handled
    pub total_volume: u256,
    /// Registration timestamp
    pub registered_at: u64,
    /// Last activity timestamp
    pub last_active: u64,
    /// Agent's rating (0-1000)
    pub rating: u256,
}

// Struct for a member's contribution
#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct MemberContribution {
    pub member: ContractAddress,
    pub amount: u256,
    pub contributed_at: u64,
}

// Savings group record
#[derive(Copy, Drop, starknet::Store)]
pub struct SavingsGroup {
    pub id: u64, // Group identifier
    pub creator: ContractAddress, // Group creator
    pub max_members: u8, // Maximum number of members
    pub member_count: u8, // Current number of members
    pub is_active: bool // Group active status
}


// Enum for the status of a contribution round
#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub enum RoundStatus {
    Active,
    Completed,
}

// Struct for a contribution round
#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct ContributionRound {
    pub round_id: u256,
    pub total_contributions: u256,
    pub status: RoundStatus,
    pub deadline: u64,
}
// Struct for a member's contribution


