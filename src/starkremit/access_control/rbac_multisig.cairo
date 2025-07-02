// Role-based Access Control and Multi-Signature Logic for StarkRemit
// SPDX-License-Identifier: MIT

use starknet::get_block_timestamp;
use starknet::get_caller_address;
use starknet::storage::LegacyMap;
use array::ArrayTrait;
use traits::Into;
use starkremit_contract::base::events::{ActionProposed, ActionConfirmed, ActionExecuted, Paused, Unpaused};

// Role constants (bitmask)
const ROLE_ADMIN: u8 = 1;
const ROLE_MINTER: u8 = 2;
const ROLE_KYC_MANAGER: u8 = 4;

// Pending action types
enum PendingActionType {
    Mint = 0,
    AddMinter = 1,
    RemoveMinter = 2,
    UpdateKYC = 3,
    Pause = 4,
    Unpause = 5,
}

struct PendingAction {
    action_type: PendingActionType,
    params_hash: felt252, // hash of params for simplicity
    proposer: ContractAddress,
    confirmations: Array<ContractAddress>,
    execute_after: u64, // unix timestamp
    executed: bool,
}

// RBAC helpers
fn has_role(roles: LegacyMap<ContractAddress, u8>, addr: ContractAddress, role: u8) -> bool {
    let r = roles.read(addr);
    r & role != 0
}

fn only_role(roles: LegacyMap<ContractAddress, u8>, role: u8) {
    let caller = get_caller_address();
    assert(has_role(roles, caller, role), 'NotAuthorized');
}

fn require_not_paused(paused: bool) {
    assert(paused == false, 'Paused');
}

// Helper: hash action params (for simplicity, just use params_hash directly)
fn hash_action(action_type: PendingActionType, params_hash: felt252, timestamp: u64) -> felt252 {
    // In production, use a real hash function
    action_type.into() + params_hash + timestamp.into()
}

// Multi-sig helpers
// Enhanced propose_action with event emission
fn propose_action(
    pending_actions: LegacyMap<felt252, PendingAction>,
    roles: LegacyMap<ContractAddress, u8>,
    action_type: PendingActionType,
    params_hash: felt252,
    delay_seconds: u64
) -> felt252 {
    only_role(roles, ROLE_ADMIN);
    let action_id = hash_action(action_type, params_hash, get_block_timestamp());
    let execute_after = get_block_timestamp() + delay_seconds;
    let mut confirmations = ArrayTrait::new();
    confirmations.append(get_caller_address());
    let pending = PendingAction {
        action_type,
        params_hash,
        proposer: get_caller_address(),
        confirmations,
        execute_after,
        executed: false,
    };
    pending_actions.write(action_id, pending);
    emit ActionProposed { action_id, action_type: action_type.into(), proposer: get_caller_address(), execute_after };
    action_id
}

// Enhanced confirm_action with event emission
fn confirm_action(pending_actions: LegacyMap<felt252, PendingAction>, roles: LegacyMap<ContractAddress, u8>, action_id: felt252) {
    only_role(roles, ROLE_ADMIN);
    let mut pending = pending_actions.read(action_id);
    assert(!pending.executed, 'ActionAlreadyExecuted');
    let caller = get_caller_address();
    assert(!pending.confirmations.contains(caller), 'AlreadyConfirmed');
    pending.confirmations.append(caller);
    pending_actions.write(action_id, pending);
    emit ActionConfirmed { action_id, confirmer: caller };
}

// Enhanced execute_action with event emission and handler stub
fn execute_action(
    pending_actions: LegacyMap<felt252, PendingAction>,
    roles: LegacyMap<ContractAddress, u8>,
    action_id: felt252,
    min_confirmations: u8
) {
    only_role(roles, ROLE_ADMIN);
    let mut pending = pending_actions.read(action_id);
    assert(!pending.executed, 'ActionAlreadyExecuted');
    assert(get_block_timestamp() >= pending.execute_after, 'ActionTooEarly');
    assert(pending.confirmations.len() >= min_confirmations, 'NotEnoughConfirmations');
    // Call the actual action handler (to be implemented per action)
    handle_action(pending.action_type, pending.params_hash);
    pending.executed = true;
    pending_actions.write(action_id, pending);
    emit ActionExecuted { action_id };
}

// Handler stub for critical actions (expand as needed)
fn handle_action(action_type: PendingActionType, params_hash: felt252) {
    match action_type {
        PendingActionType::Pause => { emit Paused { pauser: get_caller_address() }; },
        PendingActionType::Unpause => { emit Unpaused { unpauser: get_caller_address() }; },
        _ => { /* implement as needed */ }
    }
}

// Community pause voting
// Enhanced community pause voting with event emission
fn vote_pause(pause_votes: LegacyMap<ContractAddress, bool>, roles: LegacyMap<ContractAddress, u8>, paused: bool, pause_vote_count: u8, required_votes: u8) -> bool {
    let caller = get_caller_address();
    assert(has_role(roles, caller, ROLE_ADMIN), 'NotAuthorized');
    assert(!pause_votes.read(caller), 'AlreadyVoted');
    pause_votes.write(caller, true);
    let new_count = pause_vote_count + 1;
    if new_count >= required_votes {
        emit Paused { pauser: caller };
        return true;
    }
    false
}
