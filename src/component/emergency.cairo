use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct EmergencyConfig {
    pub emergency_cooldown: u64,
    pub required_approvals: u8,
}



#[starknet::interface]
pub trait IEmergency<TContractState> {
    // Configuration and query functions (simple operations)
    fn set_config(ref self: TContractState, cfg: EmergencyConfig);
    fn get_config(self: @TContractState) -> EmergencyConfig;
    fn get_pause_reason(self: @TContractState) -> felt252;
    fn get_pause_timestamp(self: @TContractState) -> u64;
    fn is_paused(self: @TContractState) -> bool;
    fn is_banned(self: @TContractState, member: ContractAddress) -> bool;
    
    // Utility functions (simple operations)
    fn assert_paused(self: @TContractState);
    fn assert_not_paused(self: @TContractState);
}



#[starknet::component]
pub mod emergency_component {
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess, StorageMapReadAccess, StorageMapWriteAccess,
    };
    use super::EmergencyConfig; 
    use starkremit_contract::base::errors::{EmergencyComponentErrors};

    
    #[storage]
    pub struct Storage {
        is_paused: bool,
        pause_reason: felt252,
        pause_timestamp: u64,
        emergency_admin: ContractAddress,
        banned_members: Map<ContractAddress, bool>,
        config: EmergencyConfig,
    }

    
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PauseMetaSet: PauseMetaSet,
        MemberBanned: MemberBanned,
        MemberUnbanned: MemberUnbanned,
        Paused: Paused,
        Unpaused: Unpaused,
        Initialized: Initialized,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PauseMetaSet {
        reason: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MemberBanned {
        member: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MemberUnbanned {
        member: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Paused {
        reason: felt252,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Unpaused {
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Initialized {
        admin: ContractAddress,
    }


    #[embeddable_as(Emergency)]
    impl EmergencyImpl<
        TContractState, +HasComponent<TContractState>,
    > of super::IEmergency<ComponentState<TContractState>> {


        fn get_pause_reason(self: @ComponentState<TContractState>) -> felt252 {
            self.pause_reason.read()
        }

        fn get_pause_timestamp(self: @ComponentState<TContractState>) -> u64 {
            self.pause_timestamp.read()
        }



        fn is_banned(self: @ComponentState<TContractState>, member: ContractAddress) -> bool {
            self.banned_members.read(member)
        }

        fn set_config(ref self: ComponentState<TContractState>, cfg: EmergencyConfig) {
            self._assert_admin(); 
            assert(!self.is_paused.read(), EmergencyComponentErrors::CONTRACT_PAUSED); 
            self.config.write(cfg);
        }

        fn get_config(self: @ComponentState<TContractState>) -> EmergencyConfig {
            self.config.read()
        }

        fn is_paused(self: @ComponentState<TContractState>) -> bool {
            self.is_paused.read()
        }

        fn assert_paused(self: @ComponentState<TContractState>) {
            assert(self.is_paused.read(), EmergencyComponentErrors::CONTRACT_NOT_PAUSED);
        }

        fn assert_not_paused(self: @ComponentState<TContractState>) {
            assert(!self.is_paused.read(), EmergencyComponentErrors::CONTRACT_PAUSED);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            self.emergency_admin.write(admin);
            self.is_paused.write(false); // Component starts unpaused by default
            // Initialize config to default values
            self.config.write(
                EmergencyConfig { emergency_cooldown: 0, required_approvals: 0 }
            );
            self.emit(Event::Initialized(Initialized { admin }));
        }

        // Internal function to assert that the caller is the emergency admin.
        fn _assert_admin(self: @ComponentState<TContractState>) {
            let admin: ContractAddress = self.emergency_admin.read();
            let caller: ContractAddress = get_caller_address();
            assert(caller == admin, EmergencyComponentErrors::NOT_ADMIN);
        }

        // Internal function to toggle the pause state.
        fn _toggle_pause(ref self: ComponentState<TContractState>, paused: bool) {
            self.is_paused.write(paused);
            if paused {
                self.pause_timestamp.write(get_block_timestamp());
            } else {
                self.pause_reason.write(0); // Clear reason on unpause
                self.pause_timestamp.write(0); // Clear timestamp on unpause
            }
        }

        // Complex operations that will be called by the main contract
        fn _pause(ref self: ComponentState<TContractState>) {
            assert(!self.is_paused.read(), EmergencyComponentErrors::ALREADY_PAUSED);
            self._toggle_pause(true);
        }

        fn _unpause(ref self: ComponentState<TContractState>) {
            assert(self.is_paused.read(), EmergencyComponentErrors::CONTRACT_NOT_PAUSED);
            self._toggle_pause(false);
        }

        fn _pause_with_metadata(ref self: ComponentState<TContractState>, reason: felt252) {
            assert(!self.is_paused.read(), EmergencyComponentErrors::ALREADY_PAUSED);
            self.pause_reason.write(reason);
            self.pause_timestamp.write(get_block_timestamp());
            self._toggle_pause(true);
        }

        fn _unpause_with_metadata_clear(ref self: ComponentState<TContractState>) {
            assert(self.is_paused.read(), EmergencyComponentErrors::CONTRACT_NOT_PAUSED);
            self.pause_reason.write(0);
            self.pause_timestamp.write(0);
            self._toggle_pause(false);
        }

        fn _set_pause_meta(ref self: ComponentState<TContractState>, reason: felt252) {
            assert(self.is_paused.read(), EmergencyComponentErrors::CONTRACT_NOT_PAUSED);
            self.pause_reason.write(reason);
            self.pause_timestamp.write(get_block_timestamp());
        }

        fn _set_ban(ref self: ComponentState<TContractState>, member: ContractAddress, banned: bool) {
            assert(!self.is_paused.read(), EmergencyComponentErrors::CONTRACT_PAUSED);
            self.banned_members.write(member, banned);
        }
    }
}