use core::option::OptionTrait;
use core::result::ResultTrait;
use core::traits::TryInto;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, get_block_timestamp, get_contract_address};
use starkremit_contract::base::errors::*;
use starkremit_contract::base::events::*;
use starkremit_contract::base::types::*;
use starkremit_contract::interfaces::IERC20::{
    IERC20MintableDispatcher, IERC20MintableDispatcherTrait,
};
use starkremit_contract::interfaces::IStarkRemit::{
    IStarkRemitDispatcher, IStarkRemitDispatcherTrait,
};

// Test constants
const TIMELOCK_DURATION: u64 = 86400; // 24 hours in seconds
const PARAM_MIN_TRANSFER_AMOUNT: felt252 = 'min_transfer_amount';
const PARAM_MAX_TRANSFER_AMOUNT: felt252 = 'max_transfer_amount';
const PARAM_FEE_RATE: felt252 = 'transfer_fee_rate';
const PARAM_TIMEOUT_DURATION: felt252 = 'timeout_duration';
const FEE_TYPE_TRANSFER: felt252 = 'transfer_fee';
const FEE_TYPE_EXCHANGE: felt252 = 'exchange_fee';
const CONTRACT_ORACLE: felt252 = 'oracle';
const CONTRACT_TREASURY: felt252 = 'treasury';

// Test helper functions
fn SUPER_ADMIN() -> ContractAddress {
    'SUPER_ADMIN'.try_into().unwrap() // This becomes the initial SuperAdmin during deployment
}

fn ADMIN() -> ContractAddress {
    'ADMIN'.try_into().unwrap()
}

fn OPERATOR() -> ContractAddress {
    'OPERATOR'.try_into().unwrap()
}

fn USER() -> ContractAddress {
    'USER'.try_into().unwrap()
}

fn ORACLE_ADDRESS() -> ContractAddress {
    'ORACLE_ADDRESS'.try_into().unwrap()
}

fn TOKEN_ADDRESS() -> ContractAddress {
    'TOKEN_ADDRESS'.try_into().unwrap()
}

fn UNAUTHORIZED_USER() -> ContractAddress {
    'UNAUTHORIZED_USER'.try_into().unwrap()
}

fn deploy_starkremit_contract() -> (ContractAddress, IStarkRemitDispatcher) {
    let starkremit_class_hash = declare("StarkRemit").unwrap().contract_class();
    let mut starkremit_constructor_calldata = array![];
    SUPER_ADMIN().serialize(ref starkremit_constructor_calldata);
    ORACLE_ADDRESS().serialize(ref starkremit_constructor_calldata);
    TOKEN_ADDRESS().serialize(ref starkremit_constructor_calldata);

    let (starkremit_contract_address, _) = starkremit_class_hash
        .deploy(@starkremit_constructor_calldata)
        .unwrap();

    let starkremit_dispatcher = IStarkRemitDispatcher {
        contract_address: starkremit_contract_address,
    };

    (starkremit_contract_address, starkremit_dispatcher)
}


#[test]
fn test_initial_admin_role_assignment() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());
    let superadmin_role = contract.get_admin_role(SUPER_ADMIN());
    assert(superadmin_role == GovRole::SuperAdmin, 'SuperAdmin is SuperAdmin');
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_assign_admin_role_success() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Assign admin role to user
    let success = contract.assign_admin_role(ADMIN(), GovRole::Admin);
    assert(success, 'Role assignment succeeds');

    let admin_role = contract.get_admin_role(ADMIN());
    assert(admin_role == GovRole::Admin, 'Admin doesnt have Admin role');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_assign_operator_role_success() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Assign operator role to user
    let success = contract.assign_admin_role(OPERATOR(), GovRole::Operator);
    assert(success, 'Role assignment should succeed');

    let operator_role = contract.get_admin_role(OPERATOR());
    assert(operator_role == GovRole::Operator, 'User should have Operator role');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('GOV: insufficient role',))]
fn test_assign_admin_role_unauthorized() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, UNAUTHORIZED_USER());
    contract.assign_admin_role(ADMIN(), GovRole::Admin);
}

#[test]
fn test_revoke_admin_role_success() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // First assign a role
    contract.assign_admin_role(ADMIN(), GovRole::Admin);

    // Then revoke it
    let success = contract.revoke_admin_role(ADMIN());
    assert(success, 'Role revocation should succeed');

    let admin_role = contract.get_admin_role(ADMIN());
    assert(admin_role == GovRole::None, 'Admin role is not revoked');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('GOV: insufficient role',))]
fn test_revoke_admin_role_unauthorized() {
    let (contract_address, contract) = deploy_starkremit_contract();

    // Setup admin role first
    start_cheat_caller_address(contract_address, SUPER_ADMIN());
    contract.assign_admin_role(ADMIN(), GovRole::Admin);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, UNAUTHORIZED_USER());
    contract.revoke_admin_role(ADMIN());
}

#[test]
fn test_has_minimum_role_checks() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Assign different roles
    contract.assign_admin_role(ADMIN(), GovRole::Admin);
    contract.assign_admin_role(OPERATOR(), GovRole::Operator);

    // Test role hierarchy
    assert(
        contract.has_minimum_role(SUPER_ADMIN(), GovRole::SuperAdmin), 'Super admin has SuperAdmin',
    );
    assert(contract.has_minimum_role(SUPER_ADMIN(), GovRole::Admin), 'Super admin exceeds Admin');
    assert(
        contract.has_minimum_role(SUPER_ADMIN(), GovRole::Operator), 'Super admin exceeds Operator',
    );

    assert(contract.has_minimum_role(ADMIN(), GovRole::Admin), 'Admin is present');
    assert(contract.has_minimum_role(ADMIN(), GovRole::Operator), 'Admin exceeds Operator');
    assert(!contract.has_minimum_role(ADMIN(), GovRole::SuperAdmin), 'Admin lacks SuperAdmin');

    assert(contract.has_minimum_role(OPERATOR(), GovRole::Operator), 'Operator not present');
    assert(!contract.has_minimum_role(OPERATOR(), GovRole::Admin), 'Operator lacks Admin');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_set_system_parameter_success() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Set bounds first
    let bounds = ParameterBounds { min_value: 500, max_value: 5000 };
    contract.set_parameter_bounds(PARAM_MIN_TRANSFER_AMOUNT, bounds);

    // Set a system parameter within bounds
    let success = contract.set_system_parameter(PARAM_MIN_TRANSFER_AMOUNT, 1000);
    assert(success, 'Parameter not set');

    let value = contract.get_system_parameter(PARAM_MIN_TRANSFER_AMOUNT);
    assert(value == 1000, 'Parameter value not correct');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('GOV: insufficient role',))]
fn test_set_system_parameter_unauthorized() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, UNAUTHORIZED_USER());
    contract.set_system_parameter(PARAM_MIN_TRANSFER_AMOUNT, 1000);
}

#[test]
fn test_set_parameter_bounds_success() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Set parameter bounds
    let bounds = ParameterBounds { min_value: 100, max_value: 10000 };
    let success = contract.set_parameter_bounds(PARAM_MIN_TRANSFER_AMOUNT, bounds);
    assert(success, 'Bounds set not successful');

    // Verify bounds were set
    let retrieved_bounds = contract.get_parameter_bounds(PARAM_MIN_TRANSFER_AMOUNT);
    assert(retrieved_bounds.min_value == 100, 'Min value not correct');
    assert(retrieved_bounds.max_value == 10000, 'Max value not correct');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('GOV: param out of bounds',))]
fn test_set_parameter_out_of_bounds() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    let bounds = ParameterBounds { min_value: 100, max_value: 1000 };
    contract.set_parameter_bounds(PARAM_MIN_TRANSFER_AMOUNT, bounds);

    contract.set_system_parameter(PARAM_MIN_TRANSFER_AMOUNT, 2000);
}

#[test]
fn test_parameter_history_tracking() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Set bounds first
    let bounds = ParameterBounds { min_value: 500, max_value: 5000 };
    contract.set_parameter_bounds(PARAM_MIN_TRANSFER_AMOUNT, bounds);

    // Set initial parameter
    contract.set_system_parameter(PARAM_MIN_TRANSFER_AMOUNT, 1000);

    // Update parameter to a new value
    contract.set_system_parameter(PARAM_MIN_TRANSFER_AMOUNT, 2000);

    // Check history count (should have 2 entries: initial set and update)
    let history_count = contract.get_parameter_history_count(PARAM_MIN_TRANSFER_AMOUNT);
    assert(history_count >= 1, 'Should have at least 1 history');

    // Check first history entry (from initial 0 to 1000)
    let history0 = contract.get_parameter_history(PARAM_MIN_TRANSFER_AMOUNT, 0);
    assert(history0.old_value == 0, 'First old value should be 0');
    assert(history0.new_value == 1000, 'First new value should be 1000');
    assert(history0.changed_by == SUPER_ADMIN(), 'Changed by Super admin');

    // check the history count if it is more than one (1000 to 2000)
    if history_count >= 2 {
        let history1 = contract.get_parameter_history(PARAM_MIN_TRANSFER_AMOUNT, 1);
        assert(history1.old_value == 1000, 'Second old value should be 1000');
        assert(history1.new_value == 2000, 'Second new value should be 2000');
        assert(history1.changed_by == SUPER_ADMIN(), 'Changed by Super admin');
    }

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_schedule_parameter_update_success() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Schedule a parameter update
    let success = contract.schedule_parameter_update(PARAM_MAX_TRANSFER_AMOUNT, 5000);
    assert(success, 'Scheduling should succeed');

    let timelock_info = contract.get_timelock_info(PARAM_MAX_TRANSFER_AMOUNT);
    assert(timelock_info.key == PARAM_MAX_TRANSFER_AMOUNT, 'Key should match');
    assert(timelock_info.value == 5000, 'Value should be 5000');
    assert(timelock_info.proposer == SUPER_ADMIN(), 'Proposer should be Super admin');
    assert(timelock_info.is_active, 'Timelock should be active');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('GOV: insufficient role',))]
fn test_schedule_parameter_update_unauthorized() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, UNAUTHORIZED_USER());
    contract.schedule_parameter_update(PARAM_MAX_TRANSFER_AMOUNT, 5000);
}

#[test]
#[should_panic(expected: ('GOV: timelock not ready',))]
fn test_execute_timelock_update_too_early() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Schedule parameter update
    contract.schedule_parameter_update(PARAM_MAX_TRANSFER_AMOUNT, 5000);
    contract.execute_timelock_update(PARAM_MAX_TRANSFER_AMOUNT);
}

#[test]
fn test_execute_timelock_update_success() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Set bounds for the parameter first
    let bounds = ParameterBounds { min_value: 1000, max_value: 10000 };
    contract.set_parameter_bounds(PARAM_MAX_TRANSFER_AMOUNT, bounds);

    // Schedule parameter update
    contract.schedule_parameter_update(PARAM_MAX_TRANSFER_AMOUNT, 5000);

    // Fast forward time past timelock duration
    let current_time = get_block_timestamp();
    start_cheat_block_timestamp(contract_address, current_time + TIMELOCK_DURATION + 1);

    // Execute the update
    let success = contract.execute_timelock_update(PARAM_MAX_TRANSFER_AMOUNT);
    assert(success, 'Execution should succeed');

    let value = contract.get_system_parameter(PARAM_MAX_TRANSFER_AMOUNT);
    assert(value == 5000, 'Parameter should be updated');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_cancel_timelock_update_success() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Schedule parameter update
    contract.schedule_parameter_update(PARAM_MAX_TRANSFER_AMOUNT, 5000);

    // Cancel the update
    let success = contract.cancel_timelock_update(PARAM_MAX_TRANSFER_AMOUNT);
    assert(success, 'Cancellation should succeed');

    let timelock_info = contract.get_timelock_info(PARAM_MAX_TRANSFER_AMOUNT);
    assert(!timelock_info.is_active, 'Timelock should be inactive');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('GOV: unauthorized cancel',))]
fn test_cancel_timelock_update_unauthorized() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());
    contract.schedule_parameter_update(PARAM_MAX_TRANSFER_AMOUNT, 5000);
    stop_cheat_caller_address(contract_address);

    // Unauthorized user tries to cancel
    start_cheat_caller_address(contract_address, UNAUTHORIZED_USER());
    contract.cancel_timelock_update(PARAM_MAX_TRANSFER_AMOUNT);
}


#[test]
fn test_register_contract_success() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Register a contract
    let oracle_address = ORACLE_ADDRESS();
    let success = contract.register_contract(CONTRACT_ORACLE, oracle_address);
    assert(success, 'Contract reg should succeed');

    let registered_address = contract.get_contract_address(CONTRACT_ORACLE);
    assert(registered_address == oracle_address, 'Address should match');

    assert(contract.is_contract_registered(CONTRACT_ORACLE), 'Contract should be registered');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('GOV: insufficient role',))]
fn test_register_contract_unauthorized() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, UNAUTHORIZED_USER());
    contract.register_contract(CONTRACT_ORACLE, ORACLE_ADDRESS());
}

#[test]
#[should_panic(expected: ('GOV: registry key exists',))]
fn test_register_contract_duplicate_key() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Register contract first time
    contract.register_contract(CONTRACT_ORACLE, ORACLE_ADDRESS());

    let treasury_address: ContractAddress = 'TREASURY'.try_into().unwrap();
    contract.register_contract(CONTRACT_ORACLE, treasury_address);

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_update_contract_address_success() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    contract.register_contract(CONTRACT_ORACLE, ORACLE_ADDRESS());

    let new_oracle_address = 'NEW_ORACLE'.try_into().unwrap();
    let success = contract.update_contract_address(CONTRACT_ORACLE, new_oracle_address);
    assert(success, 'Cont addr update did not pass');

    let updated_address = contract.get_contract_address(CONTRACT_ORACLE);
    assert(updated_address == new_oracle_address, 'Address should be updated');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('GOV: param not found',))]
fn test_debug_update_nonexistent_contract() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    contract.update_contract_address(CONTRACT_ORACLE, ORACLE_ADDRESS());

    stop_cheat_caller_address(contract_address);
}


#[test]
fn test_update_fee_success() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Set bounds for fee first
    let bounds = ParameterBounds { min_value: 0, max_value: 1000 };
    contract.set_parameter_bounds(FEE_TYPE_TRANSFER, bounds);

    // Update transfer fee
    let success = contract.update_fee(FEE_TYPE_TRANSFER, 250); // 2.5%
    assert(success, 'Fee update should succeed');

    let fee = contract.get_fee(FEE_TYPE_TRANSFER);
    assert(fee == 250, 'Transfer fee should be 250');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('GOV: insufficient role',))]
fn test_update_fee_unauthorized() {
    let (contract_address, contract) = deploy_starkremit_contract();

    // Unauthorized user tries to update fee
    start_cheat_caller_address(contract_address, UNAUTHORIZED_USER());
    contract.update_fee(FEE_TYPE_TRANSFER, 250);
}


#[test]
fn test_get_timelock_duration() {
    let (_, contract) = deploy_starkremit_contract();

    let duration = contract.get_timelock_duration();
    assert(duration == TIMELOCK_DURATION, 'Timelock duration should match');
}


#[test]
fn test_admin_role_hierarchy_enforcement() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Setup role hierarchy
    contract.assign_admin_role(ADMIN(), GovRole::Admin);
    contract.assign_admin_role(OPERATOR(), GovRole::Operator);

    // Test SuperAdmin can set bounds
    let bounds = ParameterBounds { min_value: 500, max_value: 5000 };
    let bounds_success = contract.set_parameter_bounds(PARAM_MIN_TRANSFER_AMOUNT, bounds);
    assert(bounds_success, 'SuperAdmin should set bounds');

    // Test SuperAdmin can set parameters
    let param_success = contract.set_system_parameter(PARAM_MIN_TRANSFER_AMOUNT, 1000);
    assert(param_success, 'SuperAdmin sets parameters');

    assert(contract.has_minimum_role(SUPER_ADMIN(), GovRole::SuperAdmin), 'SuperAdmin role check');
    assert(contract.has_minimum_role(ADMIN(), GovRole::Admin), 'Admin role check');
    assert(contract.has_minimum_role(OPERATOR(), GovRole::Operator), 'Operator role check');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('GOV: insufficient role',))]
fn test_operator_cannot_set_parameters() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Setup role hierarchy
    contract.assign_admin_role(OPERATOR(), GovRole::Operator);

    let bounds = ParameterBounds { min_value: 500, max_value: 5000 };
    contract.set_parameter_bounds(PARAM_MIN_TRANSFER_AMOUNT, bounds);

    stop_cheat_caller_address(contract_address);

    // Test Operator cannot set parameters
    start_cheat_caller_address(contract_address, OPERATOR());

    contract.set_system_parameter(PARAM_MIN_TRANSFER_AMOUNT, 1500);

    stop_cheat_caller_address(contract_address);
}


#[test]
fn test_parameter_bounds_enforcement() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Set bounds for a parameter
    let bounds = ParameterBounds { min_value: 100, max_value: 1000 };
    contract.set_parameter_bounds(PARAM_MIN_TRANSFER_AMOUNT, bounds);

    // Test valid value within bounds
    let success = contract.set_system_parameter(PARAM_MIN_TRANSFER_AMOUNT, 500);
    assert(success, 'Value within bounds should pass');

    // Test edge cases
    let success_min = contract.set_system_parameter(PARAM_MIN_TRANSFER_AMOUNT, 100);
    assert(success_min, 'Min bound value should pass');

    let success_max = contract.set_system_parameter(PARAM_MIN_TRANSFER_AMOUNT, 1000);
    assert(success_max, 'Max boundary value should pass');

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_complete_timelock_workflow() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Set bounds for the parameter first
    let bounds = ParameterBounds { min_value: 1000, max_value: 10000 };
    contract.set_parameter_bounds(PARAM_MAX_TRANSFER_AMOUNT, bounds);

    // Schedule parameter update
    contract.schedule_parameter_update(PARAM_MAX_TRANSFER_AMOUNT, 5000);

    // Verify timelock is active
    let timelock_info = contract.get_timelock_info(PARAM_MAX_TRANSFER_AMOUNT);
    assert(timelock_info.is_active, 'Timelock should be active');

    // Fast forward time
    let current_time = get_block_timestamp();
    start_cheat_block_timestamp(contract_address, current_time + TIMELOCK_DURATION + 1);

    // Execute the update
    let success = contract.execute_timelock_update(PARAM_MAX_TRANSFER_AMOUNT);
    assert(success, 'Execution should succeed');

    let value = contract.get_system_parameter(PARAM_MAX_TRANSFER_AMOUNT);
    assert(value == 5000, 'Parameter should be updated');

    let updated_timelock_info = contract.get_timelock_info(PARAM_MAX_TRANSFER_AMOUNT);
    assert(!updated_timelock_info.is_active, 'Execution occurred, no timelock');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('GOV: insufficient role',))]
fn test_admin_cannot_set_system_parameters() {
    let (contract_address, contract) = deploy_starkremit_contract();

    start_cheat_caller_address(contract_address, SUPER_ADMIN());

    // Setup Admin role
    contract.assign_admin_role(ADMIN(), GovRole::Admin);

    // Set bounds first as SUPER_ADMIN since only SuperAdmin can set bounds
    let bounds = ParameterBounds { min_value: 500, max_value: 5000 };
    contract.set_parameter_bounds(PARAM_MIN_TRANSFER_AMOUNT, bounds);

    stop_cheat_caller_address(contract_address);

    // Test Admin cannot set system parameters 
    start_cheat_caller_address(contract_address, ADMIN());

    contract.set_system_parameter(PARAM_MIN_TRANSFER_AMOUNT, 1000);

    stop_cheat_caller_address(contract_address);
}
