use starknet::ContractAddress;

#[starknet::contract]
pub mod MockTransferContract {
    use starkremit_contract::component::transfer::transfer::transfer_component;
    use super::*;

    component!(path: transfer_component, storage: transfer_component, event: TransferEvent);

    #[abi(embed_v0)]
    impl TransferImpl = transfer_component::Transfer<ContractState>;

    // Event definitions
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        TransferEvent: transfer_component::Event,
    }

    // Contract storage definition
    #[storage]
    #[allow(starknet::colliding_storage_paths)]
    struct Storage {
        #[substorage(v0)]
        transfer_component: transfer_component::Storage,
    }

    // Contract constructor
    #[constructor]
    fn constructor(ref self: ContractState) { // No initialization needed for transfer component
    }
}
