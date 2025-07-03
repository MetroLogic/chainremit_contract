use starknet::ContractAddress;
use super::UserManagementTypes::{RegistrationRequest, RegistrationStatus, UserProfile};

#[starknet::interface]
pub trait IUserManagement<TContractState> {
    /// @notice Grants admin role to a specified address.
    /// @param admin The address to be granted admin role.
    fn grant_admin_role(ref self: TContractState, admin: ContractAddress);

    /// @notice Returns the contract owner address.
    /// @return The address of the contract owner.
    fn get_owner(self: @TContractState) -> ContractAddress;

    /// @notice Registers a new user with the platform.
    /// @param registration_data The registration data for the new user.
    /// @return True if registration is successful.
    fn register_user(ref self: TContractState, registration_data: RegistrationRequest) -> bool;

    /// @notice Retrieves user profile by address.
    /// @param user_address The address of the user.
    /// @return The user profile.
    fn get_user_profile(self: @TContractState, user_address: ContractAddress) -> UserProfile;

    /// @notice Updates user profile information.
    /// @param updated_profile The updated user profile data.
    /// @return True if update is successful.
    fn update_user_profile(ref self: TContractState, updated_profile: UserProfile) -> bool;

    /// @notice Checks if a user is registered.
    /// @param user_address The address of the user.
    /// @return True if the user is registered.
    fn is_user_registered(self: @TContractState, user_address: ContractAddress) -> bool;

    /// @notice Gets the registration status of a user.
    /// @param user_address The address of the user.
    /// @return The registration status.
    fn get_registration_status(
        self: @TContractState, user_address: ContractAddress,
    ) -> RegistrationStatus;

    /// @notice Deactivates a user account (admin only).
    /// @param user_address The address of the user to deactivate.
    /// @return True if deactivation is successful.
    fn deactivate_user(ref self: TContractState, user_address: ContractAddress) -> bool;

    /// @notice Reactivates a user account (admin only).
    /// @param user_address The address of the user to reactivate.
    /// @return True if reactivation is successful.
    fn reactivate_user(ref self: TContractState, user_address: ContractAddress) -> bool;

    /// @notice Returns the total number of registered users.
    /// @return The total user count.
    fn get_total_users(self: @TContractState) -> u256;
}
