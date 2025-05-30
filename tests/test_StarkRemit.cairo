use snforge_std::declare;
#[feature("deprecated-starknet-consts")]
use starknet::ContractAddress;
use starkremit_contract::base::types::{KYCLevel, RegistrationRequest, RegistrationStatus};

// Test Constants
const NAME: felt252 = 'StarkRemit Token';
const SYMBOL: felt252 = 'SRT';
const INITIAL_SUPPLY: u256 = 1000000000000000000000000_u256; // 1 million tokens with 18 decimals
const USD_CURRENCY: felt252 = 'USD';

// User test data
const USER1_EMAIL_HASH: felt252 = 'user1_email_hash';
const USER1_PHONE_HASH: felt252 = 'user1_phone_hash';
const USER1_FULL_NAME: felt252 = 'John Doe';
const USER1_COUNTRY: felt252 = 'US';

const USER2_EMAIL_HASH: felt252 = 'user2_email_hash';
const USER2_PHONE_HASH: felt252 = 'user2_phone_hash';
const USER2_FULL_NAME: felt252 = 'Jane Smith';
const USER2_COUNTRY: felt252 = 'CA';

fn create_registration_request(
    email_hash: felt252, phone_hash: felt252, full_name: felt252, country_code: felt252,
) -> RegistrationRequest {
    RegistrationRequest {
        email_hash, phone_hash, full_name, preferred_currency: USD_CURRENCY, country_code,
    }
}

#[test]
fn test_contract_declaration() {
    // Declare the contract
    let contract_class = declare("StarkRemit");

    // Test that the contract declaration succeeded
    assert(contract_class.is_err() == false, 'Contract declaration failed');

    // This confirms that the contract compiles and can be deployed
    println!("StarkRemit contract declaration successful");
}

#[test]
fn test_registration_request_creation() {
    // Test creating a registration request
    let registration_data = create_registration_request(
        USER1_EMAIL_HASH, USER1_PHONE_HASH, USER1_FULL_NAME, USER1_COUNTRY,
    );

    // Verify the data is correctly set
    assert(registration_data.email_hash == USER1_EMAIL_HASH, 'Email hash match');
    assert(registration_data.phone_hash == USER1_PHONE_HASH, 'Phone hash match');
    assert(registration_data.full_name == USER1_FULL_NAME, 'Full name match');
    assert(registration_data.preferred_currency == USD_CURRENCY, 'Currency match');
    assert(registration_data.country_code == USER1_COUNTRY, 'Country match');
}

#[test]
fn test_kyc_level_enum() {
    // Test KYC level enum variants
    let none_level = KYCLevel::None;
    let basic_level = KYCLevel::Basic;
    let advanced_level = KYCLevel::Advanced;
    let full_level = KYCLevel::Full;

    // This test ensures the enum variants are properly defined
    println!("KYC level enum variants work correctly");
}

#[test]
fn test_registration_status_enum() {
    // Test registration status enum variants
    let not_started = RegistrationStatus::NotStarted;
    let in_progress = RegistrationStatus::InProgress;
    let completed = RegistrationStatus::Completed;
    let failed = RegistrationStatus::Failed;
    let suspended = RegistrationStatus::Suspended;

    // This test ensures the enum variants are properly defined
    println!("Registration status enum variants work correctly");
}
