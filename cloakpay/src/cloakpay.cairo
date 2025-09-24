#[starknet::contract]
pub mod cloakpay {
    use core::num::traits::Zero;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StoragePathEntry, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::base::errors::{CloakPayErrors, payment_errors};
    use crate::base::events::Events::DepositEvent;
    use crate::base::types::DepositDetails;
    use crate::interfaces::ICloakpay::ICloakPay;

    #[storage]
    struct Storage {
        deposit: Map<u256, DepositDetails>, // deposit id to deposit details
        commitments: Map<felt252, bool>, // commitment to use status
        commitment_to_deposit_id: Map<felt252, u256>, // commitment to deposit id
        total_deposits: u256,
        supported_tokens: Map<u256, ContractAddress> // supported token_id to contract address
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        DepositEvent: DepositEvent,
    }

    #[constructor]
    fn constructor(ref self: ContractState, default_supported_token: ContractAddress) {
        self.supported_tokens.entry(1_u256).write(default_supported_token);
        self.total_deposits.write(0_u256);
    }


    #[abi(embed_v0)]
    impl CloakPayImpl of ICloakPay<ContractState> {
        fn deposit(
            ref self: ContractState, supported_token: u256, amount: u256, commitment: felt252,
        ) {
            assert(!self.commitments.read(commitment), CloakPayErrors::COMMITMENT_ALREADY_USED);
            let supported_token = self.supported_tokens.read(supported_token);
            assert(!supported_token.is_zero(), CloakPayErrors::UNSUPPORTED_TOKEN);
            self._process_payment(amount, supported_token);
            let deposit_id = self.total_deposits.read() + 1;
            let deposit_details = DepositDetails {
                supported_token, amount, commitment, time_sent: get_block_timestamp(),
            };
            self.deposit.entry(deposit_id).write(deposit_details);
            self.commitment_to_deposit_id.entry(commitment).write(deposit_id);
            self.total_deposits.write(deposit_id);
            self.commitments.entry(commitment).write(true);
            self
                .emit(
                    Event::DepositEvent(
                        DepositEvent { deposit_id: deposit_id, details: deposit_details },
                    ),
                );
        }

        fn get_deposit_details(ref self: ContractState, deposit_id: u256) -> DepositDetails {
            self.deposit.read(deposit_id)
        }

        fn get_total_deposits(ref self: ContractState) -> u256 {
            self.total_deposits.read()
        }

        fn get_commitment_used_status(ref self: ContractState, commitment: felt252) -> bool {
            self.commitments.read(commitment)
        }

        fn get_deposit_id_from_commitment(ref self: ContractState, commitment: felt252) -> u256 {
            self.commitment_to_deposit_id.read(commitment)
        }
    }

    #[generate_trait]
    impl Internal of InternalTrait {
        /// @notice Processes a payment for a deposit
        fn _process_payment(ref self: ContractState, amount: u256, token: ContractAddress) {
            let strk_token = IERC20Dispatcher { contract_address: token };
            let caller = get_caller_address();
            let contract_address = get_contract_address();
            self._check_token_allowance(caller, amount, token);
            self._check_token_balance(caller, amount, token);
            strk_token.transfer_from(caller, contract_address, amount);
        }

        /// @notice Checks if the caller has sufficient token allowance.
        fn _check_token_allowance(
            ref self: ContractState, spender: ContractAddress, amount: u256, token: ContractAddress,
        ) {
            let token = IERC20Dispatcher { contract_address: token };
            let allowance = token.allowance(spender, starknet::get_contract_address());
            assert(allowance >= amount, payment_errors::INSUFFICIENT_ALLOWANCE);
        }

        /// @notice Checks if the caller has sufficient token balance.
        fn _check_token_balance(
            ref self: ContractState, caller: ContractAddress, amount: u256, token: ContractAddress,
        ) {
            let token = IERC20Dispatcher { contract_address: token };
            let balance = token.balance_of(caller);
            assert(balance >= amount, payment_errors::INSUFFICIENT_BALANCE);
        }
    }
}
