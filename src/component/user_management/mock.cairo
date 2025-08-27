use openzeppelin::access::ownable::OwnableComponent;
use starknet::ContractAddress;

#[starknet::contract]
pub mod MockUserManagementContract {
    use starkremit_contract::component::user_management::user_management::user_management_component;
    use super::*;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(
        path: user_management_component,
        storage: user_management_component,
        event: UserManagementEvent,
    );

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl UserManagementImpl =
        user_management_component::UserManagement<ContractState>;
    impl UserManagementInternalImpl = user_management_component::InternalImpl<ContractState>;


    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UserManagementEvent: user_management_component::Event,
    }

    #[storage]
    #[allow(starknet::colliding_storage_paths)]
    struct Storage {
        #[substorage(v0)]
        user_management_component: user_management_component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
        self.user_management_component.initializer();
    }
}
