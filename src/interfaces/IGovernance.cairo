use starknet::ContractAddress;
use starkremit_contract::base::types::{
    AdminRole, ParameterBounds, ParameterHistory, TimelockChange,
};

#[starknet::interface]
pub trait IGovernance<TContractState> {
    // Admin Role Management
    fn assign_admin_role(ref self: TContractState, user: ContractAddress, role: AdminRole) -> bool;
    fn revoke_admin_role(ref self: TContractState, user: ContractAddress) -> bool;
    fn get_admin_role(self: @TContractState, user: ContractAddress) -> AdminRole;
    fn has_minimum_role(
        self: @TContractState, user: ContractAddress, required_role: AdminRole,
    ) -> bool;

    // System Parameter Management
    fn set_system_parameter(ref self: TContractState, key: felt252, value: u256) -> bool;
    fn set_system_parameter_with_timelock(
        ref self: TContractState, key: felt252, value: u256,
    ) -> bool;
    fn get_system_parameter(self: @TContractState, key: felt252) -> u256;
    fn set_parameter_bounds(
        ref self: TContractState, key: felt252, bounds: ParameterBounds,
    ) -> bool;
    fn get_parameter_bounds(self: @TContractState, key: felt252) -> ParameterBounds;

    // Contract Registry
    fn register_contract(
        ref self: TContractState, name: felt252, contract_address: ContractAddress,
    ) -> bool;
    fn update_contract_address(
        ref self: TContractState, name: felt252, new_address: ContractAddress,
    ) -> bool;
    fn get_contract_address(self: @TContractState, name: felt252) -> ContractAddress;
    fn is_contract_registered(self: @TContractState, name: felt252) -> bool;

    // Timelock Management
    fn schedule_parameter_update(ref self: TContractState, key: felt252, value: u256) -> bool;
    fn execute_timelock_update(ref self: TContractState, key: felt252) -> bool;
    fn cancel_timelock_update(ref self: TContractState, key: felt252) -> bool;
    fn get_timelock_info(self: @TContractState, key: felt252) -> TimelockChange;

    // Emergency Controls
    fn pause_system(ref self: TContractState) -> bool;
    fn unpause_system(ref self: TContractState) -> bool;
    fn is_system_paused(self: @TContractState) -> bool;

    // Fee Management
    fn update_fee(ref self: TContractState, fee_type: felt252, new_value: u256) -> bool;
    fn get_fee(self: @TContractState, fee_type: felt252) -> u256;

    // Parameter History
    fn get_parameter_history_count(self: @TContractState, key: felt252) -> u256;
    fn get_parameter_history(self: @TContractState, key: felt252, index: u256) -> ParameterHistory;

    // Utility Functions
    fn get_timelock_duration(self: @TContractState) -> u64;
    fn requires_timelock(self: @TContractState, key: felt252) -> bool;
}
