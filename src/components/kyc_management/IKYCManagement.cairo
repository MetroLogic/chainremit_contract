use starknet::ContractAddress;
use super::KYCManagementTypes::{KYCLevel, KycLevel, KycStatus};

#[starknet::interface]
pub trait IKYCMnagement<TContractState> {
    /// @notice Updates the KYC level for a specific user.
    /// @param user_address The address of the user whose KYC level is to be updated.
    /// @param kyc_level The new KYC level to assign to the user.
    /// @return success True if the operation was successful.
    fn update_kyc_level(
        ref self: TContractState, user_address: ContractAddress, kyc_level: KYCLevel,
    ) -> bool;

    /// @notice Updates the KYC status for a specific user.
    /// @param user The address of the user whose KYC status is to be updated.
    /// @param status The new KYC status to assign to the user.
    /// @param level The KYC level associated with the status update.
    /// @param verification_hash The hash of the verification data.
    /// @param expires_at The timestamp when the KYC status expires.
    /// @return success True if the operation was successful.
    fn update_kyc_status(
        ref self: TContractState,
        user: ContractAddress,
        status: KycStatus,
        level: KycLevel,
        verification_hash: felt252,
        expires_at: u64,
    ) -> bool;

    /// @notice Retrieves the KYC status and level for a specific user.
    /// @param user The address of the user to query.
    /// @return status The current KYC status of the user.
    /// @return level The current KYC level of the user.
    fn get_kyc_status(self: @TContractState, user: ContractAddress) -> (KycStatus, KycLevel);

    /// @notice Checks if a user's KYC is currently valid.
    /// @param user The address of the user to check.
    /// @return is_valid True if the user's KYC is valid.
    fn is_kyc_valid(self: @TContractState, user: ContractAddress) -> bool;

    /// @notice Enables or disables KYC enforcement.
    /// @param enabled Boolean indicating whether KYC enforcement should be enabled.
    /// @return success True if the operation was successful.
    fn set_kyc_enforcement(ref self: TContractState, enabled: bool) -> bool;

    /// @notice Checks if KYC enforcement is currently enabled.
    /// @return enabled True if KYC enforcement is enabled.
    fn is_kyc_enforcement_enabled(self: @TContractState) -> bool;

    /// @notice Suspends the KYC status of a specific user.
    /// @param user The address of the user whose KYC is to be suspended.
    /// @return success True if the operation was successful.
    fn suspend_user_kyc(ref self: TContractState, user: ContractAddress) -> bool;

    /// @notice Reinstates the KYC status of a previously suspended user.
    /// @param user The address of the user whose KYC is to be reinstated.
    /// @return success True if the operation was successful.
    fn reinstate_user_kyc(ref self: TContractState, user: ContractAddress) -> bool;
}
