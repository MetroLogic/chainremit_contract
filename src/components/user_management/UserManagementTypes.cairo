use crate::components::kyc_management::KYCManagementTypes::KYCLevel;
use starknet::ContractAddress;

/// @title UserProfile
/// @notice User profile structure containing user information
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct UserProfile {
    pub address: ContractAddress,
    pub user_address: ContractAddress,
    pub email_hash: felt252,
    pub phone_hash: felt252,
    pub full_name: felt252,
    pub kyc_level: KYCLevel,
    pub registration_timestamp: u64,
    pub is_active: bool,
    pub country_code: felt252,
}

/// @title RegistrationStatus
/// @notice Registration status for tracking user onboarding progress
#[derive(Copy, Drop, Serde, starknet::Store)]
pub enum RegistrationStatus {
    #[default]
    NotStarted,
    InProgress,
    Completed,
    Failed,
    Suspended,
}

/// @title RegistrationRequest
/// @notice User registration request structure
#[derive(Copy, Drop, Serde)]
pub struct RegistrationRequest {
    pub email_hash: felt252,
    pub phone_hash: felt252,
    pub full_name: felt252,
    pub country_code: felt252,
}