use starknet::ContractAddress;

#[starknet::interface]
pub trait ITokenManagement<TContractState> {
    // ERC20 Standard Functions
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, owner: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, to: ContractAddress, value: u256) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, value: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, value: u256,
    ) -> bool;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;

    // Minting and Burning Functions
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn burn(ref self: TContractState, from: ContractAddress, amount: u256) -> bool;

    // Owner Functions
    fn add_minter(ref self: TContractState, minter: ContractAddress) -> bool;
    fn remove_minter(ref self: TContractState, minter: ContractAddress) -> bool;
    fn set_max_supply(ref self: TContractState, new_max_supply: u256) -> bool;
    fn pause(ref self: TContractState) -> bool;
    fn unpause(ref self: TContractState) -> bool;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress) -> bool;

    // Getter Functions
    fn get_owner(self: @TContractState) -> ContractAddress;
    fn get_max_supply(self: @TContractState) -> u256;
    fn is_minter(self: @TContractState, address: ContractAddress) -> bool;
    fn is_paused(self: @TContractState) -> bool;
}

#[starknet::component]
pub mod token_management_component {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use starkremit_contract::base::errors::MintBurnErrors;
    use starkremit_contract::utils::helpers::{assert_non_zero_amount, assert_not_zero_address};
    use super::*;

    // Constant for unlimited allowance
    const UNLIMITED_ALLOWANCE: u256 =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    #[storage]
    pub struct Storage {
        // ERC20 Standard Fields
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
        // Token Management Fields
        max_supply: u256, // 0 = unlimited supply
        minters: Map<ContractAddress, bool>,
        // Access Control Fields
        owner: ContractAddress,
        paused: bool,
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
        OwnershipTransferred: OwnershipTransferred,
        Paused: Paused,
        Unpaused: Unpaused,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Transfer {
        #[key]
        pub from: ContractAddress,
        #[key]
        pub to: ContractAddress,
        pub value: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Approval {
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub spender: ContractAddress,
        pub value: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Minted {
        #[key]
        pub to: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Burned {
        #[key]
        pub from: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MinterAdded {
        #[key]
        pub minter: ContractAddress,
        #[key]
        pub added_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MinterRemoved {
        #[key]
        pub minter: ContractAddress,
        #[key]
        pub removed_by: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MaxSupplyUpdated {
        #[key]
        pub old_max_supply: u256,
        #[key]
        pub new_max_supply: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OwnershipTransferred {
        #[key]
        pub previous_owner: ContractAddress,
        #[key]
        pub new_owner: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Paused {
        #[key]
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Unpaused {
        #[key]
        pub account: ContractAddress,
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            name: felt252,
            symbol: felt252,
            owner: ContractAddress,
        ) {
            self.name.write(name);
            self.symbol.write(symbol);
            self.owner.write(owner);
        }

        fn _transfer(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) {
            let from_balance = self.balances.read(from);
            assert(from_balance >= value, MintBurnErrors::INSUFFICIENT_BALANCE_BURN);

            // Update balances
            self.balances.write(from, from_balance - value);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + value);

            // Emit transfer event
            self.emit(Event::Transfer(Transfer { from, to, value }));
        }

        fn _assert_only_owner(self: @ComponentState<TContractState>) {
            let caller = get_caller_address();
            assert(caller == self.owner.read(), MintBurnErrors::NOT_OWNER);
        }

        fn _assert_not_paused(self: @ComponentState<TContractState>) {
            assert(!self.paused.read(), MintBurnErrors::CONTRACT_PAUSED);
        }

        fn _assert_only_minter(self: @ComponentState<TContractState>) {
            let caller = get_caller_address();
            assert(self.minters.read(caller), MintBurnErrors::NOT_MINTER);
        }
    }

    #[embeddable_as(TokenManagement)]
    impl TokenManagementImpl<
        TContractState, +HasComponent<TContractState>,
    > of ITokenManagement<ComponentState<TContractState>> {
        // ERC20 Standard Functions

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

        fn transfer(
            ref self: ComponentState<TContractState>, to: ContractAddress, value: u256,
        ) -> bool {
            // Check if contract is paused
            self._assert_not_paused();

            // Validate parameters
            assert_not_zero_address(to);
            assert_non_zero_amount(value);

            let caller = get_caller_address();

            // Use internal _transfer function (no duplicate logic)
            self._transfer(caller, to, value);
            true
        }

        fn approve(
            ref self: ComponentState<TContractState>, spender: ContractAddress, value: u256,
        ) -> bool {
            // Check if contract is paused
            self._assert_not_paused();

            // Validate parameters
            assert_not_zero_address(spender);

            let caller = get_caller_address();
            self.allowances.write((caller, spender), value);
            self.emit(Event::Approval(Approval { owner: caller, spender, value }));
            true
        }

        fn transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            value: u256,
        ) -> bool {
            // Check if contract is paused
            self._assert_not_paused();

            // Validate parameters
            assert_not_zero_address(from);
            assert_not_zero_address(to);
            assert_non_zero_amount(value);

            let caller = get_caller_address();
            let allowance = self.allowances.read((from, caller));

            // Check allowance (skip for unlimited allowance)
            if allowance != UNLIMITED_ALLOWANCE {
                assert(allowance >= value, MintBurnErrors::INSUFFICIENT_ALLOWANCE);
                // Update allowance
                self.allowances.write((from, caller), allowance - value);
            }

            // Perform transfer using internal function
            self._transfer(from, to, value);
            true
        }

        fn allowance(
            self: @ComponentState<TContractState>, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        // Minting and Burning Functions

        fn mint(
            ref self: ComponentState<TContractState>, to: ContractAddress, amount: u256,
        ) -> bool {
            // Check if contract is paused
            self._assert_not_paused();

            // Validate parameters
            assert_not_zero_address(to);
            assert_non_zero_amount(amount);

            // Check minter permission
            self._assert_only_minter();

            let supply = self.total_supply.read();
            let max_supply = self.max_supply.read();

            // Check max supply (0 means unlimited)
            if max_supply != 0 {
                assert(supply + amount <= max_supply, MintBurnErrors::MAX_SUPPLY_EXCEEDED);
            }

            // Update total supply
            self.total_supply.write(supply + amount);

            // Update balance
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);

            // Emit events
            self.emit(Event::Minted(Minted { to, amount }));
            self
                .emit(
                    Event::Transfer(
                        Transfer {
                            from: starknet::contract_address_const::<'0x0'>(), to, value: amount,
                        },
                    ),
                );

            true
        }

        fn burn(
            ref self: ComponentState<TContractState>, from: ContractAddress, amount: u256,
        ) -> bool {
            // Check if contract is paused
            self._assert_not_paused();

            // Validate parameters
            assert_not_zero_address(from);
            assert_non_zero_amount(amount);

            // Check minter permission
            self._assert_only_minter();

            let from_balance = self.balances.read(from);
            assert(from_balance >= amount, MintBurnErrors::INSUFFICIENT_BALANCE_BURN);

            // Update balance
            self.balances.write(from, from_balance - amount);

            // Update total supply
            let supply = self.total_supply.read();
            self.total_supply.write(supply - amount);

            // Emit events
            self.emit(Event::Burned(Burned { from, amount }));
            self
                .emit(
                    Event::Transfer(
                        Transfer {
                            from, to: starknet::contract_address_const::<'0x0'>(), value: amount,
                        },
                    ),
                );

            true
        }

        // Owner Functions

        fn add_minter(ref self: ComponentState<TContractState>, minter: ContractAddress) -> bool {
            self._assert_only_owner();
            assert_not_zero_address(minter);

            let caller = get_caller_address();
            self.minters.write(minter, true);
            self.emit(Event::MinterAdded(MinterAdded { minter, added_by: caller }));
            true
        }

        fn remove_minter(
            ref self: ComponentState<TContractState>, minter: ContractAddress,
        ) -> bool {
            self._assert_only_owner();
            assert_not_zero_address(minter);

            let caller = get_caller_address();
            self.minters.write(minter, false);
            self.emit(Event::MinterRemoved(MinterRemoved { minter, removed_by: caller }));
            true
        }

        fn set_max_supply(ref self: ComponentState<TContractState>, new_max_supply: u256) -> bool {
            self._assert_only_owner();

            let current_supply = self.total_supply.read();

            // If setting non-zero max supply, ensure it's >= current supply
            if new_max_supply != 0 {
                assert(new_max_supply >= current_supply, MintBurnErrors::MAX_SUPPLY_TOO_LOW);
            }

            let old_max_supply = self.max_supply.read();
            let caller = get_caller_address();
            self.max_supply.write(new_max_supply);

            self.emit(Event::MaxSupplyUpdated(MaxSupplyUpdated { old_max_supply, new_max_supply }));
            true
        }

        fn pause(ref self: ComponentState<TContractState>) -> bool {
            self._assert_only_owner();

            self.paused.write(true);
            let caller = get_caller_address();
            self.emit(Event::Paused(Paused { account: caller }));
            true
        }

        fn unpause(ref self: ComponentState<TContractState>) -> bool {
            self._assert_only_owner();

            self.paused.write(false);
            let caller = get_caller_address();
            self.emit(Event::Unpaused(Unpaused { account: caller }));
            true
        }

        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress,
        ) -> bool {
            self._assert_only_owner();
            assert_not_zero_address(new_owner);

            let previous_owner = self.owner.read();
            assert(previous_owner != new_owner, MintBurnErrors::OWNERSHIP_TO_SELF);

            self.owner.write(new_owner);

            self
                .emit(
                    Event::OwnershipTransferred(OwnershipTransferred { previous_owner, new_owner }),
                );
            true
        }

        // Getter Functions

        fn get_owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner.read()
        }

        fn get_max_supply(self: @ComponentState<TContractState>) -> u256 {
            self.max_supply.read()
        }

        fn is_minter(self: @ComponentState<TContractState>, address: ContractAddress) -> bool {
            self.minters.read(address)
        }

        fn is_paused(self: @ComponentState<TContractState>) -> bool {
            self.paused.read()
        }
    }
}

