pub mod CloakPayErrors {
    pub const UNSUPPORTED_TOKEN: felt252 = 'UNSUPPORTED TOKEN';
    pub const COMMITMENT_ALREADY_USED: felt252 = 'COMMITMENT ALREADY USED';
    pub const ERROR_ZERO_ADDRESS: felt252 = 'ERROR ZERO ADDRESS';
    pub const NULLIFIER_ALREADY_USED: felt252 = 'NILLIFIER ALREADY USED';
    pub const INVALID_PROOF: felt252 = 'INVALID ZK PROOF';
    pub const INVALID_ROOT: felt252 = 'INVALID MERKEL ROOT';
    pub const INVALID_DENOMINATION: felt252 = 'INVALID DENOMINATION';
    pub const FEE_EXCEEDS_AMOUNT: felt252 = 'FEE EXCEEDS AMOUNT';
}

pub mod payment_errors {
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient token allowance';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient token balance';
}
