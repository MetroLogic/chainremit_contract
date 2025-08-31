use starknet::ContractAddress;
// Replaced starknet::testing imports with snforge_std cheatcodes
use starknet::contract_address_const;
use starkremit_contract::component::emergency::{
    emergency_component, IEmergency, IEmergencyDispatcher, IEmergencyDispatcherTrait,
    EmergencyConfig
};
// Required snforge_std imports for deployment and cheatcodes
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp
};
use core::array::ArrayTrait; // Needed for array! macro and Serde

const ADMIN: felt252 = 0x123;
const NON_ADMIN: felt252 = 0x456;
const MEMBER: felt252 = 0x789;

#[starknet::contract]
mod TestContract {
    use super::*;
    
    component!(path: emergency_component, storage: emergency, event: EmergencyEvent);
    
    #[storage]
    struct Storage {
        #[substorage(v0)]
        emergency: emergency_component::Storage,
    }
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        EmergencyEvent: emergency_component::Event,
    }
    
    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.emergency.initializer(admin);
    }
    
    #[abi(embed_v0)]
    impl EmergencyInternalImpl = emergency_component::InternalImpl<ContractState>;
}

// Fixed setup function to correctly deploy the contract and set initial cheats
fn setup() -> ContractAddress {
    let admin_address = contract_address_const::<ADMIN>();
    
    let contract_class = declare("TestContract").unwrap().contract_class();
    
    let mut constructor_calldata = array![];
    Serde::serialize(@admin_address, ref constructor_calldata);
    
    let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();
    
    start_cheat_caller_address(contract_address, admin_address);
    start_cheat_block_timestamp(contract_address, 1000);

    contract_address
}

#[test]
fn test_emergency_initialization() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    
    // Test that component is initialized correctly
    assert!(!emergency.is_paused(), "Contract should start unpaused");
    assert!(emergency.get_pause_reason() == 0, "Initial pause reason should be 0");
    // Assuming initializer does not set a timestamp for pause, so it should be 0 initially
    assert!(emergency.get_pause_timestamp() == 0, "Initial pause timestamp should be 0"); 
    
    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
fn test_emergency_pause_unpause() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    
    // Test pause
    emergency.pause();
    assert!(emergency.is_paused(), "Contract should be paused");
    
    // Test unpause
    emergency.unpause();
    assert!(!emergency.is_paused(), "Contract should be unpaused");

    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
fn test_emergency_pause_with_metadata() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    
    // First pause the contract
    emergency.pause();
    
    // Set pause metadata
    let reason = 'emergency_maintenance';
    emergency.set_pause_meta(reason);
    
    assert!(emergency.get_pause_reason() == reason, "Pause reason should match");
    // The timestamp should be the cheated block timestamp from setup (1000) or a later value
    assert!(emergency.get_pause_timestamp() > 0, "Pause timestamp should be set"); 
    
    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
fn test_emergency_unpause_with_metadata_clear() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    
    // First pause the contract with metadata
    emergency.pause();
    emergency.set_pause_meta('test_reason');
    
    // Unpause and clear metadata
    emergency.unpause_with_metadata_clear();
    
    assert!(!emergency.is_paused(), "Contract should be unpaused");
    assert!(emergency.get_pause_reason() == 0, "Pause reason should be cleared");
    assert!(emergency.get_pause_timestamp() == 0, "Pause timestamp should be cleared");

    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test] 
fn test_emergency_ban_unban_member() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    let member_address = contract_address_const::<MEMBER>();
    
    // Test ban member
    emergency.set_ban(member_address, true);
    assert!(emergency.is_banned(member_address), "Member should be banned");
    
    // Test unban member
    emergency.set_ban(member_address, false);
    assert!(!emergency.is_banned(member_address), "Member should be unbanned");
    
    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
fn test_emergency_config() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    
    let config = EmergencyConfig {
        emergency_cooldown: 86400,
        required_approvals: 3,
    };
    
    emergency.set_config(config);
    let retrieved_config = emergency.get_config();
    
    assert!(retrieved_config.emergency_cooldown == 86400, "Cooldown should match");
    assert!(retrieved_config.required_approvals == 3, "Required approvals should match");
    
    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
fn test_emergency_assert_not_paused_success() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    
    // Should not panic when contract is not paused
    emergency.assert_not_paused();
    
    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
#[should_panic(expected: ('Emergency: contract is paused',))]
fn test_emergency_assert_not_paused_panic() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    
    // Pause the contract
    emergency.pause();
    
    // Should panic when contract is paused
    emergency.assert_not_paused();
    
    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
#[should_panic(expected: ('Emergency: not admin',))]
fn test_emergency_pause_unauthorized() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    let non_admin_address = contract_address_const::<NON_ADMIN>();
    
    start_cheat_caller_address(contract_address, non_admin_address);
    emergency.pause(); // This should panic
    

    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
#[should_panic(expected: ('Emergency: contract is paused',))]
fn test_emergency_double_pause() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    
    emergency.pause();
    emergency.pause(); // Should panic
    

    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
#[should_panic(expected: ('Emergency: contract not paused',))]
fn test_emergency_set_pause_meta_when_not_paused() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    
    // Try to set pause metadata without pausing first
    emergency.set_pause_meta('test_reason'); // Should panic
    

    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
#[should_panic(expected: ('Emergency: contract not paused',))]
fn test_emergency_unpause_when_not_paused() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    
    emergency.unpause(); // Should panic as contract is not paused
    

    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}

#[test]
fn test_emergency_component_integration() {
    let contract_address = setup();
    let emergency = IEmergencyDispatcher { contract_address };
    
    assert!(!emergency.is_paused(), "Should start unpaused");
    
    // Pause with reason
    emergency.pause();
    emergency.set_pause_meta('emergency_stop');
    assert!(emergency.is_paused(), "Should be paused");
    assert!(emergency.get_pause_reason() == 'emergency_stop', "Reason should match");
    
    emergency.unpause_with_metadata_clear();
    assert!(!emergency.is_paused(), "Should be unpaused");
    assert!(emergency.get_pause_reason() == 0, "Reason should be cleared");
    

    stop_cheat_caller_address(contract_address);
    stop_cheat_block_timestamp(contract_address);
}