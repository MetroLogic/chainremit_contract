use crate::base::types::SavingsGroup;
#[starknet::interface]
pub trait ISavingsGroup<TContractState> {
    fn create_group(ref self: TContractState, max_members: u8) -> u64;
    fn join_group(ref self: TContractState, group_id: u64);
    fn view_group(self: @TContractState, group_id: u64) -> SavingsGroup;
    fn confirm_group_membership(self: @TContractState, group_id: u64) -> bool;
}

#[starknet::component]
pub mod savings_group_component {
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starkremit_contract::base::errors::GroupErrors;
    use starkremit_contract::base::types::SavingsGroup;
    use super::*;

    #[storage]
    pub struct Storage {
        groups: Map<u64, SavingsGroup>,
        group_members: Map<(u64, ContractAddress), bool>,
        group_count: u64,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        GroupCreated: GroupCreated,
        MemberJoined: MemberJoined,
    }
    #[derive(Drop, starknet::Event)]
    pub struct GroupCreated {
        group_id: u64,
        creator: ContractAddress,
        max_members: u8,
        created_at: u64,
    }
    #[derive(Drop, starknet::Event)]
    pub struct MemberJoined {
        group_id: u64,
        member: ContractAddress,
        joined_at: u64,
    }

    #[embeddable_as(SavingsGroupComponent)]
    impl SavingsGroupImpl<
        TContractState, +HasComponent<TContractState>,
    > of ISavingsGroup<ComponentState<TContractState>> {
        fn create_group(ref self: ComponentState<TContractState>, max_members: u8) -> u64 {
            let caller = get_caller_address();
            let group_id = self.group_count.read() + 1;
            self.group_count.write(group_id);
            let group = SavingsGroup {
                id: group_id,
                creator: caller,
                max_members,
                member_count: 1,
                total_savings: 0,
                created_at: get_block_timestamp(),
                is_active: true,
            };
            self.groups.write(group_id, group);
            self.group_members.write((group_id, caller), true);
            self
                .emit(
                    Event::GroupCreated(
                        GroupCreated {
                            group_id, creator: caller, max_members, created_at: group.created_at,
                        },
                    ),
                );
            group_id
        }
        fn join_group(ref self: ComponentState<TContractState>, group_id: u64) {
            let caller = get_caller_address();

            assert(group_id <= self.group_count.read(), GroupErrors::INVALID_GROUP_ID);
            let mut group = self.groups.read(group_id);

            assert(group.created_at > 0, GroupErrors::GROUP_NOT_CREATED);
            assert(group.is_active, GroupErrors::GROUP_NOT_ACTIVE);
            assert(!self.group_members.read((group_id, caller)), GroupErrors::ALREADY_MEMBER);
            assert(
                group.max_members > 0 && group.max_members <= 100, GroupErrors::INVALID_GROUP_SIZE,
            );
            assert(group.member_count < (group.max_members).into(), GroupErrors::GROUP_FULL);

            group.member_count += 1;
            assert(group.member_count >= 2, GroupErrors::INVALID_GROUP_SIZE);
            self.groups.write(group_id, group);

            self.group_members.write((group_id, caller), true);

            self
                .emit(
                    Event::MemberJoined(
                        MemberJoined { group_id, member: caller, joined_at: get_block_timestamp() },
                    ),
                );
        }
        fn view_group(self: @ComponentState<TContractState>, group_id: u64) -> SavingsGroup {
            assert(group_id <= self.group_count.read(), GroupErrors::INVALID_GROUP_ID);

            let group = self.groups.read(group_id);
            assert(group.created_at > 0, GroupErrors::GROUP_NOT_CREATED);

            group
        }
        fn confirm_group_membership(self: @ComponentState<TContractState>, group_id: u64) -> bool {
            assert(group_id <= self.group_count.read(), GroupErrors::INVALID_GROUP_ID);
            self.group_members.read((group_id, get_caller_address()))
        }
    }
}
