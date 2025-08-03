use starknet::ContractAddress;
use starkremit_contract::base::types::{TransferData, TransferStatus, TransferHistory};
use core::num::traits::Zero;

#[starknet::interface]
pub trait ITransfer<TContractState> {
    fn initiate_transfer(ref self: TContractState, recipient: ContractAddress, amount: u256, expires_at: u64, metadata: felt252) -> u256;
    fn cancel_transfer(ref self: TContractState, transfer_id: u256) -> bool;
    fn complete_transfer(ref self: TContractState, transfer_id: u256) -> bool;
    fn partial_complete_transfer(ref self: TContractState, transfer_id: u256, partial_amount: u256) -> bool;
    fn request_cash_out(ref self: TContractState, transfer_id: u256) -> bool;
    fn complete_cash_out(ref self: TContractState, transfer_id: u256) -> bool;
    fn get_transfer(self: @TContractState, transfer_id: u256) -> TransferData;
    fn get_transfers_by_sender(self: @TContractState, sender: ContractAddress, limit: u32, offset: u32) -> Array<TransferData>;
    fn get_transfers_by_recipient(self: @TContractState, recipient: ContractAddress, limit: u32, offset: u32) -> Array<TransferData>;
    fn get_transfer_statistics(self: @TContractState) -> (u256, u256, u256, u256);
}

#[starknet::component]
pub mod transfer_component {
    use super::*;
    use starknet::{get_caller_address, get_block_timestamp, ContractAddress};
    use starkremit_contract::base::errors::TransferErrors;
    use starkremit_contract::base::types::{TransferData, TransferStatus};
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, Map, StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    pub struct Storage {
        transfers: Map<u256, TransferData>,
        next_transfer_id: u256,
        user_sent_transfers: Map<(ContractAddress, u32), u256>,
        user_sent_count: Map<ContractAddress, u32>,
        user_received_transfers: Map<(ContractAddress, u32), u256>,
        user_received_count: Map<ContractAddress, u32>,
        total_transfers: u256,
        total_completed_transfers: u256,
        total_cancelled_transfers: u256,
        total_expired_transfers: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TransferCreated: TransferCreated,
        TransferCancelled: TransferCancelled,
        TransferCompleted: TransferCompleted,
        TransferPartialCompleted: TransferPartialCompleted,
        TransferExpired: TransferExpired,
        CashOutRequested: CashOutRequested,
        CashOutCompleted: CashOutCompleted,
    }
    #[derive(Drop, starknet::Event)]
    pub struct TransferCreated {
        transfer_id: u256,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
        expires_at: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct TransferCancelled {
        transfer_id: u256,
        cancelled_by: ContractAddress,
        timestamp: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct TransferCompleted {
        transfer_id: u256,
        completed_by: ContractAddress,
        timestamp: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct TransferPartialCompleted {
        transfer_id: u256,
        partial_amount: u256,
        total_amount: u256,
        timestamp: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct TransferExpired {
        transfer_id: u256,
        expired_at: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct CashOutRequested {
        transfer_id: u256,
        requested_by: ContractAddress,
        timestamp: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct CashOutCompleted {
        transfer_id: u256,
        agent: ContractAddress,
        timestamp: u64,
    }

    #[embeddable_as(Transfer)]
    impl TransferImpl<
        TContractState, +HasComponent<TContractState>
    > of ITransfer<ComponentState<TContractState>> {
        fn initiate_transfer(
            ref self: ComponentState<TContractState>,
            recipient: ContractAddress,
            amount: u256,
            expires_at: u64,
            metadata: felt252,
        ) -> u256 {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(recipient != zero_address, TransferErrors::INVALID_TRANSFER_AMOUNT);
            assert(recipient != caller, 'Cannot transfer to self');
            assert(amount > 0, TransferErrors::INVALID_TRANSFER_AMOUNT);
            assert(expires_at > current_time, 'Expiry must be in future');
            assert(
                expires_at <= current_time + 86400 * 30, 'Expiry too far in future',
            );
            let transfer_id = self.next_transfer_id.read();
            self.next_transfer_id.write(transfer_id + 1);
            let transfer = TransferData {
                transfer_id,
                sender: caller,
                recipient,
                amount,
                status: TransferStatus::Pending,
                created_at: current_time,
                updated_at: current_time,
                expires_at,
                assigned_agent: zero_address,
                partial_amount: 0,
                metadata,
            };
            self.transfers.write(transfer_id, transfer);
            let sender_count = self.user_sent_count.read(caller);
            assert(sender_count < 4294967295, 'Max transfers per user exceeded');
            self.user_sent_transfers.write((caller, sender_count), transfer_id);
            self.user_sent_count.write(caller, sender_count + 1);
            let recipient_count = self.user_received_count.read(recipient);
            assert(recipient_count < 4294967295, 'Max transfers per user exceeded');
            self.user_received_transfers.write((recipient, recipient_count), transfer_id);
            self.user_received_count.write(recipient, recipient_count + 1);
            let total = self.total_transfers.read();
            self.total_transfers.write(total + 1);
            self.emit(Event::TransferCreated(TransferCreated {
                transfer_id,
                sender: caller,
                recipient,
                amount,
                expires_at,
            }));
            transfer_id
        }
        fn cancel_transfer(ref self: ComponentState<TContractState>, transfer_id: u256) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let mut transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);
            assert(
                transfer.status == TransferStatus::Pending, TransferErrors::INVALID_TRANSFER_STATUS,
            );
            assert(transfer.sender == caller, TransferErrors::UNAUTHORIZED_TRANSFER_OP);
            transfer.status = TransferStatus::Cancelled;
            transfer.updated_at = current_time;
            self.transfers.write(transfer_id, transfer);
            let cancelled_count = self.total_cancelled_transfers.read();
            self.total_cancelled_transfers.write(cancelled_count + 1);
            self.emit(Event::TransferCancelled(TransferCancelled {
                transfer_id,
                cancelled_by: caller,
                timestamp: current_time,
            }));
            true
        }
        fn complete_transfer(ref self: ComponentState<TContractState>, transfer_id: u256) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let mut transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);
            assert(
                transfer.status == TransferStatus::Pending
                    || transfer.status == TransferStatus::PartialComplete,
                TransferErrors::INVALID_TRANSFER_STATUS,
            );
            let zero_address: ContractAddress = 0.try_into().unwrap();
            let is_authorized = caller == transfer.recipient
                || (transfer.assigned_agent != zero_address && caller == transfer.assigned_agent);
            assert(is_authorized, TransferErrors::UNAUTHORIZED_TRANSFER_OP);
            transfer.status = TransferStatus::Completed;
            transfer.updated_at = current_time;
            self.transfers.write(transfer_id, transfer);
            let completed_count = self.total_completed_transfers.read();
            self.total_completed_transfers.write(completed_count + 1);
            self.emit(Event::TransferCompleted(TransferCompleted {
                transfer_id,
                completed_by: caller,
                timestamp: current_time,
            }));
            true
        }
        fn partial_complete_transfer(
            ref self: ComponentState<TContractState>,
            transfer_id: u256,
            partial_amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let mut transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);
            assert(
                transfer.status == TransferStatus::Pending
                    || transfer.status == TransferStatus::PartialComplete,
                TransferErrors::INVALID_TRANSFER_STATUS,
            );
            let zero_address: ContractAddress = 0.try_into().unwrap();
            let is_authorized = caller == transfer.recipient
                || (transfer.assigned_agent != zero_address && caller == transfer.assigned_agent);
            assert(is_authorized, TransferErrors::UNAUTHORIZED_TRANSFER_OP);
            assert(partial_amount > 0, TransferErrors::INVALID_TRANSFER_AMOUNT);
            assert(
                transfer.partial_amount + partial_amount <= transfer.amount,
                TransferErrors::PARTIAL_AMOUNT_EXCEEDS,
            );
            transfer.partial_amount += partial_amount;
            transfer.updated_at = current_time;
            if transfer.partial_amount == transfer.amount {
                transfer.status = TransferStatus::Completed;
            } else {
                transfer.status = TransferStatus::PartialComplete;
            }
            self.transfers.write(transfer_id, transfer);
            self.emit(Event::TransferPartialCompleted(TransferPartialCompleted {
                transfer_id,
                partial_amount,
                total_amount: transfer.amount,
                timestamp: current_time,
            }));
            true
        }
        fn request_cash_out(ref self: ComponentState<TContractState>, transfer_id: u256) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let mut transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);
            assert(
                transfer.status == TransferStatus::Pending, TransferErrors::INVALID_TRANSFER_STATUS,
            );
            assert(caller == transfer.recipient, TransferErrors::UNAUTHORIZED_TRANSFER_OP);
            transfer.status = TransferStatus::CashOutRequested;
            transfer.updated_at = current_time;
            self.transfers.write(transfer_id, transfer);
            self.emit(Event::CashOutRequested(CashOutRequested {
                transfer_id,
                requested_by: caller,
                timestamp: current_time,
            }));
            true
        }
        fn complete_cash_out(ref self: ComponentState<TContractState>, transfer_id: u256) -> bool {
            let caller = get_caller_address();
            let current_time = get_block_timestamp();
            let mut transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);
            assert(
                transfer.status == TransferStatus::CashOutRequested,
                TransferErrors::INVALID_TRANSFER_STATUS,
            );
            let zero_address: ContractAddress = 0.try_into().unwrap();
            assert(
                transfer.assigned_agent != zero_address, TransferErrors::INVALID_AGENT_ASSIGNMENT,
            );
            assert(caller == transfer.assigned_agent, TransferErrors::UNAUTHORIZED_TRANSFER_OP);
            transfer.status = TransferStatus::CashOutCompleted;
            transfer.updated_at = current_time;
            self.transfers.write(transfer_id, transfer);
            let completed_count = self.total_completed_transfers.read();
            self.total_completed_transfers.write(completed_count + 1);
            self.emit(Event::CashOutCompleted(CashOutCompleted {
                transfer_id,
                agent: caller,
                timestamp: current_time,
            }));
            true
        }
        fn get_transfer(self: @ComponentState<TContractState>, transfer_id: u256) -> TransferData {
            let transfer = self.transfers.read(transfer_id);
            assert(transfer.transfer_id != 0, TransferErrors::TRANSFER_NOT_FOUND);
            transfer
        }
        fn get_transfers_by_sender(
            self: @ComponentState<TContractState>, sender: ContractAddress, limit: u32, offset: u32,
        ) -> Array<TransferData> {
            let mut transfers = ArrayTrait::new();
            let total_count = self.user_sent_count.read(sender);
            let mut i = offset;
            let mut count = 0;
            while i < total_count && count < limit {
                let transfer_id = self.user_sent_transfers.read((sender, i));
                let transfer = self.transfers.read(transfer_id);
                transfers.append(transfer);
                count += 1;
                i += 1;
            }
            transfers
        }
        fn get_transfers_by_recipient(
            self: @ComponentState<TContractState>, recipient: ContractAddress, limit: u32, offset: u32,
        ) -> Array<TransferData> {
            let mut transfers = ArrayTrait::new();
            let total_count = self.user_received_count.read(recipient);
            let mut i = offset;
            let mut count = 0;
            while i < total_count && count < limit {
                let transfer_id = self.user_received_transfers.read((recipient, i));
                let transfer = self.transfers.read(transfer_id);
                transfers.append(transfer);
                count += 1;
                i += 1;
            }
            transfers
        }
        fn get_transfer_statistics(self: @ComponentState<TContractState>) -> (u256, u256, u256, u256) {
            (
                self.total_transfers.read(),
                self.total_completed_transfers.read(),
                self.total_cancelled_transfers.read(),
                self.total_expired_transfers.read(),
            )
        }
    }
}
