#[starknet::interface]
pub trait ISavingsGroup<TContractState> {
    fn create_group(ref self: TContractState, max_members: u8) -> u64;
    fn join_group(ref self: TContractState, group_id: u64);
}

#[starknet::component]
pub mod savings_group_component {
    use super::*;
    use starknet::{get_caller_address, get_block_timestamp, ContractAddress};
    use starkremit_contract::base::errors::GroupErrors;
    use starkremit_contract::base::types::{SavingsGroup};
    use starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, Map, StoragePointerReadAccess, StoragePointerWriteAccess};

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
            self.emit(Event::GroupCreated(GroupCreated {
                group_id,
                creator: caller,
                max_members,
                created_at: group.created_at,
            }));
            group_id
        }
        fn join_group(ref self: ComponentState<TContractState>, group_id: u64) {
            let caller = get_caller_address();
            let group = self.groups.read(group_id);
            assert(group.is_active, GroupErrors::GROUP_NOT_ACTIVE);
            assert(!self.group_members.read((group_id, caller)), GroupErrors::ALREADY_MEMBER);
            self.group_members.write((group_id, caller), true);
            self.emit(Event::MemberJoined(MemberJoined {
                group_id,
                member: caller,
                joined_at: get_block_timestamp(),
            }));
        }
    }

}
