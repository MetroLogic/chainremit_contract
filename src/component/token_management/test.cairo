#[cfg(test)]
mod token_management_tests {
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use starknet::{ContractAddress, contract_address_const};
    use starkremit_contract::component::token_management::token_management::{
        ITokenManagementDispatcher, ITokenManagementDispatcherTrait,
    };

    pub fn OWNER() -> ContractAddress {
        contract_address_const::<'OWNER'>()
    }

    pub fn MINTER() -> ContractAddress {
        contract_address_const::<'MINTER'>()
    }

    pub fn USER() -> ContractAddress {
        contract_address_const::<'USER'>()
    }

    pub fn NEW_OWNER() -> ContractAddress {
        contract_address_const::<'NEW_OWNER'>()
    }

    fn deploy_mock_contract() -> ContractAddress {
        let contract_class = declare("MockTokenMGTContract").unwrap().contract_class();
        let mut constructor_calldata = array![];
        'token'.serialize(ref constructor_calldata);
        'TK'.serialize(ref constructor_calldata);
        OWNER().serialize(ref constructor_calldata);
        let (contract_address, _) = contract_class.deploy(@constructor_calldata).unwrap();
        contract_address
    }

    // Only owner can add minters
    #[test]
    fn test_only_owner_can_add_minter() {
        let contract_address = deploy_mock_contract();
        let dispatcher = ITokenManagementDispatcher { contract_address };

        // Owner should be able to add minter
        start_cheat_caller_address(contract_address, OWNER());
        let result = dispatcher.add_minter(MINTER());
        assert!(result, "Owner should be able to add minter");
        assert!(dispatcher.is_minter(MINTER()), "Minter should be added");
        stop_cheat_caller_address(contract_address);
    }

    #[test]
    #[should_panic(expected: ('Token: caller is not owner',))]
    fn test_non_owner_cannot_add_minter() {
        let contract_address = deploy_mock_contract();
        let dispatcher = ITokenManagementDispatcher { contract_address };

        // Non-owner should not be able to add minter
        start_cheat_caller_address(contract_address, USER());
        dispatcher.add_minter(MINTER());
        stop_cheat_caller_address(contract_address);
    }

    #[test]
    fn test_only_owner_can_remove_minter() {
        let contract_address = deploy_mock_contract();
        let dispatcher = ITokenManagementDispatcher { contract_address };

        // First add a minter
        start_cheat_caller_address(contract_address, OWNER());
        dispatcher.add_minter(MINTER());

        // Owner should be able to remove minter
        let result = dispatcher.remove_minter(MINTER());
        assert!(result, "Owner should be able to remove minter");
        assert!(!dispatcher.is_minter(MINTER()), "Minter should be removed");
        stop_cheat_caller_address(contract_address);
    }

    #[test]
    fn test_only_owner_can_set_max_supply() {
        let contract_address = deploy_mock_contract();
        let dispatcher = ITokenManagementDispatcher { contract_address };

        start_cheat_caller_address(contract_address, OWNER());
        let result = dispatcher.set_max_supply(2000000);
        assert!(result, "Owner should be able to set max supply");
        assert!(dispatcher.get_max_supply() == 2000000, "Max supply should be updated");
        stop_cheat_caller_address(contract_address);
    }

    #[test]
    fn test_unlimited_allowance_support() {
        let contract_address = deploy_mock_contract();
        let dispatcher = ITokenManagementDispatcher { contract_address };

        // Setup: Add minter and mint tokens to USER
        start_cheat_caller_address(contract_address, OWNER());
        dispatcher.add_minter(OWNER());
        stop_cheat_caller_address(contract_address);

        start_cheat_caller_address(contract_address, OWNER());
        dispatcher.mint(USER(), 1000);
        stop_cheat_caller_address(contract_address);

        // Set unlimited allowance (max u256)
        let unlimited_allowance =
            0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
        start_cheat_caller_address(contract_address, USER());
        dispatcher.approve(MINTER(), unlimited_allowance);
        stop_cheat_caller_address(contract_address);

        // Transfer should work without reducing allowance
        start_cheat_caller_address(contract_address, MINTER());
        let result = dispatcher.transfer_from(USER(), OWNER(), 100);
        assert!(result, "Transfer from should work with unlimited allowance");

        // Allowance should still be unlimited
        let remaining_allowance = dispatcher.allowance(USER(), MINTER());
        assert!(remaining_allowance == unlimited_allowance, "Allowance should remain unlimited");
        stop_cheat_caller_address(contract_address);
    }

    #[test]
    fn test_unlimited_max_supply() {
        let contract_address = deploy_mock_contract();
        let dispatcher = ITokenManagementDispatcher { contract_address };

        // Set max supply to 0 (unlimited)
        start_cheat_caller_address(contract_address, OWNER());
        dispatcher.set_max_supply(0);
        dispatcher.add_minter(OWNER());

        // Should be able to mint beyond original max supply
        let result = dispatcher.mint(USER(), 2000000); // More than original 1M max
        assert!(result, "Should be able to mint unlimited when max_supply is 0");
        stop_cheat_caller_address(contract_address);
    }

    #[test]
    fn test_correct_ownership_transfer() {
        let contract_address = deploy_mock_contract();
        let dispatcher = ITokenManagementDispatcher { contract_address };
        let mut spy = spy_events();

        start_cheat_caller_address(contract_address, OWNER());
        let result = dispatcher.transfer_ownership(NEW_OWNER());
        assert!(result, "Ownership transfer should succeed");
        assert!(dispatcher.get_owner() == NEW_OWNER(), "New owner should be set");
        stop_cheat_caller_address(contract_address);
    }

    #[test]
    fn test_no_duplicate_transfer_logic() {
        let contract_address = deploy_mock_contract();
        let dispatcher = ITokenManagementDispatcher { contract_address };

        // Setup: Mint tokens to OWNER
        start_cheat_caller_address(contract_address, OWNER());
        dispatcher.add_minter(OWNER());
        dispatcher.mint(OWNER(), 1000);

        let initial_balance = dispatcher.balance_of(OWNER());
        let initial_user_balance = dispatcher.balance_of(USER());

        // Transfer tokens
        let result = dispatcher.transfer(USER(), 100);
        assert!(result, "Transfer should succeed");

        // Verify balances are correctly updated
        let final_balance = dispatcher.balance_of(OWNER());
        let final_user_balance = dispatcher.balance_of(USER());

        assert!(
            final_balance == initial_balance - 100,
            "Sender balance should decrease by exact amount",
        );
        assert!(
            final_user_balance == initial_user_balance + 100,
            "Recipient balance should increase by exact amount",
        );
        stop_cheat_caller_address(contract_address);
    }

    #[test]
    #[should_panic(expected: ('SetMaxSupply: too low',))]
    fn test_max_supply_cannot_be_below_current_supply() {
        let contract_address = deploy_mock_contract();
        let dispatcher = ITokenManagementDispatcher { contract_address };

        start_cheat_caller_address(contract_address, OWNER());
        dispatcher.add_minter(OWNER());
        dispatcher.mint(USER(), 1000);

        // Try to set max supply below current supply
        dispatcher.set_max_supply(500); // Should fail since current supply is 1000
        stop_cheat_caller_address(contract_address);
    }
}
