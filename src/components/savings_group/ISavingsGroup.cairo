
use starknet::ContractAddress;

#[starknet::interface]
pub trait ISavingsGroup<TContractState> {
    /// @notice Contribute a specified amount to a given round.
    /// @param round_id The unique identifier of the round.
    /// @param amount The amount to contribute for the round.
    fn contribute_round(ref self: TContractState, round_id: u256, amount: u256);

    /// @notice Mark a round as completed.
    /// @param round_id The unique identifier of the round to complete.
    fn complete_round(ref self: TContractState, round_id: u256);

    /// @notice Add a new round to the schedule for a specific recipient and deadline.
    /// @param recipient The address of the recipient for this round.
    /// @param deadline The deadline timestamp for the round.
    fn add_round_to_schedule(ref self: TContractState, recipient: ContractAddress, deadline: u64);

    /// @notice Check if an address is a member of the savings group.
    /// @param address The address to check for membership.
    /// @return bool True if the address is a member, false otherwise.
    fn is_member(self: @TContractState, address: ContractAddress) -> bool;

    /// @notice Check for missed contributions in a specific round.
    /// @param round_id The unique identifier of the round to check.
    fn check_missed_contributions(ref self: TContractState, round_id: u256);

    /// @notice Retrieve all members of the savings group.
    /// @return Array of ContractAddress representing all group members.
    fn get_all_members(self: @TContractState) -> Array<ContractAddress>;

    /// @notice Add a new member to the savings group.
    /// @param address The address of the new member to add.
    fn add_member(ref self: TContractState, address: ContractAddress);

    /// @notice Disburse the contributions for a specific round to the intended recipient.
    /// @param round_id The unique identifier of the round to disburse.
    fn disburse_round_contribution(ref self: TContractState, round_id: u256);

    /// @notice Create a new savings group with a maximum number of members.
    /// @param max_members The maximum number of members allowed in the group.
    /// @return group_id The unique identifier of the newly created group.
    fn create_group(ref self: TContractState, max_members: u8) -> u64;

    /// @notice Join an existing savings group.
    /// @param group_id The unique identifier of the group to join.
    fn join_group(ref self: TContractState, group_id: u64);
}
