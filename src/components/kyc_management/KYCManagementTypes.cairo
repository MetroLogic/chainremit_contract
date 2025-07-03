use starknet::ContractAddress;
/// @title KYCLevel (Legacy)
/// @notice Represents the legacy KYC verification levels for users.
/// @dev This enum is kept for backward compatibility. Prefer using `KycLevel` for new
/// implementations.
#[derive(Copy, Drop, Serde, starknet::Store)]
pub enum KYCLevel {
    #[default]
    None,
    Basic,
    Advanced,
    Full,
}

/// @title KycLevel
/// @notice Represents the new KYC verification levels for users.
/// @dev Use this enum for all new KYC level assignments and checks.
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum KycLevel {
    #[default]
    None,
    Basic,
    Enhanced,
    Premium,
}

/// @title KycStatus
/// @notice Represents the status of a user's KYC verification process.
/// @dev Used to track the current state of KYC for a user.
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum KycStatus {
    #[default]
    Pending,
    Approved,
    Rejected,
    Expired,
    Suspended,
}

/// @title UserKycData
/// @notice Stores KYC data for a user, including level, status, and verification metadata.
/// @dev This struct is used to persist user KYC information in the contract's storage.
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct UserKycData {
    pub user: ContractAddress,
    pub level: KycLevel,
    pub status: KycStatus,
    pub verification_hash: felt252,
    pub verified_at: u64,
    pub expires_at: u64,
}
