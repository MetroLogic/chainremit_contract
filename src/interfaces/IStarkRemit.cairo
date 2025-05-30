use starknet::ContractAddress;
use starkremit_contract::base::types::{
    KYCLevel, RegistrationRequest, RegistrationStatus, UserProfile,
};

#[starknet::interface]
pub trait IStarkRemit<TContractState> {
    // User Registration Functions
    /// Register a new user with the platform
    fn register_user(ref self: TContractState, registration_data: RegistrationRequest) -> bool;

    /// Get user profile by address
    fn get_user_profile(self: @TContractState, user_address: ContractAddress) -> UserProfile;

    /// Update user profile information
    fn update_user_profile(ref self: TContractState, updated_profile: UserProfile) -> bool;

    /// Check if user is registered
    fn is_user_registered(self: @TContractState, user_address: ContractAddress) -> bool;

    /// Get user registration status
    fn get_registration_status(
        self: @TContractState, user_address: ContractAddress,
    ) -> RegistrationStatus;

    /// Update user KYC level (admin only)
    fn update_kyc_level(
        ref self: TContractState, user_address: ContractAddress, kyc_level: KYCLevel,
    ) -> bool;

    /// Deactivate user account (admin only)
    fn deactivate_user(ref self: TContractState, user_address: ContractAddress) -> bool;

    /// Reactivate user account (admin only)
    fn reactivate_user(ref self: TContractState, user_address: ContractAddress) -> bool;

    /// Get total registered users count
    fn get_total_users(self: @TContractState) -> u256;

    /// Validate registration data
    fn validate_registration_data(
        self: @TContractState, registration_data: RegistrationRequest,
    ) -> bool;
}

// Re-export the ERC-20 interface to ensure StarkRemit implements it
#[starknet::interface]
pub trait IStarkRemitToken<TContractState> {
    // Standard ERC-20 functions
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;

    fn get_supported_currencies(self: @TContractState) -> Array<felt252>;
    fn get_exchange_rate(
        self: @TContractState, from_currency: felt252, to_currency: felt252,
    ) -> u256;
    fn convert_currency(
        ref self: TContractState, from_currency: felt252, to_currency: felt252, amount: u256,
    ) -> u256;
    fn register_currency(ref self: TContractState, currency: felt252);
    fn set_oracle(ref self: TContractState, oracle_address: ContractAddress);
    fn get_oracle(self: @TContractState) -> ContractAddress;
}
