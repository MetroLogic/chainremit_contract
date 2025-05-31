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

// Struct for a member's contribution
#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct MemberContribution {
    member: ContractAddress,
    amount: u256,
    contributed_at: u64,
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
