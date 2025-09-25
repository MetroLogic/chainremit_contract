pub mod CloakPayErrors {
    pub const UNSUPPORTED_TOKEN: felt252 = 'UNSUPPORTED TOKEN';
    pub const COMMITMENT_ALREADY_USED: felt252 = 'COMMITMENT ALREADY USED';
}

pub mod payment_errors {
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'Insufficient token allowance';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient token balance';
}
