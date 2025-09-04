use starknet::ContractAddress;

#[starknet::contract]
pub mod MockTokenMGTContract {
    use starkremit_contract::component::token_management::token_management::token_management_component;
    use super::*;

    component!(
        path: token_management_component,
        storage: token_management_component,
        event: TokenManagementEvent,
    );


    #[abi(embed_v0)]
    impl TokenManagementImpl =
        token_management_component::TokenManagement<ContractState>;
    impl TokenManagementInternalImpl = token_management_component::InternalImpl<ContractState>;


    // Event definitions
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        TokenManagementEvent: token_management_component::Event,
    }

    // Contract storage definition
    #[storage]
    #[allow(starknet::colliding_storage_paths)]
    struct Storage {
        #[substorage(v0)]
        token_management_component: token_management_component::Storage,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, name: felt252, symbol: felt252, owner: ContractAddress,
    ) {
        self.token_management_component.initializer(name, symbol, owner);
    }
}
