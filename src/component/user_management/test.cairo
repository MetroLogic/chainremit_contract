#[cfg(test)]
mod user_management_tests {
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_block_timestamp_global, start_cheat_caller_address, stop_cheat_caller_address,
    };
    use starknet::{ContractAddress, contract_address_const, get_block_timestamp};
    use starkremit_contract::base::types::{
        KYCLevel, RegistrationRequest, RegistrationStatus, UserProfile,
    };
    use starkremit_contract::component::user_management::user_management::{
        IUserManagementDispatcher, IUserManagementDispatcherTrait, user_management_component,
    };

    pub fn OWNER() -> ContractAddress {
        contract_address_const::<'OWNER'>()
    }

    pub fn ADMIN() -> ContractAddress {
        contract_address_const::<'ADMIN'>()
    }

    pub fn ADMIN2() -> ContractAddress {
        contract_address_const::<'ADMIN'>()
    }

    pub fn USER() -> ContractAddress {
        contract_address_const::<'USER'>()
    }

    pub fn USER2() -> ContractAddress {
        contract_address_const::<'USER2'>()
    }

    pub fn USER3() -> ContractAddress {
        contract_address_const::<'USER3'>()
    }

    pub fn NON_MEMBER() -> ContractAddress {
        contract_address_const::<'NON_MEMBER'>()
    }


    fn deploy_user_management_contract() -> (ContractAddress, IUserManagementDispatcher) {
        let user_management_class_hash = declare("MockUserManagementContract")
            .unwrap()
            .contract_class();
        let mut starkremit_constructor_calldata = array![];
        OWNER().serialize(ref starkremit_constructor_calldata);
        let (contract_address, _) = user_management_class_hash
            .deploy(@starkremit_constructor_calldata)
            .unwrap();

        let user_management_dispatcher = IUserManagementDispatcher {
            contract_address: contract_address,
        };

        (contract_address, user_management_dispatcher)
    }

    #[test]
    fn test_user_registration_success() {
        let (contract_address, user_management_dispatcher) = deploy_user_management_contract();

        let registration_request = RegistrationRequest {
            email_hash: 'akinshola07@gmail.com',
            phone_hash: '090999999',
            full_name: 'Akin Shola',
            country_code: '888',
        };

        let mut spy_events = spy_events();

        let registration_state = user_management_dispatcher.get_registration_state();
        assert(registration_state == true, 'Registration should be enabled');

        start_cheat_caller_address(contract_address, USER());
        user_management_dispatcher.register_user(registration_request);
        stop_cheat_caller_address(contract_address);

        let user_registration_status = user_management_dispatcher.get_registration_status(USER());
        assert(user_registration_status == RegistrationStatus::Completed, 'incorrect status');
        let user_profile = user_management_dispatcher.get_user_profile(USER());

        let expected_user_profile = UserProfile {
            address: USER(),
            user_address: USER(),
            email_hash: registration_request.email_hash,
            phone_hash: registration_request.phone_hash,
            full_name: registration_request.full_name,
            kyc_level: KYCLevel::None,
            registration_timestamp: get_block_timestamp(),
            is_active: true,
            country_code: registration_request.country_code,
        };

        assert(user_profile == expected_user_profile, 'incorrect user profile');
        let email_registry_address = user_management_dispatcher
            .get_email_registry(registration_request.email_hash);
        assert(email_registry_address == USER(), 'incorrect email registry');
        let phone_registry_address = user_management_dispatcher
            .get_phone_registry(registration_request.phone_hash);
        assert(phone_registry_address == USER(), 'incorrect phone registry');
        let total_users = user_management_dispatcher.get_total_users();
        assert(total_users == 1, 'incorrect total users');

        spy_events
            .assert_emitted(
                @array![
                    (
                        contract_address,
                        user_management_component::Event::UserRegistered(
                            user_management_component::UserRegistered {
                                user_address: USER(),
                                email_hash: registration_request.email_hash,
                                registration_timestamp: get_block_timestamp(),
                            },
                        ),
                    ),
                ],
            );
    }

    #[test]
    fn test_update_user_profile_success() {
        let (contract_address, user_management_dispatcher) = deploy_user_management_contract();

        let registration_request = RegistrationRequest {
            email_hash: 'akinshola07@gmail.com',
            phone_hash: '090999999',
            full_name: 'Akin Shola',
            country_code: '888',
        };

        let mut spy_events = spy_events();

        start_cheat_caller_address(contract_address, USER());
        user_management_dispatcher.register_user(registration_request);
        stop_cheat_caller_address(contract_address);

        let mut user_profile = user_management_dispatcher.get_user_profile(USER());

        let expected_user_profile = UserProfile {
            address: USER(),
            user_address: USER(),
            email_hash: registration_request.email_hash,
            phone_hash: registration_request.phone_hash,
            full_name: registration_request.full_name,
            kyc_level: KYCLevel::None,
            registration_timestamp: get_block_timestamp(),
            is_active: true,
            country_code: registration_request.country_code,
        };

        assert(user_profile == expected_user_profile, 'incorrect user profile');

        let updated_user_profile = UserProfile {
            address: USER(),
            user_address: USER(),
            email_hash: 'mynewemail@gmail.com',
            phone_hash: '09123456789',
            full_name: 'Akin Shola Updated',
            kyc_level: KYCLevel::None,
            registration_timestamp: get_block_timestamp(),
            is_active: true,
            country_code: '999',
        };

        start_cheat_caller_address(contract_address, USER());
        user_management_dispatcher.update_user_profile(updated_user_profile);
        stop_cheat_caller_address(contract_address);

        let email_registry_address = user_management_dispatcher
            .get_email_registry('mynewemail@gmail.com');
        assert(email_registry_address == USER(), 'incorrect email registry');

        let phone_registry_address = user_management_dispatcher.get_phone_registry('09123456789');
        assert(phone_registry_address == USER(), 'incorrect phone registry');

        let new_user_profile = user_management_dispatcher.get_user_profile(USER());
        assert(new_user_profile == updated_user_profile, 'incorrect user profile');

        spy_events
            .assert_emitted(
                @array![
                    (
                        contract_address,
                        user_management_component::Event::UserProfileUpdated(
                            user_management_component::UserProfileUpdated {
                                user_address: USER(),
                                updated_fields: " email phone full_name country_code",
                            },
                        ),
                    ),
                ],
            )
    }

    #[test]
    fn test_successful_deactivate_user() {
        let (contract_address, user_management_dispatcher) = deploy_user_management_contract();

        let registration_request = RegistrationRequest {
            email_hash: 'akinshola07@gmail.com',
            phone_hash: '090999999',
            full_name: 'Akin Shola',
            country_code: '888',
        };

        let mut spy_events = spy_events();

        let registration_state = user_management_dispatcher.get_registration_state();
        assert(registration_state == true, 'Registration should be enabled');

        start_cheat_caller_address(contract_address, USER());
        user_management_dispatcher.register_user(registration_request);
        stop_cheat_caller_address(contract_address);

        let user_registration_status = user_management_dispatcher.get_registration_status(USER());
        assert(user_registration_status == RegistrationStatus::Completed, 'incorrect status');
        let mut user_profile = user_management_dispatcher.get_user_profile(USER());
        assert(user_profile.is_active, 'incorrect user active status');

        start_cheat_caller_address(contract_address, OWNER());
        user_management_dispatcher.add_user_admin(ADMIN());
        stop_cheat_caller_address(contract_address);

        start_cheat_caller_address(contract_address, ADMIN());
        user_management_dispatcher.deactivate_user(USER());
        stop_cheat_caller_address(contract_address);

        let mut user_profile = user_management_dispatcher.get_user_profile(USER());
        assert(!user_profile.is_active, 'incorrect user active status');

        let registration_status = user_management_dispatcher.get_registration_status(USER());
        assert(registration_status == RegistrationStatus::Suspended, 'incorrect status');

        spy_events
            .assert_emitted(
                @array![
                    (
                        contract_address,
                        user_management_component::Event::UserDeactivated(
                            user_management_component::UserDeactivated {
                                user_address: USER(), admin: ADMIN(),
                            },
                        ),
                    ),
                ],
            )
    }


    #[test]
    fn test_successful_reactivate_user() {
        let (contract_address, user_management_dispatcher) = deploy_user_management_contract();

        let registration_request = RegistrationRequest {
            email_hash: 'akinshola07@gmail.com',
            phone_hash: '090999999',
            full_name: 'Akin Shola',
            country_code: '888',
        };

        let mut spy_events = spy_events();

        let registration_state = user_management_dispatcher.get_registration_state();
        assert(registration_state == true, 'Registration should be enabled');

        start_cheat_caller_address(contract_address, USER());
        user_management_dispatcher.register_user(registration_request);
        stop_cheat_caller_address(contract_address);

        let user_registration_status = user_management_dispatcher.get_registration_status(USER());
        assert(user_registration_status == RegistrationStatus::Completed, 'incorrect status');
        let mut user_profile = user_management_dispatcher.get_user_profile(USER());
        assert(user_profile.is_active, 'incorrect user active status');

        start_cheat_caller_address(contract_address, OWNER());
        user_management_dispatcher.add_user_admin(ADMIN());
        stop_cheat_caller_address(contract_address);

        start_cheat_caller_address(contract_address, ADMIN());
        user_management_dispatcher.deactivate_user(USER());
        stop_cheat_caller_address(contract_address);

        user_profile = user_management_dispatcher.get_user_profile(USER());
        assert(!user_profile.is_active, 'user should be inactive');

        let registration_status = user_management_dispatcher.get_registration_status(USER());
        assert(registration_status == RegistrationStatus::Suspended, 'incorrect status');

        start_cheat_caller_address(contract_address, ADMIN());
        user_management_dispatcher.reactivate_user(USER());
        stop_cheat_caller_address(contract_address);

        let registration_status = user_management_dispatcher.get_registration_status(USER());
        assert(registration_status == RegistrationStatus::Completed, 'incorrect status');

        spy_events
            .assert_emitted(
                @array![
                    (
                        contract_address,
                        user_management_component::Event::UserReactivated(
                            user_management_component::UserReactivated {
                                user_address: USER(), admin: ADMIN(),
                            },
                        ),
                    ),
                ],
            )
    }

    #[test]
    fn test_add_user_admin() {
        let (contract_address, user_management_dispatcher) = deploy_user_management_contract();

        let mut spy_events = spy_events();

        start_cheat_caller_address(contract_address, OWNER());
        user_management_dispatcher.add_user_admin(ADMIN());
        stop_cheat_caller_address(contract_address);

        let admin_status = user_management_dispatcher.get_admin_status(ADMIN());
        assert(admin_status, 'Admin should be added');

        let list_of_admins: Array<ContractAddress> = user_management_dispatcher.get_admins();
        assert(list_of_admins.len() == 1, 'Admin should be in the list');
        assert(*list_of_admins.at(0) == ADMIN(), 'Admin address is incorrect');

        spy_events
            .assert_emitted(
                @array![
                    (
                        contract_address,
                        user_management_component::Event::UserAdminAdded(
                            user_management_component::UserAdminAdded {
                                admin: ADMIN(), timestamp: get_block_timestamp(),
                            },
                        ),
                    ),
                ],
            )
    }

    #[test]
    fn test_remove_user_admin() {
        let (contract_address, user_management_dispatcher) = deploy_user_management_contract();

        let mut spy_events = spy_events();

        start_cheat_caller_address(contract_address, OWNER());
        user_management_dispatcher.add_user_admin(ADMIN());
        stop_cheat_caller_address(contract_address);

        start_cheat_caller_address(contract_address, OWNER());
        user_management_dispatcher.add_user_admin(ADMIN2());
        stop_cheat_caller_address(contract_address);

        let admin_status = user_management_dispatcher.get_admin_status(ADMIN());
        assert(admin_status, 'Admin should be added');

        let list_of_admins: Array<ContractAddress> = user_management_dispatcher.get_admins();
        assert(list_of_admins.len() == 2, 'Admin should be in the list');
        assert(*list_of_admins.at(0) == ADMIN(), 'Admin address is incorrect');
        assert(*list_of_admins.at(1) == ADMIN2(), 'Admin2 address is incorrect');

        start_cheat_caller_address(contract_address, OWNER());
        user_management_dispatcher.remove_user_admin(ADMIN());
        stop_cheat_caller_address(contract_address);

        let admin_status = user_management_dispatcher.get_admin_status(ADMIN());
        assert(!admin_status, 'Admin should be removed');

        let list_of_admins: Array<ContractAddress> = user_management_dispatcher.get_admins();
        assert(list_of_admins.len() == 0, 'Admin should not be in the list');

        spy_events
            .assert_emitted(
                @array![
                    (
                        contract_address,
                        user_management_component::Event::UserAdminRemoved(
                            user_management_component::UserAdminRemoved {
                                removed_admin: ADMIN(),
                                new_admin_array: array![],
                                timestamp: get_block_timestamp(),
                            },
                        ),
                    ),
                ],
            )
    }

    #[test]
    fn test_pause_registration() {
        let (contract_address, user_management_dispatcher) = deploy_user_management_contract();

        let mut spy_events = spy_events();

        start_cheat_caller_address(contract_address, OWNER());
        user_management_dispatcher.pause_registration();
        stop_cheat_caller_address(contract_address);

        let registration_state = user_management_dispatcher.get_registration_state();
        assert(!registration_state, 'Registration should be paused');

        spy_events
            .assert_emitted(
                @array![
                    (
                        contract_address,
                        user_management_component::Event::RegistrationPaused(
                            user_management_component::RegistrationPaused {
                                timestamp: get_block_timestamp(),
                            },
                        ),
                    ),
                ],
            )
    }


    #[test]
    fn test_resume_registration() {
        let (contract_address, user_management_dispatcher) = deploy_user_management_contract();

        let mut spy_events = spy_events();

        start_cheat_caller_address(contract_address, OWNER());
        user_management_dispatcher.pause_registration();
        stop_cheat_caller_address(contract_address);

        let registration_state = user_management_dispatcher.get_registration_state();
        assert(!registration_state, 'Registration should be paused');

        start_cheat_caller_address(contract_address, OWNER());
        user_management_dispatcher.resume_registration();
        stop_cheat_caller_address(contract_address);

        let registration_state = user_management_dispatcher.get_registration_state();
        assert(registration_state, 'Registration should resume');

        spy_events
            .assert_emitted(
                @array![
                    (
                        contract_address,
                        user_management_component::Event::RegistrationResumed(
                            user_management_component::RegistrationResumed {
                                timestamp: get_block_timestamp(),
                            },
                        ),
                    ),
                ],
            )
    }

    #[test]
    fn test_update_kyc_level_success() {
        let (contract_address, user_management_dispatcher) = deploy_user_management_contract();

        let registration_request = RegistrationRequest {
            email_hash: 'akinshola07@gmail.com',
            phone_hash: '090999999',
            full_name: 'Akin Shola',
            country_code: '888',
        };

        let mut spy_events = spy_events();

        let registration_state = user_management_dispatcher.get_registration_state();
        assert(registration_state == true, 'Registration should be enabled');

        start_cheat_caller_address(contract_address, USER());
        user_management_dispatcher.register_user(registration_request);
        stop_cheat_caller_address(contract_address);

        start_cheat_caller_address(contract_address, OWNER());
        user_management_dispatcher.add_user_admin(ADMIN());
        stop_cheat_caller_address(contract_address);

        start_cheat_caller_address(contract_address, ADMIN());
        user_management_dispatcher.update_user_kyc(USER(), KYCLevel::Advanced);
        stop_cheat_caller_address(contract_address);

        let kyc_level = user_management_dispatcher.get_user_kyc_level(ADMIN());
        assert(kyc_level == KYCLevel::Advanced, 'KYC level should be updated');

        spy_events
            .assert_emitted(
                @array![
                    (
                        contract_address,
                        user_management_component::Event::UserKYCUpdated(
                            user_management_component::UserKYCUpdated {
                                user_address: USER(),
                                new_kyc_level: KYCLevel::Advanced,
                                timestamp: get_block_timestamp(),
                            },
                        ),
                    ),
                ],
            )
    }
}

