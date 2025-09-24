use crate::base::types::DepositDetails;
#[starknet::interface]
pub trait ICloakPay<TContractState> {
    /// @notice This function allows users to deposit supported ERC20 tokens into the mixer.
    fn deposit(ref self: TContractState, supported_token: u256, amount: u256, commitment: felt252);
    fn get_deposit_details(ref self: TContractState, deposit_id: u256) -> DepositDetails;
    fn get_total_deposits(ref self: TContractState) -> u256;
    fn get_commitment_used_status(ref self: TContractState, commitment: felt252) -> bool;
    fn get_deposit_id_from_commitment(ref self: TContractState, commitment: felt252) -> u256;
}
