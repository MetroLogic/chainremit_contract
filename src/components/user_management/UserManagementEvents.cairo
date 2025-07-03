use starknet::ContractAddress;

/// @notice Event emitted when a new user is registered.
/// @param user_address Registered user address.
/// @param email_hash Email hash for privacy.
/// @param registration_timestamp Registration time.
#[derive(Copy, Drop, starknet::Event)]
pub struct UserRegistered {
    #[key]
    pub user_address: ContractAddress,
    pub email_hash: felt252,
    pub registration_timestamp: u64,
}

/// @notice Event emitted when user profile is updated.
/// @param user_address User address.
/// @param updated_fields Indication of what was updated.
#[derive(Copy, Drop, starknet::Event)]
pub struct UserProfileUpdated {
    #[key]
    pub user_address: ContractAddress,
    pub updated_fields: felt252,
}

/// @notice Event emitted when user is deactivated.
/// @param user_address Deactivated user address.
/// @param admin Admin who performed the action.
#[derive(Copy, Drop, starknet::Event)]
pub struct UserDeactivated {
    #[key]
    pub user_address: ContractAddress,
    pub admin: ContractAddress,
}

/// @notice Event emitted when user is reactivated.
/// @param user_address Reactivated user address.
/// @param admin Admin who performed the action.
#[derive(Copy, Drop, starknet::Event)]
pub struct UserReactivated {
    #[key]
    pub user_address: ContractAddress,
    pub admin: ContractAddress,
}
