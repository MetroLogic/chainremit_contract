use starknet::ContractAddress;
#[starknet::interface]
pub trait ITokenManagement<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, owner: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, to: ContractAddress, value: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, value: u256) -> bool;
    fn transfer_from(ref self: TContractState, from: ContractAddress, to: ContractAddress, value: u256) -> bool;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256) -> bool;
    fn add_minter(ref self: TContractState, minter: ContractAddress) -> bool;
    fn remove_minter(ref self: TContractState, minter: ContractAddress) -> bool;
    fn set_max_supply(ref self: TContractState, new_max_supply: u256) -> bool;
}

#[starknet::component]
pub mod token_management_component {
    use super::*;
    use starknet::{get_caller_address, ContractAddress};
    use starkremit_contract::base::errors::MintBurnErrors;
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, Map, StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
        max_supply: u256,
        minters: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
        Minted: Minted,
        Burned: Burned,
        MinterAdded: MinterAdded,
        MinterRemoved: MinterRemoved,
        MaxSupplyUpdated: MaxSupplyUpdated,
    }
    #[derive(Drop, starknet::Event)]
    pub struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256,
    }
    #[derive(Drop, starknet::Event)]
    pub struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    }
    #[derive(Drop, starknet::Event)]
    pub struct Minted {
        to: ContractAddress,
        amount: u256,
    }
    #[derive(Drop, starknet::Event)]
    pub struct Burned {
        from: ContractAddress,
        amount: u256,
    }
    #[derive(Drop, starknet::Event)]
    pub struct MinterAdded {
        minter: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    pub struct MinterRemoved {
        minter: ContractAddress,
    }
    #[derive(Drop, starknet::Event)]
    pub struct MaxSupplyUpdated {
        new_max_supply: u256,
    }

    #[embeddable_as(TokenManagement)]
    impl TokenManagementImpl<
        TContractState, +HasComponent<TContractState>,
    > of ITokenManagement<ComponentState<TContractState>> {
        fn name(self: @ComponentState<TContractState>) -> felt252 {
            self.name.read()
        }
        fn symbol(self: @ComponentState<TContractState>) -> felt252 {
            self.symbol.read()
        }
        fn decimals(self: @ComponentState<TContractState>) -> u8 {
            self.decimals.read()
        }
        fn total_supply(self: @ComponentState<TContractState>) -> u256 {
            self.total_supply.read()
        }
        fn balance_of(self: @ComponentState<TContractState>, owner: ContractAddress) -> u256 {
            self.balances.read(owner)
        }
        fn transfer(ref self: ComponentState<TContractState>, to: ContractAddress, value: u256) -> bool {
            let caller = get_caller_address();
            let from_balance = self.balances.read(caller);
            assert(from_balance >= value, MintBurnErrors::INSUFFICIENT_BALANCE_BURN);
            self.balances.write(caller, from_balance - value);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + value);
            self.emit(Event::Transfer(Transfer { from: caller, to, value }));
            true
        }
        fn approve(ref self: ComponentState<TContractState>, spender: ContractAddress, value: u256) -> bool {
            let caller = get_caller_address();
            self.allowances.write((caller, spender), value);
            self.emit(Event::Approval(Approval { owner: caller, spender, value }));
            true
        }
        fn transfer_from(ref self: ComponentState<TContractState>, from: ContractAddress, to: ContractAddress, value: u256) -> bool {
            let caller = get_caller_address();
            let allowance = self.allowances.read((from, caller));
            assert(allowance >= value, MintBurnErrors::INSUFFICIENT_BALANCE_BURN);
            let from_balance = self.balances.read(from);
            assert(from_balance >= value, MintBurnErrors::INSUFFICIENT_BALANCE_BURN);
            self.allowances.write((from, caller), allowance - value);
            self.balances.write(from, from_balance - value);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + value);
            self.emit(Event::Transfer(Transfer { from, to, value }));
            true
        }
        fn allowance(self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress) -> u256 {
            self.allowances.read((owner, spender))
        }
        fn mint(ref self: ComponentState<TContractState>, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            assert(self.minters.read(caller), MintBurnErrors::NOT_MINTER);
            let supply = self.total_supply.read();
            let max_supply = self.max_supply.read();
            assert(supply + amount <= max_supply, MintBurnErrors::MAX_SUPPLY_EXCEEDED);
            self.total_supply.write(supply + amount);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);
            self.emit(Event::Minted(Minted { to, amount }));
            true
        }
        fn burn(ref self: ComponentState<TContractState>, from: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            assert(self.minters.read(caller), MintBurnErrors::NOT_MINTER);
            let from_balance = self.balances.read(from);
            assert(from_balance >= amount, MintBurnErrors::INSUFFICIENT_BALANCE_BURN);
            self.balances.write(from, from_balance - amount);
            let supply = self.total_supply.read();
            self.total_supply.write(supply - amount);
            self.emit(Event::Burned(Burned { from, amount }));
            true
        }
        fn add_minter(ref self: ComponentState<TContractState>, minter: ContractAddress) -> bool {
            let caller = get_caller_address();
            assert(self.minters.read(caller), MintBurnErrors::NOT_MINTER);
            self.minters.write(minter, true);
            self.emit(Event::MinterAdded(MinterAdded { minter }));
            true
        }
        fn remove_minter(ref self: ComponentState<TContractState>, minter: ContractAddress) -> bool {
            let caller = get_caller_address();
            assert(self.minters.read(caller), MintBurnErrors::NOT_MINTER);
            self.minters.write(minter, false);
            self.emit(Event::MinterRemoved(MinterRemoved { minter }));
            true
        }
        fn set_max_supply(ref self: ComponentState<TContractState>, new_max_supply: u256) -> bool {
            let caller = get_caller_address();
            assert(self.minters.read(caller), MintBurnErrors::NOT_MINTER);
            self.max_supply.write(new_max_supply);
            self.emit(Event::MaxSupplyUpdated(MaxSupplyUpdated { new_max_supply }));
            true
        }
    }
}
