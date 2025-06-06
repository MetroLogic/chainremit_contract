use starknet::ContractAddress;

/// Enhanced Oracle interface for comprehensive exchange rate functionality
#[starknet::interface]
pub trait IOracle<TContractState> {
    /// Get exchange rate between two currencies
    /// Returns the rate as a fixed-point number (with 18 decimal precision)
    /// @param from Source currency identifier
    /// @param to Target currency identifier
    /// @return Exchange rate (target_amount = source_amount * rate / 10^18)
    fn get_rate(self: @TContractState, from: felt252, to: felt252) -> u256;

    /// Get rate with timestamp for verification and freshness checks
    /// @param from Source currency identifier
    /// @param to Target currency identifier
    /// @return (rate, timestamp) Exchange rate and last update timestamp
    fn get_rate_with_timestamp(self: @TContractState, from: felt252, to: felt252) -> (u256, u64);

    /// Check if currency pair is supported by the Oracle
    /// @param from Source currency identifier
    /// @param to Target currency identifier
    /// @return true if pair is supported, false otherwise
    fn is_pair_supported(self: @TContractState, from: felt252, to: felt252) -> bool;

    /// Get last update timestamp for specific currency pair
    /// @param from Source currency identifier
    /// @param to Target currency identifier
    /// @return Last update timestamp for this pair
    fn get_last_update_timestamp(self: @TContractState, from: felt252, to: felt252) -> u64;

    /// Update exchange rate (admin/authorized updater only)
    /// @param from Source currency identifier
    /// @param to Target currency identifier
    /// @param rate New exchange rate
    /// @return true if update successful
    fn update_rate(ref self: TContractState, from: felt252, to: felt252, rate: u256) -> bool;

    /// Add support for new currency pair (admin only)
    /// @param from Source currency identifier
    /// @param to Target currency identifier
    /// @param initial_rate Initial exchange rate
    /// @return true if successfully added
    fn add_currency_pair(
        ref self: TContractState, from: felt252, to: felt252, initial_rate: u256,
    ) -> bool;

    /// Remove support for currency pair (admin only)
    /// @param from Source currency identifier
    /// @param to Target currency identifier
    /// @return true if successfully removed
    fn remove_currency_pair(ref self: TContractState, from: felt252, to: felt252) -> bool;

    /// Get all supported currency pairs
    /// @return Array of (from, to) currency pairs
    fn get_supported_pairs(self: @TContractState) -> Array<(felt252, felt252)>;

    /// Set rate update authority (admin only)
    /// @param updater Address authorized to update rates
    /// @param authorized true to authorize, false to revoke
    /// @return true if successful
    fn set_rate_updater(
        ref self: TContractState, updater: ContractAddress, authorized: bool,
    ) -> bool;

    /// Check if address is authorized to update rates
    /// @param updater Address to check
    /// @return true if authorized
    fn is_rate_updater(self: @TContractState, updater: ContractAddress) -> bool;
}

/// Oracle Contract Implementation
#[starknet::contract]
mod Oracle {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::IOracle;

    /// Exchange rate data structure
    #[derive(Copy, Drop, Serde, starknet::Store)]
    struct ExchangeRateData {
        rate: u256,
        last_updated: u64,
        is_active: bool,
    }

    /// Event emitted when exchange rate is updated
    #[derive(Copy, Drop, starknet::Event)]
    struct RateUpdated {
        #[key]
        from_currency: felt252,
        #[key]
        to_currency: felt252,
        old_rate: u256,
        new_rate: u256,
        timestamp: u64,
    }

    /// Event emitted when currency pair is added
    #[derive(Copy, Drop, starknet::Event)]
    struct CurrencyPairAdded {
        #[key]
        from_currency: felt252,
        #[key]
        to_currency: felt252,
        initial_rate: u256,
        timestamp: u64,
    }

    /// Event emitted when currency pair is removed
    #[derive(Copy, Drop, starknet::Event)]
    struct CurrencyPairRemoved {
        #[key]
        from_currency: felt252,
        #[key]
        to_currency: felt252,
        timestamp: u64,
    }

    /// Event emitted when rate updater is authorized/deauthorized
    #[derive(Copy, Drop, starknet::Event)]
    struct RateUpdaterChanged {
        #[key]
        updater: ContractAddress,
        authorized: bool,
        timestamp: u64,
    }

    #[event]
    #[derive(Copy, Drop, starknet::Event)]
    enum Event {
        RateUpdated: RateUpdated,
        CurrencyPairAdded: CurrencyPairAdded,
        CurrencyPairRemoved: CurrencyPairRemoved,
        RateUpdaterChanged: RateUpdaterChanged,
    }

    #[storage]
    struct Storage {
        /// Contract admin
        admin: ContractAddress,
        /// Exchange rates between currency pairs
        exchange_rates: Map<(felt252, felt252), ExchangeRateData>,
        /// Authorized rate updaters
        rate_updaters: Map<ContractAddress, bool>,
        /// Supported currency pairs for efficient enumeration
        supported_pairs: Map<u32, (felt252, felt252)>,
        /// Number of supported pairs
        pair_count: u32,
    }

    /// Error constants
    mod Errors {
        pub const NOT_ADMIN: felt252 = 'Oracle: Not admin';
        pub const NOT_AUTHORIZED: felt252 = 'Oracle: Not authorized';
        pub const PAIR_NOT_SUPPORTED: felt252 = 'Oracle: Pair not supported';
        pub const PAIR_ALREADY_EXISTS: felt252 = 'Oracle: Pair already exists';
        pub const INVALID_RATE: felt252 = 'Oracle: Invalid rate';
        pub const SAME_CURRENCY: felt252 = 'Oracle: Same currency';
    }

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        self.admin.write(admin);
        // Make admin an authorized rate updater by default
        self.rate_updaters.write(admin, true);
        self.pair_count.write(0);
    }

    #[abi(embed_v0)]
    impl OracleImpl of IOracle<ContractState> {
        fn get_rate(self: @ContractState, from: felt252, to: felt252) -> u256 {
            // Handle same currency case
            if from == to {
                return 1_000_000_000_000_000_000; // 1:1 rate with 18 decimals
            }

            let rate_data = self.exchange_rates.read((from, to));
            assert(rate_data.is_active, Errors::PAIR_NOT_SUPPORTED);
            rate_data.rate
        }

        fn get_rate_with_timestamp(
            self: @ContractState, from: felt252, to: felt252,
        ) -> (u256, u64) {
            // Handle same currency case
            if from == to {
                return (1_000_000_000_000_000_000, get_block_timestamp());
            }

            let rate_data = self.exchange_rates.read((from, to));
            assert(rate_data.is_active, Errors::PAIR_NOT_SUPPORTED);
            (rate_data.rate, rate_data.last_updated)
        }

        fn is_pair_supported(self: @ContractState, from: felt252, to: felt252) -> bool {
            if from == to {
                return true; // Same currency always supported
            }
            self.exchange_rates.read((from, to)).is_active
        }

        fn get_last_update_timestamp(self: @ContractState, from: felt252, to: felt252) -> u64 {
            if from == to {
                return get_block_timestamp(); // Same currency always current
            }
            let rate_data = self.exchange_rates.read((from, to));
            assert(rate_data.is_active, Errors::PAIR_NOT_SUPPORTED);
            rate_data.last_updated
        }

        fn update_rate(ref self: ContractState, from: felt252, to: felt252, rate: u256) -> bool {
            let caller = get_caller_address();
            assert(
                self.rate_updaters.read(caller) || caller == self.admin.read(),
                Errors::NOT_AUTHORIZED,
            );
            assert(from != to, Errors::SAME_CURRENCY);
            assert(rate > 0, Errors::INVALID_RATE);

            let mut rate_data = self.exchange_rates.read((from, to));
            assert(rate_data.is_active, Errors::PAIR_NOT_SUPPORTED);

            let old_rate = rate_data.rate;
            rate_data.rate = rate;
            rate_data.last_updated = get_block_timestamp();
            self.exchange_rates.write((from, to), rate_data);

            self
                .emit(
                    RateUpdated {
                        from_currency: from,
                        to_currency: to,
                        old_rate,
                        new_rate: rate,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn add_currency_pair(
            ref self: ContractState, from: felt252, to: felt252, initial_rate: u256,
        ) -> bool {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), Errors::NOT_ADMIN);
            assert(from != to, Errors::SAME_CURRENCY);
            assert(initial_rate > 0, Errors::INVALID_RATE);

            let existing_rate = self.exchange_rates.read((from, to));
            assert(!existing_rate.is_active, Errors::PAIR_ALREADY_EXISTS);

            let rate_data = ExchangeRateData {
                rate: initial_rate, last_updated: get_block_timestamp(), is_active: true,
            };

            self.exchange_rates.write((from, to), rate_data);

            // Add to supported pairs list
            let count = self.pair_count.read();
            self.supported_pairs.write(count, (from, to));
            self.pair_count.write(count + 1);

            self
                .emit(
                    CurrencyPairAdded {
                        from_currency: from,
                        to_currency: to,
                        initial_rate,
                        timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn remove_currency_pair(ref self: ContractState, from: felt252, to: felt252) -> bool {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), Errors::NOT_ADMIN);
            assert(from != to, Errors::SAME_CURRENCY);

            let mut rate_data = self.exchange_rates.read((from, to));
            assert(rate_data.is_active, Errors::PAIR_NOT_SUPPORTED);

            rate_data.is_active = false;
            self.exchange_rates.write((from, to), rate_data);

            self
                .emit(
                    CurrencyPairRemoved {
                        from_currency: from, to_currency: to, timestamp: get_block_timestamp(),
                    },
                );

            true
        }

        fn get_supported_pairs(self: @ContractState) -> Array<(felt252, felt252)> {
            let mut pairs = ArrayTrait::new();
            let count = self.pair_count.read();
            let mut i = 0;

            while i < count {
                let pair = self.supported_pairs.read(i);
                let rate_data = self.exchange_rates.read(pair);
                if rate_data.is_active {
                    pairs.append(pair);
                }
                i += 1;
            };

            pairs
        }

        fn set_rate_updater(
            ref self: ContractState, updater: ContractAddress, authorized: bool,
        ) -> bool {
            let caller = get_caller_address();
            assert(caller == self.admin.read(), Errors::NOT_ADMIN);

            self.rate_updaters.write(updater, authorized);

            self.emit(RateUpdaterChanged { updater, authorized, timestamp: get_block_timestamp() });

            true
        }

        fn is_rate_updater(self: @ContractState, updater: ContractAddress) -> bool {
            self.rate_updaters.read(updater)
        }
    }
}
