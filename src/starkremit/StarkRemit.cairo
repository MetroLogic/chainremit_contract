#[feature("deprecated-starknet-consts")]
#[starknet::contract]
mod StarkRemit {
    // Import necessary libraries and traits
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess // Unused import
    };
    use starknet::{ContractAddress, get_caller_address};
    use starkremit_contract::base::errors::{ERC20Errors, GroupsErrors};
    use starkremit_contract::interfaces::{IERC20, IGroups};

    // Fixed point scalar for accurate currency conversion calculations
    // Equivalent to 10^18, standard for 18 decimal places
    const FIXED_POINT_SCALER: u256 = 1_000_000_000_000_000_000;

    // Event definitions for the contract
    #[event]
    #[derive(Copy, Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer, // Standard ERC20 transfer event
        Approval: Approval, // Standard ERC20 approval event
        CurrencyAssigned: CurrencyAssigned, // Event for currency assignments
        TokenConverted: TokenConverted, // Event for currency conversions
        GroupCreated: GroupCreated, // Event for new group creation
        MemberJoined: MemberJoined // Event for new user joining group
    }

    // Standard ERC20 Transfer event
    // Emitted when tokens are transferred between addresses
    #[derive(Copy, Drop, starknet::Event)]
    pub struct Transfer {
        #[key]
        from: ContractAddress, // Source address
        #[key]
        to: ContractAddress, // Destination address
        value: u256 // Amount transferred
    }

    // Standard ERC20 Approval event
    // Emitted when approval is granted to spend tokens
    #[derive(Copy, Drop, starknet::Event)]
    pub struct Approval {
        #[key]
        owner: ContractAddress, // Token owner
        #[key]
        spender: ContractAddress, // Approved spender
        value: u256 // Approved amount
    }

    // Event emitted when a user is assigned a currency
    #[derive(Copy, Drop, starknet::Event)]
    pub struct CurrencyAssigned {
        #[key]
        user: ContractAddress, // User receiving the currency
        currency: felt252, // Currency identifier
        amount: u256 // Amount assigned
    }

    // Event emitted when a token is converted between currencies
    #[derive(Copy, Drop, starknet::Event)]
    pub struct TokenConverted {
        #[key]
        user: ContractAddress, // User performing the conversion
        from_currency: felt252, // Source currency
        to_currency: felt252, // Target currency
        amount_in: u256, // Input amount
        amount_out: u256 // Output amount after conversion
    }

    // Event emitted when a new group is created
    #[derive(Copy, Drop, starknet::Event)]
    pub struct GroupCreated {
        #[key]
        group_id: u64, // Unique group ID
        creator: ContractAddress, // Address that created the group
        max_members: u8 // Configured size limit
    }

    // Event emitted when a user joins a group
    #[derive(Copy, Drop, starknet::Event)]
    pub struct MemberJoined {
        #[key]
        group_id: u64, // Group being joined
        #[key]
        member: ContractAddress // Address that joined
    }

    // Savings group record
    #[derive(Copy, Drop, starknet::Store)]
    pub struct SavingsGroup {
        id: u64, // Group identifier
        creator: ContractAddress, // Group creator
        max_members: u8, // Maximum number of members
        member_count: u8, // Current number of members
        is_active: bool // Group active status
    }

    // Contract storage definition
    #[storage]
    struct Storage {
        // ERC20 standard storage
        admin: ContractAddress, // Admin with special privileges
        name: felt252, // Token name
        symbol: felt252, // Token symbol
        decimals: u8, // Token decimals (precision)
        total_supply: u256, // Total token supply
        balances: Map<ContractAddress, u256>, // User token balances
        allowances: Map<(ContractAddress, ContractAddress), u256>, // Spending allowances
        // Multi-currency support storage
        currency_balances: Map<(ContractAddress, felt252), u256>, // User balances by currency
        supported_currencies: Map<felt252, bool>, // Registered currencies
        oracle_address: ContractAddress, // Oracle contract address for exchange rates
        // Savings-group storage
        groups: Map<u64, SavingsGroup>, // Stores all savings groups by ID
        group_members: Map<(u64, ContractAddress), bool>, // True if user is member of given group
        group_count: u64 // Counter used to assign unique group IDs
    }

    // Contract constructor
    // Initializes the token with basic ERC20 fields and multi-currency support
    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress, // Admin address
        name: felt252, // Token name
        symbol: felt252, // Token symbol
        initial_supply: u256, // Initial token supply
        base_currency: felt252, // Base currency identifier
        oracle_address: ContractAddress // Oracle contract address
    ) {
        // Initialize ERC20 standard fields
        self.admin.write(admin);
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(18); // Standard 18 decimals for ERC20
        self.total_supply.write(initial_supply);
        self.balances.write(admin, initial_supply);

        // Initialize multi-currency support
        self.supported_currencies.write(base_currency, true);
        self.currency_balances.write((admin, base_currency), initial_supply);
        self.oracle_address.write(oracle_address);

        // Emit transfer event for initial supply
        let zero_address: ContractAddress = 0.try_into().unwrap();
        self.emit(Transfer { from: zero_address, to: admin, value: initial_supply });
    }

    // Implementation of the ERC20 standard interface
    #[abi(embed_v0)]
    impl IERC20Impl of IERC20::IERC20<ContractState> {
        // Returns the token name
        fn name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        // Returns the token symbol
        fn symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        // Returns the number of decimals used for display
        fn decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        // Returns the total token supply
        fn total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        // Returns the token balance of a specific account
        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        // Returns the amount approved for a spender by an owner
        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowances.read((owner, spender))
        }

        // Transfers tokens from caller to recipient
        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            let caller_balance = self.balances.read(caller);

            // Validate caller has sufficient balance
            assert(caller_balance >= amount, ERC20Errors::INSUFFICIENT_BALANCE);

            // Update balances
            self.balances.write(caller, caller_balance - amount);
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);

            // Emit transfer event
            self.emit(Transfer { from: caller, to: recipient, value: amount });
            true
        }

        // Approves a spender to spend tokens on behalf of the caller
        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            // Set allowance
            self.allowances.write((caller, spender), amount);

            // Emit approval event
            self.emit(Approval { owner: caller, spender, value: amount });
            true
        }

        // Transfers tokens on behalf of another account if approved
        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            let allowance = self.allowances.read((sender, caller));

            // Verify sufficient allowance
            assert(allowance >= amount, ERC20Errors::INSUFFICIENT_ALLOWANCE);

            // Verify sufficient balance
            let sender_balance = self.balances.read(sender);
            assert(sender_balance >= amount, ERC20Errors::INSUFFICIENT_BALANCE);

            // Update allowance
            self.allowances.write((sender, caller), allowance - amount);

            // Update balances
            self.balances.write(sender, sender_balance - amount);
            let recipient_balance = self.balances.read(recipient);
            self.balances.write(recipient, recipient_balance + amount);

            // Emit transfer event
            self.emit(Transfer { from: sender, to: recipient, value: amount });
            true
        }
    }

    // Implementation of Multi-Currency functions
    #[generate_trait]
    impl MultiCurrencyFunctions of MultiCurrencyFunctionsTrait {
        // Registers a new supported currency
        // Only callable by admin
        fn register_currency(ref self: ContractState, currency: felt252) {
            let caller = get_caller_address();
            // Validate caller is admin
            assert(caller == self.admin.read(), ERC20Errors::NotAdmin); // "Only admin" in felt252

            // Register the currency
            self.supported_currencies.write(currency, true);
        }

        // Converts tokens from one currency to another
        // Returns the amount of tokens received in the target currency
        fn convert_currency(
            ref self: ContractState,
            user: ContractAddress,
            from_currency: felt252,
            to_currency: felt252,
            amount: u256,
        ) -> u256 {
            // Validate currencies are supported
            assert(
                self.supported_currencies.read(from_currency),
                0x556e737570706f727465645f736f75726365 // "Unsupported_source" in felt252
            );
            assert(
                self.supported_currencies.read(to_currency),
                0x556e737570706f727465645f746172676574 // "Unsupported_target" in felt252
            );

            // Verify user has sufficient balance in source currency
            let from_balance = self.currency_balances.read((user, from_currency));
            assert(from_balance >= amount, ERC20Errors::INSUFFICIENT_BALANCE);

            // Get exchange rate from oracle
            let oracle = IOracleDispatcher { contract_address: self.oracle_address.read() };
            let rate: u256 = oracle.get_rate(from_currency, to_currency);

            // Calculate converted amount using fixed-point arithmetic
            let converted = amount * rate / FIXED_POINT_SCALER;

            // Update currency balances
            self.currency_balances.write((user, from_currency), from_balance - amount);
            let to_balance = self.currency_balances.read((user, to_currency));
            self.currency_balances.write((user, to_currency), to_balance + converted);

            // Emit conversion event
            self
                .emit(
                    TokenConverted {
                        user, from_currency, to_currency, amount_in: amount, amount_out: converted,
                    },
                );

            converted
        }
    }
    // Implementation of Savings Groups functions
    #[abi(embed_v0)]
    impl IGroupsImpl of IGroups::IGroups<ContractState> {
        // Creates a new savings group, caller becomes first member
        // Returns the id of the created group
        fn create_group(ref self: ContractState, max_members: u8) -> u64 {
            let caller = get_caller_address();

            // TODO: UserRegistry check

            // Require at least two members in the group
            assert(max_members > 1, GroupsErrors::INVALID_GROUP_SIZE);

            let group_id = self._new_group_id();

            // Store group parameters
            self
                .groups
                .entry(group_id)
                .write(
                    SavingsGroup {
                        id: group_id,
                        creator: caller,
                        max_members,
                        member_count: 1_u8,
                        is_active: true,
                    },
                );

            // Add caller as member of the group
            self.group_members.write((group_id, caller), true);

            // Emit group created event
            self.emit(GroupCreated { group_id, creator: caller, max_members });

            group_id
        }

        // Joins an existing active group
        fn join_group(ref self: ContractState, group_id: u64) {
            let caller = get_caller_address();

            // TODO: UserRegistry check

            let group = self.groups.entry(group_id).read();

            // Group must be active
            assert(group.is_active, GroupsErrors::GROUP_INACTIVE);

            // Caller must not already be a member
            assert(
                !self.group_members.entry((group_id, caller)).read(), GroupsErrors::ALREADY_MEMBER,
            );

            // Group must not be full
            assert(group.member_count < group.max_members, GroupsErrors::GROUP_FULL);

            // Update number of members in the group
            self.groups.entry(group_id).member_count.write(group.member_count + 1);

            // Mark caller as member of the group
            self.group_members.write((group_id, caller), true);

            // Emit member joined event
            self.emit(MemberJoined { group_id, member: caller });
        }
    }

    // Internal helper for Savings groups
    #[generate_trait]
    impl InternalGroupsHelpers of InternalGroupsHelpersTrait {
        // Generates and stores a new unique group ID for a savings group
        // Returns the newly generated group ID
        fn _new_group_id(ref self: ContractState) -> u64 {
            let group_id = self.group_count.read();

            self.group_count.write(group_id + 1);

            group_id
        }
    }


    // Oracle interface for retrieving exchange rates
    #[starknet::interface]
    trait IOracle<T> {
        // Gets the exchange rate between two currencies
        // Returns the rate as a fixed-point number (with FIXED_POINT_SCALER precision)
        fn get_rate(self: @T, from: felt252, to: felt252) -> u256;
    }

    // Mock implementation of OracleInterface for testing
    #[starknet::contract]
    mod MockOracle {
        #[storage]
        struct Storage {}

        #[generate_trait]
        impl OracleInterface of IOracle {
            // Mock implementation that returns a 1:1 conversion rate
            fn get_rate(self: @ContractState, from: felt252, to: felt252) -> u256 {
                // Mock rate for testing purposes
                1_000_000_000_000_000_000 // Example: 1:1 conversion rate
            }
        }
    }
}
