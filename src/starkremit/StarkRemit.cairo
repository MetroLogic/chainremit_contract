#[feature("deprecated-starknet-consts")]
#[starknet::contract]
mod StarkRemit {
    use core::num::traits::Zero;
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use starkremit_contract::base::errors::ERC20Errors;
    use starkremit_contract::interfaces::IERC20;

    #[event]
    #[derive(Copy, Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        value: u256,
    }

    #[derive(Copy, Drop, starknet::Event)]
    pub struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        spender: ContractAddress,
        value: u256,
    }

    #[storage]
    struct Storage {
        /// Admin of the contract
        admin: ContractAddress,
        /// Token name
        name: felt252,
        /// Token symbol
        symbol: felt252,
        /// Number of decimals for display purposes
        decimals: u8,
        /// Total supply of the token
        total_supply: u256,
        /// Mapping of account balances
        balances: Map<ContractAddress, u256>,
        /// Mapping of account approvals
        allowances: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        name: felt252,
        symbol: felt252,
        initial_supply: u256,
    ) {
        // Initial setup
        self.admin.write(admin);
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(18);

        // Set initial supply
        self.total_supply.write(initial_supply);
        self.balances.write(admin, initial_supply);

        // Emit transfer event for initial token creation
        let zero_address: ContractAddress = 0.try_into().unwrap();
        self.emit(Transfer { from: zero_address, to: admin, value: initial_supply });
    }

    #[abi(embed_v0)]
    impl IERC20Impl of IERC20::IERC20<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let owner = get_caller_address();
            self._approve(owner, spender, amount);
            true
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            let caller = get_caller_address();

            // Reduce allowance
            let current_allowance = self.allowances.read((sender, caller));
            assert(current_allowance >= amount, ERC20Errors::INSUFFICIENT_ALLOWANCE);
            self._approve(sender, caller, current_allowance - amount);

            // Transfer tokens
            self._transfer(sender, recipient, amount);
            true
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        /// Internal function to handle token transfers
        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            // Validate addresses
            assert(!recipient.is_zero(), ERC20Errors::TRANSFER_TO_ZERO);

            // Check if sender has enough balance
            let sender_balance = self.balances.read(sender);
            assert(sender_balance >= amount, ERC20Errors::INSUFFICIENT_BALANCE);

            // Update balances
            self.balances.write(sender, sender_balance - amount);

            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);

            // Emit transfer event
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        /// Internal function to handle approvals
        fn _approve(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256,
        ) {
            // Validate addresses
            assert(!spender.is_zero(), ERC20Errors::APPROVE_TO_ZERO);

            // Update allowance
            self.allowances.write((owner, spender), amount);

            // Emit approval event
            self.emit(Approval { owner, spender, value: amount });
        }
    }
}
