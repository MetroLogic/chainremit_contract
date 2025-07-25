use starknet::ContractAddress;
use starknet::storage::{
    Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry, StoragePointerReadAccess,
    StoragePointerWriteAccess,
};
use crate::base::events::admin::*;
use crate::base::types::admin::*;
use crate::base::types::kyc::KycLevel;

#[starknet::interface]
pub trait IAdmin<TContractState> {
    // Admin Role Management
    fn grant_admin_role(ref self: TContractState, admin: ContractAddress);
    fn assign_admin_role(ref self: TContractState, user: ContractAddress, role: GovRole) -> bool;
    fn revoke_admin_role(ref self: TContractState, user: ContractAddress) -> bool;
    fn get_admin_role(self: @TContractState, user: ContractAddress) -> GovRole;
    fn has_minimum_role(
        self: @TContractState, user: ContractAddress, required_role: GovRole,
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
    fn get_timelock_duration(self: @TContractState) -> u64;

    // Fee Management
    fn update_fee(ref self: TContractState, fee_type: felt252, new_value: u256) -> bool;
    fn get_fee(self: @TContractState, fee_type: felt252) -> u256;

    // Parameter History
    fn get_parameter_history_count(self: @TContractState, key: felt252) -> u256;
    fn get_parameter_history(self: @TContractState, key: felt252, index: u256) -> ParameterHistory;

    // Admin-only Transfer Functions
    fn process_expired_transfers(ref self: TContractState, limit: u32) -> u32;
    fn assign_agent_to_transfer(
        ref self: TContractState, transfer_id: u256, agent: ContractAddress,
    ) -> bool;

    // Admin-only User Management
    fn update_kyc_level(
        ref self: TContractState, user_address: ContractAddress, kyc_level: KYCLevel,
    ) -> bool;
    fn deactivate_user(ref self: TContractState, user_address: ContractAddress) -> bool;
    fn reactivate_user(ref self: TContractState, user_address: ContractAddress) -> bool;
    fn set_kyc_enforcement(ref self: TContractState, enabled: bool) -> bool;
    fn suspend_user_kyc(ref self: TContractState, user: ContractAddress) -> bool;
    fn reinstate_user_kyc(ref self: TContractState, user: ContractAddress) -> bool;
}


#[starknet::component]
pub mod admin_component {
    use super::*;

    #[storage]
    struct Storage {
        // Admin Storage Module
        agent_permissions: Map<(ContractAddress, felt252), bool>, // (agent, permission) -> granted
        paused_functions: Map<felt252, bool>, // function selector -> paused
        multi_sig_operations: Map<felt252, MultiSigOperation>, // op_id -> operation data
        multi_sig_approvals: Map<(felt252, ContractAddress), bool>, // (op_id, approver) -> approved
        multi_sig_status: Map<felt252, MultiSigStatus>, // op_id -> status
        multi_sig_required: u32, // Number of required approvals
        multi_sig_pending: Map<felt252, u32>, // op_id -> current approvals
        upgrade_history: Map<u32, UpgradeRecord>, // upgrade index -> record
        upgrade_count: u32, // number of upgrades
        audit_trail: Map<u256, AuditEntry>, // audit log
        audit_count: u256,
        emergency_pause_expiry: Map<felt252, u64>, // function selector -> expiry timestamp
        owner: ContractAddress, // Admin address for contract management
        oracle_address: ContractAddress, // Address of the oracle contract for exchange rates
        token_address: ContractAddress, // Address of the token contract
        admin: ContractAddress, // Admin with special privileges
        // ERC20 standard storage
        name: felt252, // Token name
        symbol: felt252, // Token symbol
        decimals: u8, // Token decimals (precision)
        total_supply: u256, // Total token supply
        balances: Map<ContractAddress, u256>, // User token balances
        allowances: Map<(ContractAddress, ContractAddress), u256>, // Spending allowances
        // Token Supply Management
        max_supply: u256, // Maximum total supply of the token
        minters: Map<ContractAddress, bool>, // Addresses authorized to mint tokens
        // Governance storage
        admin_roles: Map<ContractAddress, GovRole>, // User governance roles
        param_bounds: Map<felt252, ParameterBounds>, // Parameter bounds (min, max)
        system_params: Map<felt252, u256>, // System parameter values
        pending_changes: Map<felt252, TimelockChange>, // Pending parameter changes
        contract_registry: Map<felt252, ContractAddress>, // Contract registry mapping
        param_history: Map<(felt252, u32), ParameterHistory>, // Parameter change history
        param_history_count: Map<felt252, u32>, // Parameter history count per key
        timelock_duration: u64 // Timelock duration for parameter changes
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        ContractUpgradeInitiated: ContractUpgradeInitiated,
        ContractUpgradeCompleted: ContractUpgradeCompleted,
        ContractUpgradeRolledBack: ContractUpgradeRolledBack,
        EmergencyPauseActivated: EmergencyPauseActivated,
        EmergencyPauseDeactivated: EmergencyPauseDeactivated,
        MultiSigOperationProposed: MultiSigOperationProposed,
        MultiSigOperationApproved: MultiSigOperationApproved,
        MultiSigOperationExecuted: MultiSigOperationExecuted,
        MultiSigOperationRejected: MultiSigOperationRejected,
        AdminAssigned: AdminAssigned,
        AdminRevoked: AdminRevoked,
        ContractRegistered: ContractRegistered,
        SystemParamUpdated: SystemParamUpdated,
        FeeUpdated: FeeUpdated,
        UpdateExecuted: UpdateExecuted,
        MinterAdded: MinterAdded,
        MinterRemoved: MinterRemoved,
        MaxSupplyUpdated: MaxSupplyUpdated,
    }

    #[embeddable_as(Admin)]
    impl AdminImpl<
        TContractState, +HasComponent<TContractState>,
    > of IAdmin<ComponentState<TContractState>> {}

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {}
}
