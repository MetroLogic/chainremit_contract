use starknet::ContractAddress;
/// @notice enum of supported tokens
#[derive(Copy, Drop, Serde, PartialEq, starknet::Store, Debug)]
pub enum SupportedToken {
    #[default]
    STRK,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store, Debug)]
pub struct DepositDetails {
    pub supported_token: ContractAddress,
    pub amount: u256,
    pub commitment: felt252,
    pub time_sent: u64,
}
