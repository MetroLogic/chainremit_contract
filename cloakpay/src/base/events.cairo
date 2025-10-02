use starknet::ContractAddress;
use crate::base::types::DepositDetails;

pub mod Events {
    use super::*;
    #[derive(Drop, starknet::Event)]
    pub struct DepositEvent {
        #[key]
        pub deposit_id: u256,
        pub details: DepositDetails,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenAdded {
        pub token_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenRemoved {
        pub token_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Paused {
        pub account: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Unpaused {
        pub account: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct NullifierUsed {
        pub nullifier_hash: felt252,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VerifierUpdated {
        pub old_verifier: ContractAddress,
        pub new_verifier: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DenominationAdded {
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DenominationRemoved {
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalEvent {
        pub nullifier_hash: felt252,
        pub recipient: ContractAddress,
        pub relayer: ContractAddress,
        pub amount: u256,
        pub fee: u256,
        pub token: ContractAddress,
        pub timestamp: u64,
    }
}
