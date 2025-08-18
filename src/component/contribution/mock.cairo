use openzeppelin::access::ownable::OwnableComponent;
use starknet::ContractAddress;

#[starknet::contract]
pub mod MockContributionContract {
    use starkremit_contract::component::contribution::contribution::contribution_component;
    use super::*;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(
        path: contribution_component, storage: contribution_component, event: ContributionEvent,
    );

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ContributionImpl = contribution_component::Contribution<ContractState>;
    impl ContributionInternalImpl = contribution_component::InternalImpl<ContractState>;

    // Event definitions
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ContributionEvent: contribution_component::Event,
    }

    // Contract storage definition
    #[storage]
    #[allow(starknet::colliding_storage_paths)]
    struct Storage {
        #[substorage(v0)]
        contribution_component: contribution_component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    // Contract constructor
    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress, // Admin address
        token_address: ContractAddress // Address of the token contract
    ) {
        // initialize owner
        self.ownable.initializer(owner);

        self.contribution_component.initializer(token_address);
    }
}
