use super::KYCManagementTypes::KycStatus;
use super::KYCManagementTypes::KYCLevel;
use starknet::ContractAddress;

/// @title KYCLevelUpdated
/// @notice Emitted when a user's KYC level is updated.
/// @param user_address The address of the user whose KYC level was updated.
/// @param old_level The previous KYC level.
/// @param new_level The new KYC level.
/// @param admin The admin who performed the update.
#[derive(Copy, Drop, starknet::Event)]
pub struct KYCLevelUpdated {
    #[key]
    pub user_address: ContractAddress,
    pub old_level: KYCLevel,
    pub new_level: KYCLevel,
    pub admin: ContractAddress,
}

/// @title KycStatusUpdated
/// @notice Emitted when a user's KYC status is updated.
/// @param user The address of the user whose KYC status was updated.
/// @param old_status The previous KYC status.
/// @param new_status The new KYC status.
/// @param old_level The previous KYC level.
/// @param new_level The new KYC level.
#[derive(Copy, Drop, starknet::Event)]
pub struct KycStatusUpdated {
    #[key]
    pub user: ContractAddress,
    pub old_status: KycStatus,
    pub new_status: KycStatus,
    pub old_level: KYCLevel,
    pub new_level: KYCLevel,
}

/// @title KycEnforcementEnabled
/// @notice Emitted when KYC enforcement is enabled or disabled.
/// @param enabled Whether KYC enforcement is enabled.
/// @param updated_by The address of the admin who updated the enforcement status.
#[derive(Copy, Drop, starknet::Event)]
pub struct KycEnforcementEnabled {
    pub enabled: bool,
    pub updated_by: ContractAddress,
}
