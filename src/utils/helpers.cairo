use starknet::ContractAddress;

/// Check if an address is the zero address
pub fn is_zero_address(address: ContractAddress) -> bool {
    address == starknet::contract_address_const::<'0x0'>()
}

/// Check if an amount is greater than zero
pub fn is_non_zero_amount(amount: u256) -> bool {
    amount > u256 { low: 0, high: 0 }
}

/// Validate that an address is not zero
pub fn assert_not_zero_address(address: ContractAddress) {
    assert(!is_zero_address(address), 'Address cannot be zero');
}

/// Validate that an amount is greater than zero
pub fn assert_non_zero_amount(amount: u256) {
    assert(is_non_zero_amount(amount), 'Amount must be > 0');
}
