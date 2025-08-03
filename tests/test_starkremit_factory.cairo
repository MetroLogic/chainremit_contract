// *************************************************************************
//                              TEST
// *************************************************************************
// core imports
use core::result::ResultTrait;

// OZ imports
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// snforge imports
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp, start_cheat_caller_address_global,
    stop_cheat_caller_address_global,
};

// starknet imports
use starknet::{ContractAddress, contract_address_const};

// starkremit imports
use starkremit_contract::base::errors::*;
use starkremit_contract::base::events::*;
use starkremit_contract::base::types::*;
use starkremit_contract::interfaces::IERC20::{
    IERC20MintableDispatcher, IERC20MintableDispatcherTrait,
};
use starkremit_contract::interfaces::IStarkRemit::{
    IStarkRemitDispatcher, IStarkRemitDispatcherTrait,
};


pub fn OWNER() -> ContractAddress {
    contract_address_const::<'OWNER'>()
}
pub fn TOKEN_ADDRESS() -> ContractAddress {
    contract_address_const::<'TOKEN_ADDRESS'>()
}

pub fn ORACLE_ADDRESS() -> ContractAddress {
    contract_address_const::<0x2a85bd616f912537c50a49a4076db02c00b29b2cdc8a197ce92ed1837fa875b>()
}

pub fn USER() -> ContractAddress {
    contract_address_const::<'USER'>()
}

// *************************************************************************
//                              SETUP
// *************************************************************************
// return istrkremit contract address,
fn __setup__() -> (ContractAddress, IStarkRemitDispatcher, IERC20Dispatcher) {
    let strk_token_name: ByteArray = "STARKNET_TOKEN";

    let strk_token_symbol: ByteArray = "STRK";

    let decimals: u8 = 18;

    let erc20_class_hash = declare("ERC20Upgradeable").unwrap().contract_class();
    let mut strk_constructor_calldata = array![];
    strk_token_name.serialize(ref strk_constructor_calldata);
    strk_token_symbol.serialize(ref strk_constructor_calldata);
    decimals.serialize(ref strk_constructor_calldata);
    OWNER().serialize(ref strk_constructor_calldata);

    let (strk_contract_address, _) = erc20_class_hash.deploy(@strk_constructor_calldata).unwrap();

    let strk_mintable_dispatcher = IERC20MintableDispatcher {
        contract_address: strk_contract_address,
    };
    start_cheat_caller_address_global(OWNER());
    strk_mintable_dispatcher.mint(USER(), 1_000_000_000_000_000_000);
    stop_cheat_caller_address_global();

    let ierc20_dispatcher = IERC20Dispatcher { contract_address: strk_contract_address };

    let (starkremit_contract_address, starkremit_dispatcher) = deploy_starkremit_contract();

    return (starkremit_contract_address, starkremit_dispatcher, ierc20_dispatcher);
}


fn deploy_starkremit_contract() -> (ContractAddress, IStarkRemitDispatcher) {
    let starkremit_class_hash = declare("StarkRemit").unwrap().contract_class();
    let mut starkremit_constructor_calldata = array![];
    OWNER().serialize(ref starkremit_constructor_calldata);
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

// Helper function to create test registration data
fn create_test_registration() -> RegistrationRequest {
    RegistrationRequest {
        email_hash: 'test@email.com',
        phone_hash: '+1234567890',
        full_name: 'Test User',
        country_code: 'US',
    }
}

// Helper function to create unique test registration data
fn create_unique_registration(suffix: felt252) -> RegistrationRequest {
    RegistrationRequest {
        email_hash: suffix, // Use suffix as unique email
        phone_hash: suffix + 1000, // Unique phone too
        full_name: 'Test User',
        country_code: 'US',
    }
}

#[test]
fn test_constructor_initializes_correctly() {
    let (_, starkremit_dispatcher, _) = __setup__();

    // Check owner address
    let owner = starkremit_dispatcher.get_owner();
    assert_eq!(owner, OWNER(), "Owner address should match the initialized owner");
}

#[test]
fn test_user_registration() {
    let (_, starkremit_dispatcher, _) = __setup__();
    let user = contract_address_const::<'test_user'>();
    let registration_data = create_test_registration();

    // Register user
    start_cheat_caller_address_global(user);
    let result = starkremit_dispatcher.register_user(registration_data);
    stop_cheat_caller_address_global();

    assert_eq!(result, true, "User registration should succeed");

    // Verify user is registered
    let is_registered = starkremit_dispatcher.is_user_registered(user);
    assert_eq!(is_registered, true, "User should be registered");

    // Check registration status
    let status = starkremit_dispatcher.get_registration_status(user);
    assert_eq!(status, RegistrationStatus::Completed, "Registration status should be completed");
}

#[test]
fn test_get_user_profile() {
    let (_, starkremit_dispatcher, _) = __setup__();
    let user = contract_address_const::<'profile_user'>();
    let registration_data = create_test_registration();

    // Register user first
    start_cheat_caller_address_global(user);
    starkremit_dispatcher.register_user(registration_data);
    stop_cheat_caller_address_global();

    // Get user profile
    let profile = starkremit_dispatcher.get_user_profile(user);
    assert_eq!(profile.address, user, "Profile address should match");
    assert_eq!(profile.email_hash, 'test@email.com', "Email hash should match");
    assert_eq!(profile.full_name, 'Test User', "Full name should match");
    assert_eq!(profile.country_code, 'US', "Country code should match");
}


#[test]
fn test_governance_roles() {
    let (_, starkremit_dispatcher, _) = __setup__();
    let user = contract_address_const::<'gov_user'>();

    // Assign admin role
    start_cheat_caller_address_global(OWNER());
    let result = starkremit_dispatcher.assign_admin_role(user, GovRole::Admin);
    stop_cheat_caller_address_global();

    assert_eq!(result, true, "Role assignment should succeed");

    // Check user role
    let role = starkremit_dispatcher.get_admin_role(user);
    assert_eq!(role, GovRole::Admin, "User should have admin role");

    // Check minimum role
    let has_role = starkremit_dispatcher.has_minimum_role(user, GovRole::Operator);
    assert_eq!(has_role, true, "User should have minimum operator role");
}

#[test]
fn test_savings_group_creation() {
    let (_, starkremit_dispatcher, _) = __setup__();
    let user = contract_address_const::<'group_user'>();
    let registration_data = create_test_registration();

    // Register user
    start_cheat_caller_address_global(user);
    starkremit_dispatcher.register_user(registration_data);
    stop_cheat_caller_address_global();

    // Create savings group
    start_cheat_caller_address_global(user);
    let group_id = starkremit_dispatcher.create_group(10); // max 10 members
    stop_cheat_caller_address_global();

    assert_eq!(group_id, 0, "First group should have ID 0");
}

#[test]
fn test_system_parameters() {
    let (_, starkremit_dispatcher, _) = __setup__();

    // First set parameter bounds, then set parameter value
    start_cheat_caller_address_global(OWNER());
    // Assign SuperAdmin role to owner first
    starkremit_dispatcher.assign_admin_role(OWNER(), GovRole::SuperAdmin);

    // Set parameter bounds
    let bounds = ParameterBounds { min_value: 100, max_value: 10000 };
    starkremit_dispatcher.set_parameter_bounds('test_param', bounds);

    // Set system parameter within valid bounds
    let result = starkremit_dispatcher.set_system_parameter('test_param', 1000);
    stop_cheat_caller_address_global();

    assert_eq!(result, true, "Parameter setting should succeed");

    // Get system parameter
    let value = starkremit_dispatcher.get_system_parameter('test_param');
    assert_eq!(value, 1000, "Parameter value should match");
}

#[test]
fn test_total_users_count() {
    let (_, starkremit_dispatcher, _) = __setup__();
    let user1 = contract_address_const::<'count_user1'>();
    let user2 = contract_address_const::<'count_user2'>();
    let registration_data = create_test_registration();

    // Initial count should be 0
    let initial_count = starkremit_dispatcher.get_total_users();
    assert_eq!(initial_count, 0, "Initial count should be 0");

    // Register first user
    let user1_data = create_unique_registration('user1@test.com');
    start_cheat_caller_address_global(user1);
    starkremit_dispatcher.register_user(user1_data);
    stop_cheat_caller_address_global();

    let count_after_first = starkremit_dispatcher.get_total_users();
    assert_eq!(count_after_first, 1, "Count should be 1 after first user");

    // Register second user
    let user2_data = create_unique_registration('user2@test.com');
    start_cheat_caller_address_global(user2);
    starkremit_dispatcher.register_user(user2_data);
    stop_cheat_caller_address_global();

    let final_count = starkremit_dispatcher.get_total_users();
    assert_eq!(final_count, 2, "Count should be 2 after second user");
}
