use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20<TContractState> {
    /// Returns the name of the token
    fn name(self: @TContractState) -> felt252;

    /// Returns the symbol of the token
    fn symbol(self: @TContractState) -> felt252;

    /// Returns the number of decimals used for display purposes
    fn decimals(self: @TContractState) -> u8;

    /// Returns the total token supply
    fn total_supply(self: @TContractState) -> u256;

    /// Returns the account balance of an account with address `account`
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;

    /// Returns the amount which `spender` is allowed to withdraw from `owner`
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;

    /// Transfers `amount` from the caller's account to `recipient`
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;

    /// Approves `spender` to withdraw from the caller's account up to `amount`
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;

    /// Transfers `amount` from `sender` to `recipient` if the caller has been approved
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256,
    ) -> bool;
}
