use starknet::ContractAddress;
use super::TransferManagementTypes::{TransferData, TransferHistory, TransferStatus};

#[starknet::interface]
pub trait ITransferManagement<TContractState> {
    /// @notice Initiates a new transfer with enhanced logic compared to create_transfer.
    /// @param recipient The address of the transfer recipient.
    /// @param amount The amount to transfer.
    /// @param expires_at The expiration timestamp of the transfer.
    /// @param metadata Additional metadata associated with the transfer.
    /// @return The unique identifier (ID) of the created transfer.
    fn initiate_transfer(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256,
        expires_at: u64,
        metadata: felt252,
    ) -> u256;

    /// @notice Creates a new transfer.
    /// @param recipient The address of the transfer recipient.
    /// @param amount The amount to transfer.
    /// @param expires_at The expiration timestamp of the transfer.
    /// @param metadata Additional metadata associated with the transfer.
    /// @return The unique identifier (ID) of the created transfer.
    fn create_transfer(
        ref self: TContractState,
        recipient: ContractAddress,
        amount: u256,
        expires_at: u64,
        metadata: felt252,
    ) -> u256;

    /// @notice Cancels an existing transfer.
    /// @param transfer_id The unique identifier of the transfer to cancel.
    /// @return True if the transfer was successfully cancelled, false otherwise.
    fn cancel_transfer(ref self: TContractState, transfer_id: u256) -> bool;

    /// @notice Marks a transfer as completed.
    /// @param transfer_id The unique identifier of the transfer to complete.
    /// @return True if the transfer was successfully completed, false otherwise.
    fn complete_transfer(ref self: TContractState, transfer_id: u256) -> bool;

    /// @notice Partially completes a transfer by a specified amount.
    /// @param transfer_id The unique identifier of the transfer.
    /// @param partial_amount The amount to partially complete.
    /// @return True if the partial completion was successful, false otherwise.
    fn partial_complete_transfer(
        ref self: TContractState, 
        transfer_id: u256, 
        partial_amount: u256,
    ) -> bool;

    /// @notice Requests a cash-out for a specific transfer.
    /// @param transfer_id The unique identifier of the transfer.
    /// @return True if the cash-out request was successful, false otherwise.
    fn request_cash_out(ref self: TContractState, transfer_id: u256) -> bool;

    /// @notice Completes the cash-out process for a transfer (agent only).
    /// @param transfer_id The unique identifier of the transfer.
    /// @return True if the cash-out was completed, false otherwise.
    fn complete_cash_out(ref self: TContractState, transfer_id: u256) -> bool;

    /// @notice Retrieves the details of a specific transfer.
    /// @param transfer_id The unique identifier of the transfer.
    /// @return The transfer data structure containing all details.
    fn get_transfer(self: @TContractState, transfer_id: u256) -> TransferData;

    /// @notice Retrieves a list of transfers sent by a specific sender.
    /// @param sender The address of the sender.
    /// @param limit The maximum number of transfers to return.
    /// @param offset The starting index for pagination.
    /// @return An array of transfer data.
    fn get_transfers_by_sender(
        self: @TContractState, 
        sender: ContractAddress, 
        limit: u32, 
        offset: u32,
    ) -> Array<TransferData>;

    /// @notice Retrieves a list of transfers received by a specific recipient.
    /// @param recipient The address of the recipient.
    /// @param limit The maximum number of transfers to return.
    /// @param offset The starting index for pagination.
    /// @return An array of transfer data.
    fn get_transfers_by_recipient(
        self: @TContractState, 
        recipient: ContractAddress, 
        limit: u32, 
        offset: u32,
    ) -> Array<TransferData>;

    /// @notice Retrieves a list of transfers filtered by status.
    /// @param status The status to filter transfers by.
    /// @param limit The maximum number of transfers to return.
    /// @param offset The starting index for pagination.
    /// @return An array of transfer data.
    fn get_transfers_by_status(
        self: @TContractState, 
        status: TransferStatus, 
        limit: u32, 
        offset: u32,
    ) -> Array<TransferData>;

    /// @notice Retrieves a list of expired transfers.
    /// @param limit The maximum number of transfers to return.
    /// @param offset The starting index for pagination.
    /// @return An array of expired transfer data.
    fn get_expired_transfers(self: @TContractState, limit: u32, offset: u32) -> Array<TransferData>;

    /// @notice Processes expired transfers (admin only).
    /// @param limit The maximum number of expired transfers to process.
    /// @return The number of expired transfers processed.
    fn process_expired_transfers(ref self: TContractState, limit: u32) -> u32;

    /// @notice Assigns an agent to a specific transfer (admin only).
    /// @param transfer_id The unique identifier of the transfer.
    /// @param agent The address of the agent to assign.
    /// @return True if the agent was successfully assigned, false otherwise.
    fn assign_agent_to_transfer(
        ref self: TContractState, 
        transfer_id: u256, 
        agent: ContractAddress,
    ) -> bool;

    /// @notice Retrieves the history of a specific transfer.
    /// @param transfer_id The unique identifier of the transfer.
    /// @param limit The maximum number of history records to return.
    /// @param offset The starting index for pagination.
    /// @return An array of transfer history records.
    fn get_transfer_history(
        self: @TContractState, 
        transfer_id: u256, 
        limit: u32, 
        offset: u32,
    ) -> Array<TransferHistory>;

    /// @notice Searches transfer history by actor address.
    /// @param actor The address of the actor to search for.
    /// @param limit The maximum number of history records to return.
    /// @param offset The starting index for pagination.
    /// @return An array of transfer history records.
    fn search_history_by_actor(
        self: @TContractState, 
        actor: ContractAddress, 
        limit: u32, 
        offset: u32,
    ) -> Array<TransferHistory>;

    /// @notice Searches transfer history by action type.
    /// @param action The action identifier to search for.
    /// @param limit The maximum number of history records to return.
    /// @param offset The starting index for pagination.
    /// @return An array of transfer history records.
    fn search_history_by_action(
        self: @TContractState, 
        action: felt252, 
        limit: u32, 
        offset: u32,
    ) -> Array<TransferHistory>;

    /// @notice Retrieves transfer statistics.
    /// @return total The total number of transfers.
    /// @return completed The number of completed transfers.
    /// @return cancelled The number of cancelled transfers.
    /// @return expired The number of expired transfers.
    fn get_transfer_statistics(
        self: @TContractState,
    ) -> (u256, u256, u256, u256); // total, completed, cancelled, expired
}