use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum KycLevel {
    #[default]
    None,
    Basic,
    Enhanced,
    Premium,
}

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
pub enum KycStatus {
    #[default]
    Pending,
    Approved,
    Rejected,
    Expired,
    Suspended,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct UserKycData {
    pub user: ContractAddress,
    pub level: KycLevel,
    pub status: KycStatus,
    pub verification_hash: felt252,
    pub verified_at: u64,
    pub expires_at: u64,
}

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct TransactionLimits {
    pub daily_limit: u256,
    pub single_tx_limit: u256,
}
