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
#[allow(starknet::store_no_default_variant)]
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
#[allow(starknet::store_no_default_variant)]
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
