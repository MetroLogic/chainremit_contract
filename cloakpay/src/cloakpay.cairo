use crate::interfaces::ICloakPay::ICloakPay;

#[starknet::contract]
pub mod cloakpay {
    use super::*;
    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[constructor]
    fn constructor(ref self: ContractState) {}


    #[abi(embed_v0)]
    impl CloakPayImpl of ICloakPay<ContractState> {}

    #[generate_trait]
    impl Internal of InternalTrait {}
}
