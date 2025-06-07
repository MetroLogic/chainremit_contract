use core::array::ArrayTrait;
use core::num::traits::Pow;
use core::result::ResultTrait;
use core::traits::TryInto;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp, get_contract_address};

use starkremit_contract::base::types::{ // Agent, AgentStatus, KYCLevel, KycLevel, KycStatus, LoanRequest,
    LoanStatus, RegistrationRequest // RegistrationStatus, SavingsGroup, Transfer as TransferData,
    // TransferHistory, TransferStatus, UserKycData, UserProfile,
};
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
fn test_loan_request() {
    // Setup
    let (contract_address, admin_address) = setup();
    let contract = IStarkRemitDispatcher { contract_address };
    println!("Contract Address: {:?}", contract_address);
    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
        preferred_currency: BASE_CURRENCY,
        country_code: '32445',
    };
    println!("Caller name: {:?}", register_user);
    // Register a user
    let user = contract.register_user(register_user);
    assert(user, 'User registration failed');

    //requestLoan
    let loan_request = contract.requestLoan(caller, 400);
    // request id
    println!("id: {loan_request}");
    let loan_data = contract.getLoan(loan_request);
    assert(contract.get_loan_count() == 1, 'loan count should be 1');
    //assert that request status is pending
    println!("Loan request status: {:?}", loan_data);
    assert(loan_data.status == LoanStatus::Pending, 'loan request is not pending');

    stop_cheat_caller_address(contract_address);
}
#[test]
#[should_panic(expected: ('loan amount is zero',))]
fn test_loan_request_zero_amount() {
    // Setup
    let (contract_address, admin_address) = setup();
    let contract = IStarkRemitDispatcher { contract_address };
    println!("Contract Address: {:?}", contract_address);
    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
        preferred_currency: BASE_CURRENCY,
        country_code: '32445',
    };
    println!("Caller name: {:?}", register_user);
    // Register a user
    let user = contract.register_user(register_user);
    assert(user, 'User registration failed');

    //requestLoan with zero amount
    // This should panic as the loan amount is zero
    contract.requestLoan(caller, 0);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_approve_loan_request() {
    // Setup
    let (contract_address, admin_address) = setup();
    let contract = IStarkRemitDispatcher { contract_address };

    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
        preferred_currency: BASE_CURRENCY,
        country_code: '32445',
    };
    // Register a user
    let user = contract.register_user(register_user);
    assert(user, 'User registration failed');

    //requestLoan
    let loan_request = contract.requestLoan(caller, 400);
    // request id
    let loan_data = contract.getLoan(loan_request);
    // assert that request status is pending
    assert(loan_data.status == LoanStatus::Pending, 'loan request is not pending');
    assert(contract.get_loan_count() == 1, 'loan count should be 1');
    contract.approveLoan(loan_request);
    let loan_data = contract.getLoan(loan_request);
    // assert that request status is approved
    assert(loan_data.status == LoanStatus::Approved, 'loan request is not pending');

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expected: ('User already has an active loan',))]
fn test_active_loan_loan_request() {
    // Setup
    let (contract_address, admin_address) = setup();
    let contract = IStarkRemitDispatcher { contract_address };

    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
        preferred_currency: BASE_CURRENCY,
        country_code: '32445',
    };
    // Register a user
    let user = contract.register_user(register_user);
    assert(user, 'User registration failed');

    //requestLoan
    let loan_request = contract.requestLoan(caller, 400);
    // request id
    let loan_data = contract.getLoan(loan_request);
    // assert that request status is pending
    assert(loan_data.status == LoanStatus::Pending, 'loan request is not pending');
    assert(contract.get_loan_count() == 1, 'loan count should be 1');
    contract.approveLoan(loan_request);
    let loan_data = contract.getLoan(loan_request);
    // assert that request status is approved
    assert(loan_data.status == LoanStatus::Approved, 'loan request is not pending');

    stop_cheat_caller_address(contract_address);
    contract.requestLoan(caller, 700);
}

#[test]
#[should_panic(expected: ('has pending loan request',))]
fn test_loan_request_with_active_loan() {
    // Setup
    let (contract_address, admin_address) = setup();
    let contract = IStarkRemitDispatcher { contract_address };
    println!("Contract Address: {:?}", contract_address);
    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
        preferred_currency: BASE_CURRENCY,
        country_code: '32445',
    };
    println!("Caller name: {:?}", register_user);
    // Register a user
    let user = contract.register_user(register_user);
    assert(user, 'User registration failed');

    //requestLoan
    let loan_request = contract.requestLoan(caller, 400);
    contract.requestLoan(caller, 400);

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_reject_loan_request() {
    // Setup
    let (contract_address, admin_address) = setup();
    let contract = IStarkRemitDispatcher { contract_address };

    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
        preferred_currency: BASE_CURRENCY,
        country_code: '32445',
    };
    // Register a user
    let user = contract.register_user(register_user);
    assert(user, 'User registration failed');

    //requestLoan
    let loan_request = contract.requestLoan(caller, 400);
    // request id
    let loan_data = contract.getLoan(loan_request);
    // assert that request status is pending
    assert(loan_data.status == LoanStatus::Pending, 'loan request is not pending');
    assert(contract.get_loan_count() == 1, 'loan count should be 1');

    contract.rejectLoan(loan_request);
    let loan_data = contract.getLoan(loan_request);
    // assert that request status is rejected
    assert(loan_data.status == LoanStatus::Reject, 'loan request is not rejected');

    stop_cheat_caller_address(contract_address);
}
