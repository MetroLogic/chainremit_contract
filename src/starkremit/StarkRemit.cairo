#[feature("deprecated-starknet-consts")]
#[starknet::contract]
mod StarkRemit {
    // Import necessary libraries and traits
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, // Unused import
        StoragePointerWriteAccess // Unused import
    };
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starkremit_contract::base::errors::{ERC20Errors, RegistrationErrors};
    use starkremit_contract::base::types::{UserProfile, RegistrationRequest, RegistrationStatus, KYCLevel};
    use starkremit_contract::interfaces::{IERC20, IStarkRemit};

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
        UserRegistered: UserRegistered, // Event for user registration
        UserProfileUpdated: UserProfileUpdated, // Event for profile updates
        UserDeactivated: UserDeactivated, // Event for user deactivation
        UserReactivated: UserReactivated, // Event for user reactivation
        KYCLevelUpdated: KYCLevelUpdated, // Event for KYC level updates
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

    // Event emitted when a new user is registered
    #[derive(Copy, Drop, starknet::Event)]
    pub struct UserRegistered {
        #[key]
        user_address: ContractAddress, // Registered user address
        email_hash: felt252, // Email hash for privacy
        preferred_currency: felt252, // User's preferred currency
        registration_timestamp: u64, // Registration time
    }

    // Event emitted when user profile is updated
    #[derive(Copy, Drop, starknet::Event)]
    pub struct UserProfileUpdated {
        #[key]
        user_address: ContractAddress, // User address
        updated_fields: felt252, // Indication of what was updated
    }

    // Event emitted when user is deactivated
    #[derive(Copy, Drop, starknet::Event)]
    pub struct UserDeactivated {
        #[key]
        user_address: ContractAddress, // Deactivated user address
        admin: ContractAddress, // Admin who performed the action
    }

    // Event emitted when user is reactivated
    #[derive(Copy, Drop, starknet::Event)]
    pub struct UserReactivated {
        #[key]
        user_address: ContractAddress, // Reactivated user address
        admin: ContractAddress, // Admin who performed the action
    }

    // Event emitted when user KYC level is updated
    #[derive(Copy, Drop, starknet::Event)]
    pub struct KYCLevelUpdated {
        #[key]
        user_address: ContractAddress, // User address
        old_level: KYCLevel, // Previous KYC level
        new_level: KYCLevel, // New KYC level
        admin: ContractAddress, // Admin who performed the update
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
        // User registration storage
        user_profiles: Map<ContractAddress, UserProfile>, // User profile data
        email_registry: Map<felt252, ContractAddress>, // Email hash to address mapping for uniqueness
        phone_registry: Map<felt252, ContractAddress>, // Phone hash to address mapping for uniqueness
        registration_status: Map<ContractAddress, RegistrationStatus>, // User registration status
        total_users: u256, // Total number of registered users
        registration_enabled: bool, // Whether registration is currently enabled
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

        // Initialize user registration system
        self.total_users.write(0);
        self.registration_enabled.write(true);

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

    // Implementation of the User Registration interface
    #[abi(embed_v0)]
    impl IStarkRemitImpl of IStarkRemit::IStarkRemit<ContractState> {
        /// Register a new user with the platform
        /// Validates all data and prevents duplicate registrations
        fn register_user(ref self: ContractState, registration_data: RegistrationRequest) -> bool {
            let caller = get_caller_address();
            let zero_address: ContractAddress = 0.try_into().unwrap();
            
            // Validate caller is not zero address
            assert(caller != zero_address, RegistrationErrors::ZERO_ADDRESS);
            
            // Check if registration is enabled
            assert(self.registration_enabled.read(), 'Registration disabled');
            
            // Check if user is already registered
            let current_status = self.registration_status.read(caller);
            match current_status {
                RegistrationStatus::Completed => {
                    assert(false, RegistrationErrors::USER_ALREADY_REGISTERED);
                },
                RegistrationStatus::Suspended => {
                    assert(false, RegistrationErrors::USER_SUSPENDED);
                },
                _ => {} // Allow registration for NotStarted, InProgress, or Failed
            }
            
            // Validate registration data
            assert(self.validate_registration_data(registration_data), RegistrationErrors::INCOMPLETE_DATA);
            
            // Check for duplicate email
            let existing_email_user = self.email_registry.read(registration_data.email_hash);
            assert(existing_email_user == zero_address, RegistrationErrors::EMAIL_ALREADY_EXISTS);
            
            // Check for duplicate phone
            let existing_phone_user = self.phone_registry.read(registration_data.phone_hash);
            assert(existing_phone_user == zero_address, RegistrationErrors::PHONE_ALREADY_EXISTS);
            
            // Check if preferred currency is supported
            assert(
                self.supported_currencies.read(registration_data.preferred_currency),
                RegistrationErrors::UNSUPPORTED_CURRENCY
            );
            
            // Set registration status to in progress
            self.registration_status.write(caller, RegistrationStatus::InProgress);
            
            // Create user profile
            let current_timestamp = get_block_timestamp();
            let user_profile = UserProfile {
                address: caller,
                email_hash: registration_data.email_hash,
                phone_hash: registration_data.phone_hash,
                full_name: registration_data.full_name,
                preferred_currency: registration_data.preferred_currency,
                kyc_level: KYCLevel::None,
                registration_timestamp: current_timestamp,
                is_active: true,
                country_code: registration_data.country_code,
            };
            
            // Store user profile
            self.user_profiles.write(caller, user_profile);
            
            // Register email and phone for uniqueness
            self.email_registry.write(registration_data.email_hash, caller);
            self.phone_registry.write(registration_data.phone_hash, caller);
            
            // Update registration status to completed
            self.registration_status.write(caller, RegistrationStatus::Completed);
            
            // Increment total users
            let current_total = self.total_users.read();
            self.total_users.write(current_total + 1);
            
            // Emit registration event
            self.emit(UserRegistered {
                user_address: caller,
                email_hash: registration_data.email_hash,
                preferred_currency: registration_data.preferred_currency,
                registration_timestamp: current_timestamp,
            });
            
            true
        }
        
        /// Get user profile by address
        fn get_user_profile(self: @ContractState, user_address: ContractAddress) -> UserProfile {
            let status = self.registration_status.read(user_address);
            match status {
                RegistrationStatus::Completed => {},
                _ => {
                    assert(false, RegistrationErrors::USER_NOT_FOUND);
                }
            }
            
            self.user_profiles.read(user_address)
        }
        
        /// Update user profile information
        /// Only the user themselves can update their profile
        fn update_user_profile(ref self: ContractState, updated_profile: UserProfile) -> bool {
            let caller = get_caller_address();
            
            // Verify caller is the profile owner
            assert(caller == updated_profile.address, 'Unauthorized profile update');
            
            // Verify user is registered and active
            let status = self.registration_status.read(caller);
            match status {
                RegistrationStatus::Completed => {},
                _ => {
                    assert(false, RegistrationErrors::USER_NOT_FOUND);
                }
            }
            
            let current_profile = self.user_profiles.read(caller);
            assert(current_profile.is_active, RegistrationErrors::USER_INACTIVE);
            
            // Validate that core immutable fields haven't changed
            assert(updated_profile.address == current_profile.address, 'Cannot change address');
            assert(updated_profile.registration_timestamp == current_profile.registration_timestamp, 'Cannot change timestamp');
            
            // If email or phone changed, check for duplicates
            if updated_profile.email_hash != current_profile.email_hash {
                let zero_address: ContractAddress = 0.try_into().unwrap();
                let existing_email_user = self.email_registry.read(updated_profile.email_hash);
                assert(existing_email_user == zero_address, RegistrationErrors::EMAIL_ALREADY_EXISTS);
                
                // Update email registry
                self.email_registry.write(current_profile.email_hash, zero_address);
                self.email_registry.write(updated_profile.email_hash, caller);
            }
            
            if updated_profile.phone_hash != current_profile.phone_hash {
                let zero_address: ContractAddress = 0.try_into().unwrap();
                let existing_phone_user = self.phone_registry.read(updated_profile.phone_hash);
                assert(existing_phone_user == zero_address, RegistrationErrors::PHONE_ALREADY_EXISTS);
                
                // Update phone registry
                self.phone_registry.write(current_profile.phone_hash, zero_address);
                self.phone_registry.write(updated_profile.phone_hash, caller);
            }
            
            // Check if new preferred currency is supported
            assert(
                self.supported_currencies.read(updated_profile.preferred_currency),
                RegistrationErrors::UNSUPPORTED_CURRENCY
            );
            
            // Store updated profile
            self.user_profiles.write(caller, updated_profile);
            
            // Emit update event
            self.emit(UserProfileUpdated {
                user_address: caller,
                updated_fields: 'profile_updated',
            });
            
            true
        }
        
        /// Check if user is registered
        fn is_user_registered(self: @ContractState, user_address: ContractAddress) -> bool {
            let status = self.registration_status.read(user_address);
            match status {
                RegistrationStatus::Completed => true,
                _ => false
            }
        }
        
        /// Get user registration status
        fn get_registration_status(self: @ContractState, user_address: ContractAddress) -> RegistrationStatus {
            self.registration_status.read(user_address)
        }
        
        /// Update user KYC level (admin only)
        fn update_kyc_level(ref self: ContractState, user_address: ContractAddress, kyc_level: KYCLevel) -> bool {
            let caller = get_caller_address();
            
            // Verify caller is admin
            assert(caller == self.admin.read(), ERC20Errors::NotAdmin);
            
            // Verify user is registered
            assert(self.is_user_registered(user_address), RegistrationErrors::USER_NOT_FOUND);
            
            let mut user_profile = self.user_profiles.read(user_address);
            let old_level = user_profile.kyc_level;
            
            // Update KYC level
            user_profile.kyc_level = kyc_level;
            self.user_profiles.write(user_address, user_profile);
            
            // Emit KYC update event
            self.emit(KYCLevelUpdated {
                user_address,
                old_level,
                new_level: kyc_level,
                admin: caller,
            });
            
            true
        }
        
        /// Deactivate user account (admin only)
        fn deactivate_user(ref self: ContractState, user_address: ContractAddress) -> bool {
            let caller = get_caller_address();
            
            // Verify caller is admin
            assert(caller == self.admin.read(), ERC20Errors::NotAdmin);
            
            // Verify user is registered
            assert(self.is_user_registered(user_address), RegistrationErrors::USER_NOT_FOUND);
            
            let mut user_profile = self.user_profiles.read(user_address);
            user_profile.is_active = false;
            self.user_profiles.write(user_address, user_profile);
            
            // Update registration status
            self.registration_status.write(user_address, RegistrationStatus::Suspended);
            
            // Emit deactivation event
            self.emit(UserDeactivated {
                user_address,
                admin: caller,
            });
            
            true
        }
        
        /// Reactivate user account (admin only)
        fn reactivate_user(ref self: ContractState, user_address: ContractAddress) -> bool {
            let caller = get_caller_address();
            
            // Verify caller is admin
            assert(caller == self.admin.read(), ERC20Errors::NotAdmin);
            
            // Verify user exists
            let status = self.registration_status.read(user_address);
            match status {
                RegistrationStatus::Suspended => {},
                _ => {
                    assert(false, 'User not suspended');
                }
            }
            
            let mut user_profile = self.user_profiles.read(user_address);
            user_profile.is_active = true;
            self.user_profiles.write(user_address, user_profile);
            
            // Update registration status
            self.registration_status.write(user_address, RegistrationStatus::Completed);
            
            // Emit reactivation event
            self.emit(UserReactivated {
                user_address,
                admin: caller,
            });
            
            true
        }
        
        /// Get total registered users count
        fn get_total_users(self: @ContractState) -> u256 {
            self.total_users.read()
        }
        
        /// Validate registration data
        fn validate_registration_data(self: @ContractState, registration_data: RegistrationRequest) -> bool {
            // Check that required fields are not empty (0)
            if registration_data.email_hash == 0 {
                return false;
            }
            
            if registration_data.phone_hash == 0 {
                return false;
            }
            
            if registration_data.full_name == 0 {
                return false;
            }
            
            if registration_data.preferred_currency == 0 {
                return false;
            }
            
            if registration_data.country_code == 0 {
                return false;
            }
            
            true
        }
    }
}
