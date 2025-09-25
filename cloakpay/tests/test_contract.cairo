use cloakpay::base::events::Events::DepositEvent;
use cloakpay::cloakpay::cloakpay::Event as cloakpayEvent;
use cloakpay::interfaces::ICloakpay::ICloakPayDispatcherTrait;
use openzeppelin::token::erc20::interface::IERC20DispatcherTrait;
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_block_timestamp_global,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use crate::test_utils::{deploy_cloakpay, owner, test_address_1, to_18_decimals};

#[test]
fn test_create_deposit_successful() {
    let (cloakpay_dispatcher, token_dispatcher) = deploy_cloakpay();

    let mut spy = spy_events();

    let token_address = token_dispatcher.contract_address;

    let cloakpay_address = cloakpay_dispatcher.contract_address;

    start_cheat_caller_address(token_address, owner);

    token_dispatcher.transfer(test_address_1, to_18_decimals(50));

    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(token_address, test_address_1);

    token_dispatcher.approve(cloakpay_address, to_18_decimals(50));

    stop_cheat_caller_address(token_address);

    // cheat timer
    start_cheat_block_timestamp_global(12987);

    start_cheat_caller_address(cloakpay_address, test_address_1);

    cloakpay_dispatcher.deposit(1, to_18_decimals(50), 1443);

    stop_cheat_caller_address(token_address);

    // assert token was sent to us and token was removed form them
    let cloakpay_balance = token_dispatcher.balance_of(cloakpay_address);

    let user_balance = token_dispatcher.balance_of(test_address_1);

    assert!(cloakpay_balance == to_18_decimals(50), "cloakpay balance incorrect");

    assert!(user_balance == 0_u256, "user balance incorrect");

    // assert deposit id and details weer stored
    let deposit_details = cloakpay_dispatcher.get_deposit_details(1);

    assert!(deposit_details.amount == to_18_decimals(50), "deposit amount incorrect");

    assert!(deposit_details.commitment == 1443, "deposit commitment incorrect");

    assert!(deposit_details.supported_token == token_address, "deposit supported token incorrect");

    assert!(deposit_details.time_sent == 12987, "deposit time sent incorrect");

    // assert commitment was marked as used
    let commitment_used = cloakpay_dispatcher.get_commitment_used_status(1443);

    assert!(commitment_used, "commitment used status incorrect");

    // assert total deposits incremented
    let total_deposits = cloakpay_dispatcher.get_total_deposits();

    assert!(total_deposits == 1_u256, "total deposits incorrect");

    // assert commitment to id was written
    let deposit_id = cloakpay_dispatcher.get_deposit_id_from_commitment(1443);

    assert!(deposit_id == 1_u256, "deposit id from commitment incorrect");

    println!("All assertions passed {:?}", deposit_details);

    // assert event was emmitted
    let expected_event = cloakpayEvent::DepositEvent(
        DepositEvent { deposit_id: 1_u256, details: deposit_details },
    );

    spy.assert_emitted(@array![(cloakpay_address, expected_event)]);
}


#[test]
#[should_panic(expected: 'COMMITMENT ALREADY USED')]
fn test_create_deposit_should_panic_if_commitment_already_used() {
    let (cloakpay_dispatcher, token_dispatcher) = deploy_cloakpay();

    let token_address = token_dispatcher.contract_address;

    let cloakpay_address = cloakpay_dispatcher.contract_address;

    start_cheat_caller_address(token_address, owner);

    token_dispatcher.transfer(test_address_1, to_18_decimals(50));

    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(token_address, test_address_1);

    token_dispatcher.approve(cloakpay_address, to_18_decimals(50));

    stop_cheat_caller_address(token_address);

    // cheat timer
    start_cheat_block_timestamp_global(12987);

    start_cheat_caller_address(cloakpay_address, test_address_1);

    cloakpay_dispatcher.deposit(1, to_18_decimals(25), 1443);

    cloakpay_dispatcher.deposit(1, to_18_decimals(25), 1443);
}


#[test]
#[should_panic(expected: 'UNSUPPORTED TOKEN')]
fn test_create_deposit_should_panic_if_unsupported_token() {
    let (cloakpay_dispatcher, token_dispatcher) = deploy_cloakpay();

    let token_address = token_dispatcher.contract_address;

    let cloakpay_address = cloakpay_dispatcher.contract_address;

    start_cheat_caller_address(token_address, owner);

    token_dispatcher.transfer(test_address_1, to_18_decimals(50));

    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(token_address, test_address_1);

    token_dispatcher.approve(cloakpay_address, to_18_decimals(50));

    stop_cheat_caller_address(token_address);

    // cheat timer
    start_cheat_block_timestamp_global(12987);

    start_cheat_caller_address(cloakpay_address, test_address_1);

    cloakpay_dispatcher.deposit(4, to_18_decimals(25), 1443);
}
