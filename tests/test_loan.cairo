// // Test constants
const ADMIN: felt252 = 'admin';
use core::result::ResultTrait;

// OZ imports
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// snforge imports
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_block_timestamp, start_cheat_caller_address, start_cheat_caller_address_global,
    stop_cheat_caller_address, stop_cheat_caller_address_global,
};

// starknet imports
use starknet::{ContractAddress, contract_address_const, get_contract_address};

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
    // let admin_address: ContractAddress = address(ADMIN);
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

#[test]
fn test_loan_request() {
    // Setup
    let (contract_address, contract, _) = __setup__();
    let admin_address = USER();
    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    // register user struct
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
        country_code: '32445',
    };

    // Register a user
    let user = contract.register_user(register_user);
    assert(user, 'User registration failed');

    //requestLoan
    let loan_request = contract.requestLoan(caller, 400);
    // request id
    let loan_data = contract.getLoan(loan_request);
    assert(contract.get_loan_count() == 1, 'loan count should be 1');
    //assert that request status is pending
    assert(loan_data.status == LoanStatus::Pending, 'loan request is not pending');

    stop_cheat_caller_address(contract_address);
}
#[test]
#[should_panic(expected: ('loan amount is zero',))]
fn test_loan_request_zero_amount() {
    // Setup
    let (contract_address, contract, _) = __setup__();
    let admin_address = USER();
    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    // new user struct
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
        country_code: '32445',
    };

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
    let (contract_address, contract, _) = __setup__();
    let admin_address = USER();
    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    // register new user struct
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
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
    stop_cheat_caller_address(contract_address);
    let owner = OWNER();
    start_cheat_caller_address(contract_address, owner);
    contract.approveLoan(loan_request);
    let loan_data = contract.getLoan(loan_request);
    // assert that request status is approved
    assert(loan_data.status == LoanStatus::Approved, 'loan request is not pending');

    stop_cheat_caller_address(owner);
}

#[test]
#[should_panic(expected: ('User already has an active loan',))]
fn test_active_loan_request() {
    // Setup
    let (contract_address, contract, _) = __setup__();
    let admin_address = USER();
    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
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
    stop_cheat_caller_address(contract_address);
    let owner = OWNER();
    start_cheat_caller_address(contract_address, owner);
    contract.approveLoan(loan_request);
    let loan_data = contract.getLoan(loan_request);
    // assert that request status is approved
    assert(loan_data.status == LoanStatus::Approved, 'loan request is not pending');

    contract.requestLoan(caller, 700);
    stop_cheat_caller_address(owner);
}

#[test]
#[should_panic(expected: ('has pending loan request',))]
fn test_loan_request_with_active_loan() {
    // Setup
    let (contract_address, contract, _) = __setup__();
    let admin_address = USER();
    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
        country_code: '32445',
    };

    // Register a user
    let user = contract.register_user(register_user);
    assert(user, 'User registration failed');

    //requestLoan
    //will panic user has a pending loan request
    contract.requestLoan(caller, 400);
    contract.requestLoan(caller, 400);

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_reject_loan_request() {
    // Setup
    let (contract_address, contract, _) = __setup__();
    let admin_address = USER();
    start_cheat_caller_address(contract_address, admin_address);
    let caller = get_contract_address();
    let register_user = RegistrationRequest {
        email_hash: 'kate@gmail.com',
        phone_hash: '4959398484845',
        full_name: 'kate michael',
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
    stop_cheat_caller_address(contract_address);

    let owner = OWNER();
    start_cheat_caller_address(contract_address, owner);
    // reject loan request
    contract.rejectLoan(loan_request);
    let loan_data = contract.getLoan(loan_request);
    // assert that request status is rejected
    assert(loan_data.status == LoanStatus::Reject, 'loan request is not rejected');

    stop_cheat_caller_address(owner);
}
