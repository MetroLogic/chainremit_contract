use core::array::ArrayTrait;
use core::num::traits::Pow;
use core::result::ResultTrait;
use core::traits::TryInto;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use starkremit_contract::interfaces::IStarkRemit::{
    IStarkRemitDispatcher, IStarkRemitDispatcherTrait,
};

// Test constants
const ADMIN: felt252 = 'admin';
const MEMBER1: felt252 = 'member1';
const MEMBER2: felt252 = 'member2';
const MEMBER3: felt252 = 'member3';
const NON_MEMBER: felt252 = 'non_member';
const CONTRIBUTION_AMOUNT: u256 = 100;
const DEADLINE: u64 = 1000;
const NAME: felt252 = 'StarkRemit Token';
const SYMBOL: felt252 = 'SRT';
const INITIAL_SUPPLY: u256 = 1000000000000000000000000; // 1,000,000 tokens with 18 decimals
const BASE_CURRENCY: felt252 = 'USD';
const MAX_SUPPLY: u256 = 1_000_000_000 * 10_u256.pow(18); // 1B tokens with 18 decimals

// Helper function to create a contract address
fn address(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}
fn setup() -> (ContractAddress, ContractAddress) {
    let admin_address: ContractAddress = address(ADMIN);
    let oracle_address: ContractAddress = address('oracle');

    let declare_result = declare("StarkRemit");
    assert(declare_result.is_ok(), 'Contract declaration failed');

    let contract_class = declare_result.unwrap().contract_class();

    let mut calldata = ArrayTrait::new();
    calldata.append(admin_address.into());
    calldata.append(NAME);
    calldata.append(SYMBOL);
    calldata.append(INITIAL_SUPPLY.low.into());
    calldata.append(INITIAL_SUPPLY.high.into());
    calldata.append(MAX_SUPPLY.low.into());
    calldata.append(MAX_SUPPLY.high.into());
    calldata.append(BASE_CURRENCY);
    calldata.append(oracle_address.into());

    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();

    (contract_address, admin_address)
}


#[test]
fn test_add_member() {
    // Setup
    let (contract_address, admin_address) = setup();
    let contract = IStarkRemitDispatcher { contract_address };

    start_cheat_caller_address(contract_address, admin_address);

    contract.add_member(address(MEMBER1));

    assert(contract.is_member(address(MEMBER1)), 'Member1 should be a member');

    contract.add_member(address(MEMBER2));
    assert(contract.is_member(address(MEMBER2)), 'Member2 should be a member');

    assert(!contract.is_member(address(NON_MEMBER)), 'Non-member can not be a member');

    stop_cheat_caller_address(contract_address);
}

// Separate test for the duplicate member case that should panic
#[test]
#[should_panic(expected: ('Already a member',))]
fn test_add_duplicate_member() {
    let (contract_address, admin_address) = setup();
    let contract = IStarkRemitDispatcher { contract_address };

    start_cheat_caller_address(contract_address, admin_address);

    contract.add_member(address(MEMBER1));

    contract.add_member(address(MEMBER1));

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_contribute_round() {
    let (contract_address, admin_address) = setup();
    let contract = IStarkRemitDispatcher { contract_address };

    start_cheat_caller_address(contract_address, admin_address);

    contract.add_member(address(MEMBER1));
    contract.add_member(address(MEMBER2));

    let current_time = get_block_timestamp();
    let round_deadline = current_time + DEADLINE;
    let recipient = address(MEMBER1);
    contract.add_round_to_schedule(recipient, round_deadline);

    start_cheat_caller_address(contract_address, address(MEMBER1));

    let round_id: u256 = 0;
    contract.contribute_round(round_id, CONTRIBUTION_AMOUNT);

    start_cheat_caller_address(contract_address, address(MEMBER2));
    contract.contribute_round(round_id, CONTRIBUTION_AMOUNT);

    stop_cheat_caller_address(contract_address);
}

// Separate test for the non-member contribution case that should panic
#[test]
#[should_panic(expected: ('Caller is not a member',))]
fn test_non_member_contribution() {
    let (contract_address, admin_address) = setup();
    let contract = IStarkRemitDispatcher { contract_address };

    start_cheat_caller_address(contract_address, admin_address);
    contract.add_member(address(MEMBER1));

    let current_time = get_block_timestamp();
    let round_deadline = current_time + DEADLINE;
    let recipient = address(MEMBER1);
    contract.add_round_to_schedule(recipient, round_deadline);

    start_cheat_caller_address(contract_address, address(NON_MEMBER));

    contract.contribute_round(0, CONTRIBUTION_AMOUNT);

    stop_cheat_caller_address(contract_address);
}

