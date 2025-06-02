use starknet::ContractAddress;
use starkremit_contract::base::types::{
    KYCLevel, KycLevel, KycStatus, MemberContribution, RegistrationRequest, RegistrationStatus,
    UserProfile,
};

// Comprehensive StarkRemit interface combining all functionality
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

    // KYC Management Functions
    fn update_kyc_status(
        ref self: TContractState,
        user: ContractAddress,
        status: KycStatus,
        level: KycLevel,
        verification_hash: felt252,
        expires_at: u64,
    ) -> bool;

    fn get_kyc_status(self: @TContractState, user: ContractAddress) -> (KycStatus, KycLevel);
    fn is_kyc_valid(self: @TContractState, user: ContractAddress) -> bool;
    fn set_kyc_enforcement(ref self: TContractState, enabled: bool) -> bool;
    fn is_kyc_enforcement_enabled(self: @TContractState) -> bool;
    fn suspend_user_kyc(ref self: TContractState, user: ContractAddress) -> bool;
    fn reinstate_user_kyc(ref self: TContractState, user: ContractAddress) -> bool;

    // contribution

    fn contribute_round(ref self: TContractState, round_id: u256, amount: u256);
    fn complete_round(ref self: TContractState, round_id: u256);
    fn add_round_to_schedule(ref self: TContractState, recipient: ContractAddress, deadline: u64);
    fn is_member(self: @TContractState, address: ContractAddress) -> bool;
    fn check_missed_contributions(ref self: TContractState, round_id: u256);
    fn get_all_members(self: @TContractState) -> Array<ContractAddress>;
    fn add_member(ref self: TContractState, address: ContractAddress);
    fn disburse_round_contribution(ref self: TContractState, round_id: u256);

    // Savings Group Functions
    fn create_group(ref self: TContractState, max_members: u8) -> u64;
    fn join_group(ref self: TContractState, group_id: u64);
}

// ERC-20 Token interface
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

    // Token Supply Management Functions
    /// Mints new tokens to a specified recipient.
    /// Callable only by authorized minters.
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;

    /// Burns (destroys) a specified amount of tokens from the caller's balance.
    fn burn(ref self: TContractState, amount: u256) -> bool;

    /// Adds a new authorized minter.
    /// Callable only by the contract admin.
    fn add_minter(ref self: TContractState, minter_address: ContractAddress) -> bool;

    /// Removes an authorized minter.
    /// Callable only by the contract admin.
    fn remove_minter(ref self: TContractState, minter_address: ContractAddress) -> bool;

    /// Checks if an account is an authorized minter.
    fn is_minter(self: @TContractState, account: ContractAddress) -> bool;

    /// Sets the maximum total supply of the token.
    /// Callable only by the contract admin.
    fn set_max_supply(ref self: TContractState, new_max_supply: u256) -> bool;

    /// Gets the maximum total supply of the token.
    fn get_max_supply(self: @TContractState) -> u256;
    // // Multi-currency functions
// fn get_supported_currencies(self: @TContractState) -> Array<felt252>;
// fn get_exchange_rate(
//     self: @TContractState, from_currency: felt252, to_currency: felt252,
// ) -> u256;
// fn convert_currency(
//     ref self: TContractState, from_currency: felt252, to_currency: felt252, amount: u256,
// ) -> u256;
// fn register_currency(ref self: TContractState, currency: felt252);
// fn set_oracle(ref self: TContractState, oracle_address: ContractAddress);
// fn get_oracle(self: @TContractState) -> ContractAddress;
}
