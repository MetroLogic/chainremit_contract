use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
use starkremit_contract::base::types::{KycLevel, KycStatus};
use starkremit_contract::interfaces::IStarkRemit::{
    IStarkRemitDispatcher, IStarkRemitDispatcherTrait,
};

const ADMIN_ADDRESS: felt252 = 0x123;
const USER_ADDRESS: felt252 = 0x456;
const ORACLE_ADDRESS: felt252 = 0x789;
const VERIFICATION_HASH: felt252 = 0xABC;
const MAX_SUPPLY: u256 = 1_000_000_000_u256 * 1_000_000_000_000_000_000_u256; // 1B tokens with 18 decimals

fn deploy_starkremit_contract() -> IStarkRemitDispatcher {
    let contract = declare("StarkRemit").unwrap().contract_class();
    let admin: ContractAddress = contract_address_const::<'admin'>();
    let oracle: ContractAddress = contract_address_const::<'oracle'>();

    let mut calldata: Array<felt252> = array![];
    admin.serialize(ref calldata);
    'StarkRemit'.serialize(ref calldata);
    'SRM'.serialize(ref calldata);
    1000000_u256.serialize(ref calldata);
    MAX_SUPPLY.serialize(ref calldata);
    'USD'.serialize(ref calldata);
    oracle.serialize(ref calldata);

    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    IStarkRemitDispatcher { contract_address }
}

#[test]
fn test_kyc_enforcement_toggle() {
    let contract = deploy_starkremit_contract();
    let admin: ContractAddress = contract_address_const::<'admin'>();

    start_cheat_caller_address(contract.contract_address, admin);

    // Initially KYC enforcement should be disabled
    assert(!contract.is_kyc_enforcement_enabled(), 'KYC disabled initially');

    // Enable KYC enforcement
    let success = contract.set_kyc_enforcement(true);
    assert(success, 'Failed to enable KYC');
    assert(contract.is_kyc_enforcement_enabled(), 'KYC should be enabled');

    // Disable KYC enforcement
    let success = contract.set_kyc_enforcement(false);
    assert(success, 'Failed to disable KYC');
    assert(!contract.is_kyc_enforcement_enabled(), 'KYC should be disabled');
}

#[test]
fn test_kyc_status_update() {
    let contract = deploy_starkremit_contract();
    let admin: ContractAddress = contract_address_const::<'admin'>();
    let user: ContractAddress = contract_address_const::<'user'>();

    start_cheat_caller_address(contract.contract_address, admin);

    let expires_at = get_block_timestamp() + 86400; // 24 hours

    // Update KYC status
    let success = contract
        .update_kyc_status(
            user, KycStatus::Approved, KycLevel::Basic, 'sample_id_857493', expires_at,
        );
    assert(success, 'KYC status update failed');

    // Verify KYC status
    let (status, level) = contract.get_kyc_status(user);
    assert(status == KycStatus::Approved, 'Status should be Approved');
    assert(level == KycLevel::Basic, 'Level should be Basic');

    // Verify KYC is valid
    assert(contract.is_kyc_valid(user), 'KYC should be valid');
}

#[test]
fn test_kyc_suspension_and_reinstatement() {
    let contract = deploy_starkremit_contract();
    let admin: ContractAddress = contract_address_const::<'admin'>();
    let user: ContractAddress = contract_address_const::<'user'>();

    start_cheat_caller_address(contract.contract_address, admin);

    // First approve the user
    contract
        .update_kyc_status(
            user,
            KycStatus::Approved,
            KycLevel::Basic,
            'sample_id_857493',
            get_block_timestamp() + 86400,
        );

    assert(contract.is_kyc_valid(user), 'KYC should be valid initially');

    // Suspend user KYC
    let success = contract.suspend_user_kyc(user);
    assert(success, 'KYC suspension failed');

    let (status, _level) = contract.get_kyc_status(user);
    assert(status == KycStatus::Suspended, 'Status should be Suspended');
    assert(!contract.is_kyc_valid(user), 'KYC should be invalid');

    // Reinstate user KYC
    let success = contract.reinstate_user_kyc(user);
    assert(success, 'KYC reinstatement failed');

    let (status, _level) = contract.get_kyc_status(user);
    assert(status == KycStatus::Approved, 'Status should be Approved');
    assert(contract.is_kyc_valid(user), 'KYC should be valid again');
}

#[test]
fn test_kyc_expiration() {
    let contract = deploy_starkremit_contract();
    let admin: ContractAddress = contract_address_const::<'admin'>();
    let user: ContractAddress = contract_address_const::<'user'>();

    start_cheat_caller_address(contract.contract_address, admin);

    let expires_at = get_block_timestamp() + 100; // Expires in 100 seconds

    // Update KYC status with expiration
    contract
        .update_kyc_status(
            user, KycStatus::Approved, KycLevel::Basic, 'sample_id_857493', expires_at,
        );

    // Verify KYC is initially valid
    assert(contract.is_kyc_valid(user), 'KYC should be valid initially');

    // Fast forward time beyond expiration
    start_cheat_block_timestamp(contract.contract_address, expires_at + 1);

    // Verify KYC has expired
    let (status, _level) = contract.get_kyc_status(user);
    assert(status == KycStatus::Expired, 'Status should be Expired');
    assert(!contract.is_kyc_valid(user), 'KYC should be invalid');
}
