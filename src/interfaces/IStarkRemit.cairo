use starknet::ContractAddress;

#[starknet::interface]
pub trait IStarkRemit<TContractState> { // StarkRemit specific functions can be added here
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
