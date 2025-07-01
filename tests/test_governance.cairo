use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare,
    start_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, get_block_timestamp};
use starkremit_contract::base::types::{
    AdminRole, KycLevel, KycStatus, ParameterBounds, ParameterHistory, TimelockChange,
};
use starkremit_contract::interfaces::IGovernance::{
    IGovernanceDispatcher, IGovernanceDispatcherTrait,
};
use starkremit_contract::interfaces::IStarkRemit::{
    IStarkRemitDispatcher, IStarkRemitDispatcherTrait,
};


// Test constants
const FEE_TYPE: felt252 = 'GAS_FEE';
const SYSTEM_PARAMETER_KEY: felt252 = 'SERVICE_FEE';
const CONTRACT_NAME: felt252 = 'TEST_CONTRACT';
const TIMELOCK_PARAM_KEY: felt252 = 'MAX_TX_AMOUNT';

// TEST ADDRESS

fn ADMIN() -> ContractAddress {
    'ADMIN'.try_into().unwrap() // This becomes the initial SuperAdmin during deployment
}

fn ADMIN_USER() -> ContractAddress {
    'ADMIN_USER'.try_into().unwrap()
}

fn KYC_MANAGER() -> ContractAddress {
    'KYC_MANAGER'.try_into().unwrap()
}

fn ORACLE() -> ContractAddress {
    'ORACLE'.try_into().unwrap()
}

fn USER() -> ContractAddress {
    'USER'.try_into().unwrap()
}

fn UNAUTHORIZED() -> ContractAddress {
    'UNAUTHORIZED'.try_into().unwrap()
}

fn TARGET_USER() -> ContractAddress {
    'TARGET_USER'.try_into().unwrap()
}

fn TEST_CONTRACT() -> ContractAddress {
    'TEST_CONTRACT'.try_into().unwrap()
}

fn OLD_CONTRACT() -> ContractAddress {
    'OLD_CONTRACT'.try_into().unwrap()
}

fn NEW_CONTRACT() -> ContractAddress {
    'NEW_CONTRACT'.try_into().unwrap()
}

fn CONTRACT1() -> ContractAddress {
    'CONTRACT1'.try_into().unwrap()
}

fn CONTRACT2() -> ContractAddress {
    'CONTRACT2'.try_into().unwrap()
}

fn deploy_starkremit_contract() -> (IStarkRemitDispatcher, IGovernanceDispatcher) {
    let contract = declare("StarkRemit").unwrap().contract_class();

    let admin: ContractAddress = ADMIN();
    let oracle: ContractAddress = ORACLE();

    let mut calldata: Array<felt252> = array![];
    admin.serialize(ref calldata);
    'StarkRemit'.serialize(ref calldata);
    'SRM'.serialize(ref calldata);
    1000000_u256.serialize(ref calldata);
    'USD'.serialize(ref calldata);
    oracle.serialize(ref calldata);

    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    let starkremit_dispatcher = IStarkRemitDispatcher { contract_address };
    let governance_dispatcher = IGovernanceDispatcher { contract_address };

    (starkremit_dispatcher, governance_dispatcher)
}

#[test]
fn test_assign_admin_role() {
    let (_, governance) = deploy_starkremit_contract();

    let admin: ContractAddress = ADMIN();
    let user: ContractAddress = USER();

    start_cheat_caller_address(governance.contract_address, admin);

    // Test assigning Admin role
    let success = governance.assign_admin_role(user, AdminRole::Admin);
    assert(success, 'Failed to assign admin role');

    let assigned_role = governance.get_admin_role(user);
    assert(assigned_role == AdminRole::Admin, 'Role not assigned correctly');

    assert(governance.has_minimum_role(user, AdminRole::Operator), 'Should have operator access');
    assert(governance.has_minimum_role(user, AdminRole::Admin), 'Should have admin access');
    assert(
        !governance.has_minimum_role(user, AdminRole::SuperAdmin), 'Should not have super admin',
    );
}

#[test]
fn test_revoke_admin_role() {
    let (_, governance) = deploy_starkremit_contract();

    let admin: ContractAddress = ADMIN();
    let user: ContractAddress = USER();

    start_cheat_caller_address(governance.contract_address, admin);
    // First assign a role
    governance.assign_admin_role(user, AdminRole::KYCManager);
    assert(governance.get_admin_role(user) == AdminRole::KYCManager, 'Role not assigned');
    //  revoke it
    let success = governance.revoke_admin_role(user);
    assert(success, 'Failed to revoke admin role');
    let revoked_role = governance.get_admin_role(user);
    assert(revoked_role == AdminRole::None, 'Role not revoked correctly');
}

#[test]
#[should_panic(expected: ('GOV: insufficient role',))]
fn test_unauthorized_role_assignment() {
    let (_, governance) = deploy_starkremit_contract();

    let unauthorized_user: ContractAddress = UNAUTHORIZED();
    let target_user: ContractAddress = TARGET_USER();

    start_cheat_caller_address(governance.contract_address, unauthorized_user);
    governance.assign_admin_role(target_user, AdminRole::Admin);
}

#[test]
fn test_set_system_parameter() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();
    start_cheat_caller_address(governance.contract_address, admin);
    let new_value: u256 = 2000000000000000; // 0.002 tokens
    let success = governance.set_system_parameter(SYSTEM_PARAMETER_KEY, new_value);
    assert(success, 'Failed to set system parameter');
    let retrieved_value = governance.get_system_parameter(SYSTEM_PARAMETER_KEY);
    assert(retrieved_value == new_value, 'Parameter not set correctly');
}

#[test]
fn test_set_parameter_bounds() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();
    start_cheat_caller_address(governance.contract_address, admin);
    let bounds = ParameterBounds { min_value: 100, max_value: 1000 };
    let success = governance.set_parameter_bounds('TEST_PARAM', bounds);
    assert(success, 'Failed to set parameter bounds');
    let retrieved_bounds = governance.get_parameter_bounds('TEST_PARAM');
    assert(retrieved_bounds.min_value == 100, 'Min bound not set correctly');
    assert(retrieved_bounds.max_value == 1000, 'Max bound not set correctly');
}

#[test]
#[should_panic(expected: ('GOV: param out of bounds',))]
fn test_parameter_bounds_validation() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();
    start_cheat_caller_address(governance.contract_address, admin);
    let bounds = ParameterBounds { min_value: 100, max_value: 1000 };
    governance.set_parameter_bounds('BOUNDED_PARAM', bounds);
    governance.set_system_parameter('BOUNDED_PARAM', 50); // Below the min_value
}

#[test]
#[should_panic(expected: ('GOV: requires timelock',))]
fn test_timelock_required_parameter() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();
    start_cheat_caller_address(governance.contract_address, admin);
    governance.set_system_parameter(TIMELOCK_PARAM_KEY, 5000000000000000000000000);
}

#[test]
fn test_register_contract() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();
    let test_contract: ContractAddress = TEST_CONTRACT();

    start_cheat_caller_address(governance.contract_address, admin);

    let success = governance.register_contract(CONTRACT_NAME, test_contract);
    assert(success, 'Failed to register contract');

    // Verify contract was registered
    let registered_address = governance.get_contract_address(CONTRACT_NAME);
    assert(registered_address == test_contract, 'Contract not registered well');
    assert(governance.is_contract_registered(CONTRACT_NAME), 'Contract should be registered');
}

#[test]
fn test_update_contract_address() {
    let (_, governance) = deploy_starkremit_contract();

    let admin: ContractAddress = ADMIN();
    let old_contract: ContractAddress = OLD_CONTRACT();
    let new_contract: ContractAddress = NEW_CONTRACT();

    start_cheat_caller_address(governance.contract_address, admin);

    // Register contract first
    governance.register_contract(CONTRACT_NAME, old_contract);

    // Update contract address
    let success = governance.update_contract_address(CONTRACT_NAME, new_contract);
    assert(success, 'Failed to update address');

    // Verify update
    let updated_address = governance.get_contract_address(CONTRACT_NAME);
    assert(updated_address == new_contract, 'Address not updated');
}

#[test]
#[should_panic(expected: ('GOV: registry key exists',))]
fn test_prevent_duplicate_registration() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();
    let contract1: ContractAddress = CONTRACT1();
    let contract2: ContractAddress = CONTRACT2();

    start_cheat_caller_address(governance.contract_address, admin);

    // Register contract first time
    governance.register_contract(CONTRACT_NAME, contract1);

    // Try to register again - should fail
    governance.register_contract(CONTRACT_NAME, contract2);
}

#[test]
fn test_schedule_timelock_update() {
    let (_, governance) = deploy_starkremit_contract();

    let admin: ContractAddress = ADMIN();

    start_cheat_caller_address(governance.contract_address, admin);

    let new_value: u256 = 5000000000000000000000000; // 5M tokens
    let success = governance.schedule_parameter_update(TIMELOCK_PARAM_KEY, new_value);
    assert(success, 'Failed to do timelock update');

    // Verify timelock was scheduled
    let timelock_info = governance.get_timelock_info(TIMELOCK_PARAM_KEY);
    assert(timelock_info.is_active, 'Timelock should be active');
    assert(timelock_info.value == new_value, 'Timelock value incorrect');
    assert(timelock_info.proposer == admin, 'Proposer should be admin');
}

#[test]
fn test_execute_timelock_update() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();

    start_cheat_caller_address(governance.contract_address, admin);

    let new_value: u256 = 5000000000000000000000000;
    governance.schedule_parameter_update(TIMELOCK_PARAM_KEY, new_value);

    // Fast forward time past timelock duration (48 hours = 172800 seconds)
    let current_time = get_block_timestamp();
    start_cheat_block_timestamp(governance.contract_address, current_time + 172801);

    // Execute the timelock
    let success = governance.execute_timelock_update(TIMELOCK_PARAM_KEY);
    assert(success, 'Failed to do timelock update');

    // Verify parameter was updated
    let updated_value = governance.get_system_parameter(TIMELOCK_PARAM_KEY);
    assert(updated_value == new_value, 'Parameter not updated correctly');

    // Verify timelock was cleared
    let timelock_info = governance.get_timelock_info(TIMELOCK_PARAM_KEY);
    assert(!timelock_info.is_active, 'Timelock should be inactive');
}

#[test]
#[should_panic(expected: ('GOV: timelock not ready',))]
fn test_early_timelock_execution() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();

    start_cheat_caller_address(governance.contract_address, admin);

    let new_value: u256 = 5000000000000000000000000;
    governance.schedule_parameter_update(TIMELOCK_PARAM_KEY, new_value);

    // Try to execute before timelock duration - should fail
    governance.execute_timelock_update(TIMELOCK_PARAM_KEY);
}

#[test]
fn test_cancel_timelock_update() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();

    start_cheat_caller_address(governance.contract_address, admin);

    let new_value: u256 = 5000000000000000000000000;
    governance.schedule_parameter_update(TIMELOCK_PARAM_KEY, new_value);

    // Cancel the timelock
    let success = governance.cancel_timelock_update(TIMELOCK_PARAM_KEY);
    assert(success, 'Failed to cancel update');

    // Verify timelock was cancelled
    let timelock_info = governance.get_timelock_info(TIMELOCK_PARAM_KEY);
    assert(!timelock_info.is_active, 'Timelock should be inactive');
}

// ======================
// EMERGENCY CONTROLS TESTS
// ======================

#[test]
fn test_system_pause_unpause() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();

    start_cheat_caller_address(governance.contract_address, admin);

    // Initially system should not be paused
    assert(!governance.is_system_paused(), 'System should not be paused yet');

    // Pause system
    let success = governance.pause_system();
    assert(success, 'Failed to pause system');
    assert(governance.is_system_paused(), 'System should be paused');

    // Unpause system
    let success = governance.unpause_system();
    assert(success, 'Failed to unpause system');
    assert(!governance.is_system_paused(), 'System is paused after unpause');
}

#[test]
#[should_panic(expected: ('GOV: system paused',))]
fn test_operations_blocked_during_pause() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();
    let user: ContractAddress = USER();

    start_cheat_caller_address(governance.contract_address, admin);

    // Pause system
    governance.pause_system();

    // Try to assign role during pause - should fail
    governance.assign_admin_role(user, AdminRole::Admin);
}


#[test]
fn test_update_fee() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();

    start_cheat_caller_address(governance.contract_address, admin);

    let new_fee_value: u256 = 2500000000000000;
    let success = governance.update_fee(FEE_TYPE, new_fee_value);
    assert(success, 'Failed to update fee');

    // Verify fee was updated
    let retrieved_fee = governance.get_fee(FEE_TYPE);
    assert(retrieved_fee == new_fee_value, 'Fee not updated correctly');
}

#[test]
fn test_parameter_history_tracking() {
    let (_, governance) = deploy_starkremit_contract();
    let admin: ContractAddress = ADMIN();

    start_cheat_caller_address(governance.contract_address, admin);

    // Update parameter multiple times
    governance.set_system_parameter(SYSTEM_PARAMETER_KEY, 1000);
    governance.set_system_parameter(SYSTEM_PARAMETER_KEY, 2000);
    governance.set_system_parameter(SYSTEM_PARAMETER_KEY, 3000);

    // Check history count
    let history_count = governance.get_parameter_history_count(SYSTEM_PARAMETER_KEY);
    assert(history_count == 3, 'History count should be 3');

    // Check specific history entry
    let history_entry = governance.get_parameter_history(SYSTEM_PARAMETER_KEY, 0);
    assert(history_entry.new_value == 1000, 'First history entry incorrect');
    assert(history_entry.changed_by == admin, 'History changed_by incorrect');

    let history_entry_2 = governance.get_parameter_history(SYSTEM_PARAMETER_KEY, 1);
    assert(history_entry_2.old_value == 1000, 'old_value is incorrect');
    assert(history_entry_2.new_value == 2000, 'new_value is incorrect');
}

#[test]
fn test_timelock_duration() {
    let (_, governance) = deploy_starkremit_contract();

    let duration = governance.get_timelock_duration();
    assert(duration == 172800, 'Timelock should be 48 hours');
}

#[test]
fn test_requires_timelock() {
    let (_, governance) = deploy_starkremit_contract();

    // MAX_TX_AMOUNT should require timelock (set in initialization)
    assert(governance.requires_timelock(TIMELOCK_PARAM_KEY), 'max amount not need timelock');

    // Regular parameters should not require timelock
    assert(!governance.requires_timelock(SYSTEM_PARAMETER_KEY), 'SERVICE_FEE not need timelock');
}


#[test]
fn test_admin_workflow_integration() {
    let (_, governance) = deploy_starkremit_contract();

    // INTEGRATION TESTS
    let super_admin: ContractAddress = ADMIN(); // This is the admin that is now superadmin 

    //   This will be a regular Admin (not SuperAdmin) with limited privileges
    let admin_user: ContractAddress = ADMIN_USER();

    let kyc_manager: ContractAddress = KYC_MANAGER();

    let initial_role = governance.get_admin_role(super_admin);
    assert(initial_role == AdminRole::SuperAdmin, 'SuperAdmin not set for deploy');

    start_cheat_caller_address(governance.contract_address, super_admin);

    governance.assign_admin_role(admin_user, AdminRole::Admin);
    governance.assign_admin_role(kyc_manager, AdminRole::KYCManager);

    // Set bounds for parameters to ensure values stay within safe ranges
    let bounds = ParameterBounds { min_value: 0, max_value: 10000 };
    governance.set_parameter_bounds('INTEGRATION_PARAM', bounds);

    let test_contract: ContractAddress = TEST_CONTRACT();
    governance.register_contract('INTEGRATION_CONTRACT', test_contract);

    start_cheat_caller_address(governance.contract_address, admin_user);
    // Admin can set system parameters (within bounds set by SuperAdmin)
    governance.set_system_parameter('INTEGRATION_PARAM', 5000);
    governance.update_fee('INTEGRATION_FEE', 1500);

    // Switch back to super_admin to verify all operations completed successfully
    start_cheat_caller_address(governance.contract_address, super_admin);

    // Verify role assignments worked
    assert(governance.get_admin_role(admin_user) == AdminRole::Admin, 'Admin role not assigned');
    assert(
        governance.get_admin_role(kyc_manager) == AdminRole::KYCManager,
        'KYC Manager role not assigned',
    );

    // Verify parameter and fee updates worked
    assert(governance.get_system_parameter('INTEGRATION_PARAM') == 5000, 'Parameter not updated');
    assert(governance.get_fee('INTEGRATION_FEE') == 1500, 'Fee not updated');

    // Verify contract registration worked
    assert(governance.is_contract_registered('INTEGRATION_CONTRACT'), 'Contract not registered');
}
