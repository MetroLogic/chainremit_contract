// Role-based Access Control and Multi-Signature Logic for StarkRemit
// SPDX-License-Identifier: MIT

use array::ArrayTrait;
use starknet::storage::LegacyMap;
use starknet::{get_block_timestamp, get_caller_address};
use starkremit_contract::base::events::{
    ActionConfirmed, ActionExecuted, ActionProposed, Paused, Unpaused,
};
use traits::Into;

// Role constants (bitmask)
const ROLE_ADMIN: u8 = 1;
const ROLE_MINTER: u8 = 2;
const ROLE_KYC_MANAGER: u8 = 4;

// Pending action types
// Expanded for all admin actions
enum PendingActionType {
    Mint,
    AddMinter,
    RemoveMinter,
    UpdateKYC,
    DeactivateUser,
    ReactivateUser,
    SuspendKYC,
    ReinstateKYC,
    SetKYCEnforcement,
    Pause,
    Unpause,
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
fn propose_action(
    mut pending_actions: LegacyMap<felt252, PendingAction>,
    roles: LegacyMap<ContractAddress, u8>,
    action_type: PendingActionType,
    params_hash: felt252,
    delay_seconds: u64,
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
    emit
    ActionProposed {
        action_id, action_type: action_type.into(), proposer: get_caller_address(), execute_after,
    };
    action_id
}

fn confirm_action(
    mut pending_actions: LegacyMap<felt252, PendingAction>,
    roles: LegacyMap<ContractAddress, u8>,
    action_id: felt252,
) {
    only_role(roles, ROLE_ADMIN);
    let mut pending = pending_actions.read(action_id);
    assert(!pending.executed, 'ActionAlreadyExecuted');
    let caller = get_caller_address();
    // Prevent duplicate confirmations by the same address
    let mut already_confirmed = false;
    for i in 0..pending.confirmations.len() {
        if pending.confirmations.get(i) == caller {
            already_confirmed = true;
            break;
        }
    }
    assert(!already_confirmed, 'AlreadyConfirmed');
    pending.confirmations.append(caller);
    pending_actions.write(action_id, pending);
    emit
    ActionConfirmed { action_id, confirmer: caller };
}

fn execute_action(
    mut pending_actions: LegacyMap<felt252, PendingAction>,
    roles: LegacyMap<ContractAddress, u8>,
    action_id: felt252,
    min_confirmations: u8,
) {
    only_role(roles, ROLE_ADMIN);
    let mut pending = pending_actions.read(action_id);
    assert(!pending.executed, 'ActionAlreadyExecuted');
    assert(get_block_timestamp() >= pending.execute_after, 'ActionTooEarly');
    assert(pending.confirmations.len() >= min_confirmations, 'NotEnoughConfirmations');
    // Here you would call handle_action for real business logic
    pending.executed = true;
    pending_actions.write(action_id, pending);
    emit
    ActionExecuted { action_id };
}

fn vote_pause(
    mut pause_votes: LegacyMap<ContractAddress, bool>,
    roles: LegacyMap<ContractAddress, u8>,
    paused: bool,
    pause_vote_count: u8,
    required_votes: u8,
) -> bool {
    let caller = get_caller_address();
    assert(has_role(roles, caller, ROLE_ADMIN), 'NotAuthorized');
    assert(!pause_votes.read(caller), 'AlreadyVoted');
    pause_votes.write(caller, true);
    let new_count = pause_vote_count + 1_u8;
    if new_count >= required_votes {
        emit
        Paused { pauser: caller };
        return true;
    }
    false
}

// Handler stub for critical actions (expand as needed)
fn handle_action(action_type: PendingActionType, params_hash: felt252) {
    match action_type {
        PendingActionType::Pause => {
            emit
            Paused { pauser: get_caller_address() };
        },
        PendingActionType::Unpause => {
            emit
            Unpaused { unpauser: get_caller_address() };
        },
        PendingActionType::Mint => {
            // Example: params_hash is the address to mint to (for demo)
            let to: ContractAddress = params_hash.into();
            // TODO: decode amount as well if needed
        // _mint(to, amount);
        },
        PendingActionType::AddMinter => {
            // params_hash is the address to add as minter
            let minter_address: ContractAddress = params_hash.into();
            let current_roles = roles.read(minter_address);
            roles.write(minter_address, current_roles | ROLE_MINTER);
        },
        PendingActionType::RemoveMinter => {
            // params_hash is the address to remove as minter
            let minter_address: ContractAddress = params_hash.into();
            let current_roles = roles.read(minter_address);
            roles.write(minter_address, current_roles & ~ROLE_MINTER);
        },
        PendingActionType::UpdateKYC => { // TODO: decode params_hash to get user address and new KYC level
        // update_kyc(user, new_level);
        },
        PendingActionType::DeactivateUser => { // TODO: decode params_hash to get user address
        // deactivate_user(user);
        },
        PendingActionType::ReactivateUser => { // TODO: decode params_hash to get user address
        // reactivate_user(user);
        },
        PendingActionType::SuspendKYC => { // TODO: decode params_hash to get user address
        // suspend_kyc(user);
        },
        PendingActionType::ReinstateKYC => { // TODO: decode params_hash to get user address
        // reinstate_kyc(user);
        },
        PendingActionType::SetKYCEnforcement => { // TODO: decode params_hash to get enforcement flag
        // set_kyc_enforcement(flag);
        },
        _ => {},
    }
}

// Community pause voting
fn vote_pause(
    pause_votes: LegacyMap<ContractAddress, bool>,
    roles: LegacyMap<ContractAddress, u8>,
    paused: bool,
    pause_vote_count: u8,
    required_votes: u8,
) -> bool {
    let caller = get_caller_address();
    assert(has_role(roles, caller, ROLE_ADMIN), 'NotAuthorized');
    assert(!pause_votes.read(caller), 'AlreadyVoted');
    pause_votes.write(caller, true);
    let new_count = pause_vote_count + 1;
    if new_count >= required_votes {
        emit
        Paused { pauser: caller };
        return true;
    }
    false
}

// Propose action for any role (not just admin)
fn propose_action_for_role(
    pending_actions: LegacyMap<felt252, PendingAction>,
    roles: LegacyMap<ContractAddress, u8>,
    action_type: PendingActionType,
    params_hash: felt252,
    delay_seconds: u64,
    required_role: u8,
) -> felt252 {
    only_role(roles, required_role);
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
    emit
    ActionProposed {
        action_id, action_type: action_type.into(), proposer: get_caller_address(), execute_after,
    };
    action_id
}
