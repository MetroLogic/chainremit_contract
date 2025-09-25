use crate::base::types::DepositDetails;

pub mod Events {
    use super::*;
    #[derive(Drop, starknet::Event)]
    pub struct DepositEvent {
        #[key]
        pub deposit_id: u256,
        pub details: DepositDetails,
    }
}
