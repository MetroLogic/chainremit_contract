#[starknet::interface]
pub trait IGroups<TContractState> {
    fn create_group(ref self: TContractState, max_members: u8) -> u64;
    fn join_group(ref self: TContractState, group_id: u64);
}
