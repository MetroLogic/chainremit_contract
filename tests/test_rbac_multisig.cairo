// SPDX-License-Identifier: MIT
// Test suite for RBAC and Multi-Signature Logic (rbac_multisig.cairo)
// Project: StarkRemit

use array::ArrayTrait;
use starknet::storage::LegacyMap;
use starknet::testing::{get_caller_address, start_prank, stop_prank};
use starkremit_contract::starkremit::access_control::rbac_multisig::*;
use traits::Into;

#[test]
fn test_role_assignment_and_check() {
    let mut roles = LegacyMap::<ContractAddress, u8>::new();
    let admin: ContractAddress = 0x1;
    let minter: ContractAddress = 0x2;
    roles.write(admin, ROLE_ADMIN);
    roles.write(minter, ROLE_MINTER);
    assert(has_role(roles, admin, ROLE_ADMIN), 'Admin should have admin role');
    assert(!has_role(roles, minter, ROLE_ADMIN), 'Minter should not have admin role');
}

#[test]
fn test_only_role_enforcement() {
    let mut roles = LegacyMap::<ContractAddress, u8>::new();
    let admin: ContractAddress = 0x1;
    roles.write(admin, ROLE_ADMIN);
    start_prank(admin);
    only_role(roles, ROLE_ADMIN); // Should not panic
    stop_prank();
}

#[test]
#[should_panic]
fn test_only_role_enforcement_fail() {
    let mut roles = LegacyMap::<ContractAddress, u8>::new();
    let not_admin: ContractAddress = 0x3;
    roles.write(not_admin, 0);
    start_prank(not_admin);
    only_role(roles, ROLE_ADMIN); // Should panic
    stop_prank();
}

#[test]
fn test_propose_and_confirm_action() {
    let mut roles = LegacyMap::<ContractAddress, u8>::new();
    let mut pending_actions = LegacyMap::<felt252, PendingAction>::new();
    let admin: ContractAddress = 0x1;
    roles.write(admin, ROLE_ADMIN);
    start_prank(admin);
    let action_id = propose_action(pending_actions, roles, PendingActionType::Pause, 123, 10);
    confirm_action(pending_actions, roles, action_id); // Should succeed
    stop_prank();
}

#[test]
#[should_panic]
fn test_duplicate_confirmation_prevention() {
    let mut roles = LegacyMap::<ContractAddress, u8>::new();
    let mut pending_actions = LegacyMap::<felt252, PendingAction>::new();
    let admin: ContractAddress = 0x1;
    roles.write(admin, ROLE_ADMIN);
    start_prank(admin);
    let action_id = propose_action(pending_actions, roles, PendingActionType::Pause, 123, 10);
    confirm_action(pending_actions, roles, action_id); // First confirmation
    confirm_action(pending_actions, roles, action_id); // Should panic (duplicate)
    stop_prank();
}

#[test]
fn test_execute_action_with_min_confirmations() {
    let mut roles = LegacyMap::<ContractAddress, u8>::new();
    let mut pending_actions = LegacyMap::<felt252, PendingAction>::new();
    let admin1: ContractAddress = 0x1;
    let admin2: ContractAddress = 0x2;
    roles.write(admin1, ROLE_ADMIN);
    roles.write(admin2, ROLE_ADMIN);
    start_prank(admin1);
    let action_id = propose_action(pending_actions, roles, PendingActionType::Pause, 123, 0);
    stop_prank();
    start_prank(admin2);
    confirm_action(pending_actions, roles, action_id);
    stop_prank();
    // Simulate time passing for delay (if needed)
    start_prank(admin1);
    execute_action(pending_actions, roles, action_id, 2); // Should succeed with 2 confirmations
    stop_prank();
}

#[test]
fn test_vote_pause() {
    let mut roles = LegacyMap::<ContractAddress, u8>::new();
    let mut pause_votes = LegacyMap::<ContractAddress, bool>::new();
    let admin1: ContractAddress = 0x1;
    let admin2: ContractAddress = 0x2;
    roles.write(admin1, ROLE_ADMIN);
    roles.write(admin2, ROLE_ADMIN);
    let mut pause_vote_count = 0_u8;
    let required_votes = 2_u8;
    start_prank(admin1);
    let paused = vote_pause(pause_votes, roles, false, pause_vote_count, required_votes);
    assert(!paused, 'Should not pause yet');
    pause_vote_count = pause_vote_count + 1_u8;
    stop_prank();
    start_prank(admin2);
    let paused = vote_pause(pause_votes, roles, false, pause_vote_count, required_votes);
    assert(paused, 'Should pause now');
    stop_prank();
}
