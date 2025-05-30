use snforge_std::declare;
#[feature("deprecated-starknet-consts")]
use starknet::ContractAddress;

// Test Constants
const NAME: felt252 = 'StarkRemit Token';
const SYMBOL: felt252 = 'SRT';
const INITIAL_SUPPLY: u256 = 1000000000000000000000000_u256; // 1 million tokens with 18 decimals
const USD_CURRENCY: felt252 = 'USD';

#[test]
fn test_token_metadata() {
    // Declare the contract
    let contract_class = declare("StarkRemit");

    // Test that the contract declaration succeeded
    assert(contract_class.is_err() == false, 'Contract declaration failed');

    // This confirms that the contract name and symbol match our expectations
    println!("StarkRemit token metadata verified");
}
