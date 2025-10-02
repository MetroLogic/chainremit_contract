use starknet::ContractAddress;
use crate::base::types::DepositDetails;
#[starknet::interface]
pub trait ICloakPay<TContractState> {
    fn deposit(ref self: TContractState, supported_token: u256, amount: u256, commitment: felt252);
    fn get_deposit_details(ref self: TContractState, deposit_id: u256) -> DepositDetails;
    fn get_total_deposits(ref self: TContractState) -> u256;
    fn get_commitment_used_status(ref self: TContractState, commitment: felt252) -> bool;
    fn get_deposit_id_from_commitment(ref self: TContractState, commitment: felt252) -> u256;
    fn pause(ref self: TContractState);
    fn resume(ref self: TContractState);
    fn get_paused_status(ref self: TContractState) -> bool;
    fn add_supported_token(ref self: TContractState, token_address: ContractAddress);
    fn remove_supported_token(ref self: TContractState, token_address: ContractAddress);
    fn is_token_supported(ref self: TContractState, token_address: ContractAddress) -> bool;
    fn get_supported_tokens(ref self: TContractState) -> Array<ContractAddress>;
    fn withdraw(
        ref self: TContractState,
        proof: Array<felt252>,
        root: felt252,
        nullifier_hash: felt252,
        recipient: ContractAddress,
        relayer: ContractAddress,
        fee: u256,
        amount: u256,
        token_id: u256,
    );
    fn add_merkle_root(ref self: TContractState, root: felt252);
    fn is_valid_root(ref self: TContractState, root: felt252) -> bool;
    fn is_nullifier_used(ref self: TContractState, nullifier_hash: felt252) -> bool;
    fn get_total_withdrawals(ref self: TContractState) -> u256;
    fn update_verifier(ref self: TContractState, new_verifier: ContractAddress);
    fn add_denomination(ref self: TContractState, amount: u256);
    fn remove_denomination(ref self: TContractState, amount: u256);
    fn is_denomination_allowed(ref self: TContractState, amount: u256) -> bool;
}
