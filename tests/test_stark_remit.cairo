// tests/starkremit_system_test.cairo
use starkremit_contract::starkremit::StarkRemit;
use starkremit_contract::interfaces::IStarkRemit::{IStarkRemitDispatcherTrait, IStarkRemitDispatcher};

use starkremit_contract::starkremit::StarkRemit::{
    AgentAuthorized, ContractUpgradeCompleted, EmergencyPauseActivated, EmergencyPauseDeactivated,
    MultiSigOperationProposed, MultiSigOperationApproved, MultiSigOperationExecuted, AuditTrailEntry,
    AgentPermissionUpdated, ContractUpgradeRolledBack
};
use snforge_std::{
    declare, start_cheat_caller_address_global, stop_cheat_caller_address_global,
    ContractClassTrait, DeclareResultTrait, spy_events, EventSpyAssertionsTrait, load, Event
};
use starknet::{ContractAddress, contract_address_const, get_caller_address, get_block_timestamp,};

// Helper function to deploy the contract
fn deploy() -> (IStarkRemitDispatcher, ContractAddress) {
    let contract = declare("StarkRemit").unwrap().contract_class();
    let owner = contract_address_const::<'owner'>();
    let oracle = contract_address_const::<'oracle'>();
    let token = contract_address_const::<'token'>();
    
    start_cheat_caller_address_global(owner);
    let (contract_address, _) = contract.deploy(@array![owner.into(), oracle.into(), token.into()]).unwrap();
    stop_cheat_caller_address_global();
    
    (IStarkRemitDispatcher { contract_address }, owner)
}

#[test]
fn test_authorize_agent() {
    let (contract, owner) = deploy();
    let admin = contract_address_const::<'admin'>();
    let agent = contract_address_const::<'agent'>();

    // Grant admin role first
    start_cheat_caller_address_global(owner);
    contract.grant_admin_role(admin);
    stop_cheat_caller_address_global();

    // Authorize agent
    start_cheat_caller_address_global(admin);
    
    let mut spy = spy_events();
    contract.authorize_agent(agent, 'WRITE', true);

    // Verify event emission
    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                StarkRemit::Event::AgentAuthorized(AgentAuthorized {
                    agent_address: agent,
                    permission: 'WRITE',
                    authorized: true,
                    caller: admin,
                }),
            ),
        ],
    );

    // Verify storage update
    let is_authorized = load(
        contract.contract_address,
        selector!("agent_permissions"),
        1, // Length of the storage slot
    );
    assert(is_authorized == array![1], "Agent should be authorized");
    
    stop_cheat_caller_address_global();
}

#[test]
fn test_upgrade_contract() {
    let (contract, owner) = deploy();
    let new_class_hash = 12345; // Mock class hash
    
    start_cheat_caller_address_global(owner);
    
    let mut spy = spy_events();
    contract.upgrade_contract(new_class_hash);
    
    // Verify event emission
    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                StarkRemit::Event::ContractUpgradeCompleted(ContractUpgradeCompleted {
                    old_class_hash: 0, // Placeholder
                    new_class_hash,
                    version: 1,
                    caller: owner,
                }),
            ),
        ],
    );

    // Verify upgrade history
    let upgrade_record: UpgradeRecord = load(
        contract.contract_address,
        selector!("upgrade_history"),
        4, // Number of fields in UpgradeRecord
    ).try_into().unwrap();
    
    assert(upgrade_record.class_hash == new_class_hash, "Class hash should be updated");
    assert(upgrade_record.version == 1, "Version should be incremented");
    
    stop_cheat_caller_address_global();
}

#[test]
fn test_emergency_pause() {
    let (contract, owner) = deploy();
    let admin = contract_address_const::<'admin'>();
    let function_selector = selector!("complete_transfer");
    let expires_at = get_block_timestamp() + 86400; // 1 day from now

    // Setup: Grant admin role and set pauser
    start_cheat_caller_address_global(owner);
    contract.grant_admin_role(admin);
    contract.set_pauser(admin, true);
    stop_cheat_caller_address_global();

    // Test pause
    start_cheat_caller_address_global(admin);
    
    let mut spy = spy_events();
    contract.emergency_pause_function(function_selector, expires_at);
    
    // Verify event
    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                StarkRemit::Event::EmergencyPauseActivated(EmergencyPauseActivated {
                    function_selector,
                    caller: admin,
                    expires_at,
                }),
            ),
        ],
    );

    // Verify pause status
    let is_paused = load(
        contract.contract_address,
        selector!("paused_functions"),
        1,
    );
    assert(is_paused == array![1], 'Function should be paused');

    // Test unpause
    contract.emergency_unpause_function(function_selector);
    
    // Verify unpause event
    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                StarkRemit::Event::EmergencyPauseDeactivated(EmergencyPauseDeactivated {
                    function_selector,
                    caller: admin,
                }),
            ),
        ],
    );
    
    stop_cheat_caller_address_global();
}

#[test]
fn test_multi_sig_workflow() {
    let (contract, owner) = deploy();
    let signer1 = contract_address_const::<'signer1'>();
    let signer2 = contract_address_const::<'signer2'>();
    let target_contract = contract_address_const::<'target'>();
    let selector = selector!("upgrade_contract");
    let op_id = 'operation_1';

    // Setup: Set multi-sig signers
    start_cheat_caller_address_global(owner);
    contract.set_multi_sig_signer(signer1, true);
    contract.set_multi_sig_signer(signer2, true);
    stop_cheat_caller_address_global();

    // Test proposal
    start_cheat_caller_address_global(signer1);
    
    let mut spy = spy_events();
    contract.propose_critical_operation(op_id, target_contract, selector);
    
    // Verify proposal event
    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                StarkRemit::Event::MultiSigOperationProposed(MultiSigOperationProposed {
                    op_id,
                    target_contract,
                    selector,
                    proposer: signer1,
                }),
            ),
        ],
    );

    // Test confirmation
    start_cheat_caller_address_global(signer2);
    contract.confirm_critical_operation(op_id);
    
    // Verify confirmation event
    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                StarkRemit::Event::MultiSigOperationApproved(MultiSigOperationApproved {
                    op_id,
                    approver: signer2,
                    confirmations_count: 2,
                }),
            ),
        ],
    );

    // Test execution
    contract.execute_critical_operation(op_id);
    
    // Verify execution event
    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                StarkRemit::Event::MultiSigOperationExecuted(MultiSigOperationExecuted {
                    op_id,
                    executor: signer2,
                }),
            ),
        ],
    );
    
    stop_cheat_caller_address_global();
}

#[test]
fn test_audit_trail() {
    let (contract, owner) = deploy();
    let action = 'security_action';
    let details = 'user_deactivated';
    
    start_cheat_caller_address_global(owner);
    
    let mut spy = spy_events();
    contract.log_security_action(action, owner, details);
    
    // Verify audit event
    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                StarkRemit::Event::AuditTrailEntry(AuditTrailEntry {
                    action,
                    actor: owner,
                    timestamp: get_block_timestamp(),
                    details,
                }),
            ),
        ],
    );

    // Verify audit trail storage
    let audit_entry: AuditEntry = load(
        contract.contract_address,
        selector!("audit_trail"),
        4, // Number of fields in AuditEntry
    ).try_into().unwrap();
    
    assert(audit_entry.action == action, 'Action should match');
    assert(audit_entry.actor == owner, "Actor should match");
    assert(audit_entry.details == details, "Details should match");
    
    stop_cheat_caller_address_global();
}

#[test]
fn test_rollback_contract() {
    let (contract, owner) = deploy();
    let version1_hash = 12345;
    let version2_hash = 67890;
    
    // Perform two upgrades
    start_cheat_caller_address_global(owner);
    contract.upgrade_contract(version1_hash);
    contract.upgrade_contract(version2_hash);
    
    let mut spy = spy_events();
    contract.rollback_contract(1); // Rollback to version 1
    
    // Verify rollback event
    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                StarkRemit::Event::ContractUpgradeRolledBack(ContractUpgradeRolledBack {
                    old_class_hash: 0, // Placeholder
                    new_class_hash: version1_hash,
                    target_version: 1,
                    caller: owner,
                }),
            ),
        ],
    );

    // Verify version was rolled back
    let current_version = load(
        contract.contract_address,
        selector!("upgrade_count"),
        1,
    );
    assert(current_version == array![1], 'Version should be rolled back to 1');
    
    stop_cheat_caller_address_global();
}

#[test]
fn test_revoke_permission() {
    let (contract, owner) = deploy();
    let admin = contract_address_const::<'admin'>();
    let agent = contract_address_const::<'agent'>();
    
    // Setup: Grant admin and authorize agent
    start_cheat_caller_address_global(owner);
    contract.grant_admin_role(admin);
    stop_cheat_caller_address_global();
    
    start_cheat_caller_address_global(admin);
    contract.authorize_agent(agent, 'WRITE', true);
    
    let mut spy = spy_events();
    contract.authorize_agent(agent, 'WRITE', false); // Revoke permission
    
    // Verify revocation event
    spy.assert_emitted(
        @array![
            (
                contract.contract_address,
                StarkRemit::Event::AgentPermissionUpdated(AgentPermissionUpdated {
                    agent_address: agent,
                    permission: 'WRITE',
                    authorized: false,
                    caller: admin,
                }),
            ),
        ],
    );

    // Verify storage update
    let is_authorized = load(
        contract.contract_address,
        selector!("agent_permissions"),
        1,
    );
    assert(is_authorized == array![0], 'Permission should be revoked');
    
    stop_cheat_caller_address_global();
}
