#[cfg(test)]
mod contribution_tests {
    // OZ imports
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    // snforge imports
    use snforge_std::{
        ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp_global,
        start_cheat_caller_address, stop_cheat_caller_address,
    };

    // starknet imports
    use starknet::{ContractAddress, contract_address_const};
    use starkremit_contract::component::contribution::contribution::{
        IContributionDispatcher, IContributionDispatcherTrait,
    };
    use starkremit_contract::interfaces::IERC20::{
        IERC20MintableDispatcher, IERC20MintableDispatcherTrait,
    };

    pub fn OWNER() -> ContractAddress {
        contract_address_const::<'OWNER'>()
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

    // *************************************************************************
    //                              SETUP
    // *************************************************************************
    fn __setup__() -> (ContractAddress, IContributionDispatcher, IERC20Dispatcher) {
        let strk_token_name: ByteArray = "STARKNET_TOKEN";

        let strk_token_symbol: ByteArray = "STRK";

        let decimals: u8 = 18;

        let erc20_class_hash = declare("ERC20Upgradeable").unwrap().contract_class();
        let mut strk_constructor_calldata = array![];
        strk_token_name.serialize(ref strk_constructor_calldata);
        strk_token_symbol.serialize(ref strk_constructor_calldata);
        decimals.serialize(ref strk_constructor_calldata);
        OWNER().serialize(ref strk_constructor_calldata);

        let (strk_contract_address, _) = erc20_class_hash
            .deploy(@strk_constructor_calldata)
            .unwrap();

        let strk_mintable_dispatcher = IERC20MintableDispatcher {
            contract_address: strk_contract_address,
        };
        start_cheat_caller_address(strk_contract_address, OWNER());
        strk_mintable_dispatcher.mint(USER(), 1_000_000_000_000_000_000);
        strk_mintable_dispatcher.mint(USER2(), 1_000_000_000_000_000_000);
        strk_mintable_dispatcher.mint(USER3(), 1_000_000_000_000_000_000);
        stop_cheat_caller_address(strk_contract_address);

        let ierc20_dispatcher = IERC20Dispatcher { contract_address: strk_contract_address };

        let (contrib_contract, contrib_dispatcher) = deploy_contrib_contract(strk_contract_address);

        return (contrib_contract, contrib_dispatcher, ierc20_dispatcher);
    }


    fn deploy_contrib_contract(
        token_address: ContractAddress,
    ) -> (ContractAddress, IContributionDispatcher) {
        let contrib_class_hash = declare("MockContributionContract").unwrap().contract_class();
        let mut starkremit_constructor_calldata = array![];
        OWNER().serialize(ref starkremit_constructor_calldata);
        token_address.serialize(ref starkremit_constructor_calldata);
        let (contract_address, _) = contrib_class_hash
            .deploy(@starkremit_constructor_calldata)
            .unwrap();

        let contrib_dispatcher = IContributionDispatcher { contract_address: contract_address };

        (contract_address, contrib_dispatcher)
    }

    // *************************************************************************
    //                              MEMBER MANAGEMENT TESTS
    // *************************************************************************

    #[test]
    fn test_add_member_success() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        stop_cheat_caller_address(contrib_contract);

        assert!(contrib_dispatcher.is_member(USER()), "User should be a member");

        let members = contrib_dispatcher.get_all_members();
        assert!(members.len() == 1, "Should have 1 member");
        assert!(*members[0] == USER(), "Member should be USER");
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn test_add_member_not_owner() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, USER());
        contrib_dispatcher.add_member(USER2());
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Invalid address',))]
    fn test_add_member_zero_address() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(contract_address_const::<0>());
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Already a member',))]
    fn test_add_member_already_exists() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.add_member(USER());
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    fn test_remove_member_success() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.add_member(USER2());
        contrib_dispatcher.add_member(USER3());

        assert!(contrib_dispatcher.is_member(USER2()), "USER2 should be a member");

        contrib_dispatcher.remove_member(USER2());

        assert!(!contrib_dispatcher.is_member(USER2()), "USER2 should not be a member");

        let members = contrib_dispatcher.get_all_members();
        assert!(members.len() == 2, "Should have 2 members after removal");
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn test_remove_member_not_owner() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        stop_cheat_caller_address(contrib_contract);

        start_cheat_caller_address(contrib_contract, USER());
        contrib_dispatcher.remove_member(USER());
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Not a member',))]
    fn test_remove_member_not_exists() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.remove_member(USER());
        stop_cheat_caller_address(contrib_contract);
    }

    // *************************************************************************
    //                              CONFIGURATION TESTS
    // *************************************************************************

    #[test]
    fn test_set_required_contribution() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        let new_amount = 1000;

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.set_required_contribution(new_amount);
        stop_cheat_caller_address(contrib_contract);

        let stored_amount = contrib_dispatcher.get_required_contribution();
        assert!(stored_amount == new_amount, "Required contribution should be updated");
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn test_set_required_contribution_not_owner() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, USER());
        contrib_dispatcher.set_required_contribution(1000);
        stop_cheat_caller_address(contrib_contract);
    }

    // *************************************************************************
    //                              ROUND MANAGEMENT TESTS
    // *************************************************************************

    #[test]
    fn test_add_round_to_schedule_success() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());

        let future_deadline = 1000000000; // Future timestamp
        start_cheat_block_timestamp_global(999999990);

        contrib_dispatcher.add_round_to_schedule(USER(), future_deadline);

        let round_id = contrib_dispatcher.get_current_round_id();
        assert!(round_id == 1, "Round ID should be 1");

        let round_details = contrib_dispatcher.get_round_details(round_id);
        assert!(round_details.recipient == USER(), "Recipient should be USER");
        assert!(round_details.deadline == future_deadline, "Deadline should match");
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn test_add_round_to_schedule_not_owner() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        stop_cheat_caller_address(contrib_contract);

        start_cheat_caller_address(contrib_contract, USER());
        contrib_dispatcher.add_round_to_schedule(USER(), 1000000000);
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Recipient must be a member',))]
    fn test_add_round_to_schedule_recipient_not_member() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_round_to_schedule(NON_MEMBER(), 1000000000);
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Deadline not in the future',))]
    fn test_add_round_to_schedule_past_deadline() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());

        start_cheat_block_timestamp_global(1000000000);
        contrib_dispatcher.add_round_to_schedule(USER(), 999999999); // Past deadline
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    fn test_complete_round_success() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.add_round_to_schedule(USER(), 1000000000);

        let round_id = contrib_dispatcher.get_current_round_id();
        contrib_dispatcher.complete_round(round_id);

        let round_details = contrib_dispatcher.get_round_details(round_id);
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn test_complete_round_not_owner() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.add_round_to_schedule(USER(), 1000000000);
        let round_id = contrib_dispatcher.get_current_round_id();
        stop_cheat_caller_address(contrib_contract);

        start_cheat_caller_address(contrib_contract, USER());
        contrib_dispatcher.complete_round(round_id);
        stop_cheat_caller_address(contrib_contract);
    }

    // *************************************************************************
    //                              CONTRIBUTION TESTS
    // *************************************************************************

    #[test]
    fn test_contribute_round_success() {
        let (contrib_contract, contrib_dispatcher, ierc20_dispatcher) = __setup__();

        let contribution_amount = 100;

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.set_required_contribution(contribution_amount);
        contrib_dispatcher.add_round_to_schedule(USER(), 2000000000);
        stop_cheat_caller_address(contrib_contract);

        let round_id = contrib_dispatcher.get_current_round_id();

        // Approve tokens for transfer
        start_cheat_caller_address(ierc20_dispatcher.contract_address, USER());
        ierc20_dispatcher.approve(contrib_contract, contribution_amount);
        stop_cheat_caller_address(ierc20_dispatcher.contract_address);

        start_cheat_caller_address(contrib_contract, USER());
        start_cheat_block_timestamp_global(1000000000);
        contrib_dispatcher.contribute_round(round_id, contribution_amount);
        stop_cheat_caller_address(contrib_contract);

        let contribution = contrib_dispatcher.get_member_contribution(round_id, USER());
        assert!(contribution.amount == contribution_amount, "Contribution amount should match");
        assert!(contribution.member == USER(), "Contributor should be USER");

        let round_details = contrib_dispatcher.get_round_details(round_id);
        assert!(
            round_details.total_contributions == contribution_amount,
            "Total contributions should match",
        );
    }

    #[test]
    #[should_panic(expected: ('Caller is not a member',))]
    fn test_contribute_round_not_member() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.add_round_to_schedule(USER(), 2000000000);
        stop_cheat_caller_address(contrib_contract);

        let round_id = contrib_dispatcher.get_current_round_id();

        start_cheat_caller_address(contrib_contract, NON_MEMBER());
        contrib_dispatcher.contribute_round(round_id, 1000);
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Already contributed',))]
    fn test_contribute_round_double_contribution() {
        let (contrib_contract, contrib_dispatcher, ierc20_dispatcher) = __setup__();

        let contribution_amount = 1000;

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.set_required_contribution(contribution_amount);
        contrib_dispatcher.add_round_to_schedule(USER(), 2000000000);
        stop_cheat_caller_address(contrib_contract);

        let round_id = contrib_dispatcher.get_current_round_id();

        start_cheat_caller_address(ierc20_dispatcher.contract_address, USER());
        ierc20_dispatcher.approve(contrib_contract, contribution_amount * 2);
        stop_cheat_caller_address(ierc20_dispatcher.contract_address);

        start_cheat_caller_address(contrib_contract, USER());
        start_cheat_block_timestamp_global(1000000000);
        contrib_dispatcher.contribute_round(round_id, contribution_amount);
        contrib_dispatcher.contribute_round(round_id, contribution_amount);
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('amount less than required',))]
    fn test_contribute_round_insufficient_amount() {
        let (contrib_contract, contrib_dispatcher, ierc20_dispatcher) = __setup__();

        let required_amount = 1000;
        let insufficient_amount = 500;

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.set_required_contribution(required_amount);
        contrib_dispatcher.add_round_to_schedule(USER(), 2000000000);
        stop_cheat_caller_address(contrib_contract);

        let round_id = contrib_dispatcher.get_current_round_id();

        start_cheat_caller_address(ierc20_dispatcher.contract_address, USER());
        ierc20_dispatcher.approve(contrib_contract, insufficient_amount);
        stop_cheat_caller_address(contrib_contract);

        start_cheat_caller_address(contrib_contract, USER());
        start_cheat_block_timestamp_global(1000000000);
        contrib_dispatcher.contribute_round(round_id, insufficient_amount);
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Contribution deadline passed',))]
    fn test_contribute_round_deadline_passed() {
        let (contrib_contract, contrib_dispatcher, ierc20_dispatcher) = __setup__();

        let contribution_amount = 1000;
        let deadline = 1500000000;

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.set_required_contribution(contribution_amount);
        contrib_dispatcher.add_round_to_schedule(USER(), deadline);
        stop_cheat_caller_address(contrib_contract);

        let round_id = contrib_dispatcher.get_current_round_id();

        start_cheat_caller_address(ierc20_dispatcher.contract_address, USER());
        ierc20_dispatcher.approve(contrib_contract, contribution_amount);
        stop_cheat_caller_address(ierc20_dispatcher.contract_address);

        start_cheat_caller_address(contrib_contract, USER());
        start_cheat_block_timestamp_global(deadline + 1); // After deadline
        contrib_dispatcher.contribute_round(round_id, contribution_amount);
        stop_cheat_caller_address(contrib_contract);
    }

    // *************************************************************************
    //                              DISBURSEMENT TESTS
    // *************************************************************************

    #[test]
    fn test_disburse_round_contribution_success() {
        let (contrib_contract, contrib_dispatcher, ierc20_dispatcher) = __setup__();

        let contribution_amount = 1000;

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.add_member(USER2());
        contrib_dispatcher.set_required_contribution(contribution_amount);
        contrib_dispatcher.add_round_to_schedule(USER2(), 2000000000);

        let round_id = contrib_dispatcher.get_current_round_id();
        stop_cheat_caller_address(contrib_contract);

        // USER contributes
        start_cheat_caller_address(ierc20_dispatcher.contract_address, USER());
        ierc20_dispatcher.approve(contrib_contract, contribution_amount);
        stop_cheat_caller_address(ierc20_dispatcher.contract_address);

        start_cheat_caller_address(contrib_contract, USER());
        start_cheat_block_timestamp_global(1000000000);
        contrib_dispatcher.contribute_round(round_id, contribution_amount);
        stop_cheat_caller_address(contrib_contract);

        // Complete and disburse round
        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.complete_round(round_id);

        let recipient_balance_before = ierc20_dispatcher.balance_of(USER2());
        contrib_dispatcher.disburse_round_contribution(round_id);
        let recipient_balance_after = ierc20_dispatcher.balance_of(USER2());

        assert!(
            recipient_balance_after - recipient_balance_before == contribution_amount,
            "Recipient should receive the contribution amount",
        );
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn test_disburse_round_contribution_not_owner() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.add_round_to_schedule(USER(), 2000000000);
        let round_id = contrib_dispatcher.get_current_round_id();
        contrib_dispatcher.complete_round(round_id);
        stop_cheat_caller_address(contrib_contract);

        start_cheat_caller_address(contrib_contract, USER());
        contrib_dispatcher.disburse_round_contribution(round_id);
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    #[should_panic(expected: ('Round not completed',))]
    fn test_disburse_round_contribution_not_completed() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.add_round_to_schedule(USER(), 2000000000);
        let round_id = contrib_dispatcher.get_current_round_id();

        contrib_dispatcher.disburse_round_contribution(round_id);
        stop_cheat_caller_address(contrib_contract);
    }

    // *************************************************************************
    //                              GETTER FUNCTION TESTS
    // *************************************************************************

    #[test]
    fn test_get_current_round_id() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        assert!(contrib_dispatcher.get_current_round_id() == 0, "Initial round ID should be 0");

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.add_round_to_schedule(USER(), 2000000000);

        assert!(
            contrib_dispatcher.get_current_round_id() == 1,
            "Round ID should be 1 after adding round",
        );
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    fn test_get_round_details() {
        let (contrib_contract, contrib_dispatcher, _) = __setup__();

        let deadline = 2000000000;

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.add_round_to_schedule(USER(), deadline);

        let round_id = contrib_dispatcher.get_current_round_id();
        let round_details = contrib_dispatcher.get_round_details(round_id);

        assert!(round_details.round_id == round_id, "Round ID should match");
        assert!(round_details.recipient == USER(), "Recipient should be USER");
        assert!(round_details.deadline == deadline, "Deadline should match");
        assert!(round_details.total_contributions == 0, "Initial contributions should be 0");
        stop_cheat_caller_address(contrib_contract);
    }

    #[test]
    fn test_get_member_contribution() {
        let (contrib_contract, contrib_dispatcher, ierc20_dispatcher) = __setup__();

        let contribution_amount = 1000;

        start_cheat_caller_address(contrib_contract, OWNER());
        contrib_dispatcher.add_member(USER());
        contrib_dispatcher.set_required_contribution(contribution_amount);
        contrib_dispatcher.add_round_to_schedule(USER(), 2000000000);
        stop_cheat_caller_address(contrib_contract);

        let round_id = contrib_dispatcher.get_current_round_id();

        // Check initial contribution (should be empty)
        let initial_contribution = contrib_dispatcher.get_member_contribution(round_id, USER());
        assert!(initial_contribution.amount == 0, "Initial contribution should be 0");

        // Make contribution
        start_cheat_caller_address(ierc20_dispatcher.contract_address, USER());
        ierc20_dispatcher.approve(contrib_contract, contribution_amount);
        stop_cheat_caller_address(ierc20_dispatcher.contract_address);

        start_cheat_caller_address(contrib_contract, USER());
        start_cheat_block_timestamp_global(1000000000);
        contrib_dispatcher.contribute_round(round_id, contribution_amount);
        stop_cheat_caller_address(contrib_contract);

        // Check contribution after making it
        let final_contribution = contrib_dispatcher.get_member_contribution(round_id, USER());
        assert!(
            final_contribution.amount == contribution_amount, "Contribution amount should match",
        );
        assert!(final_contribution.member == USER(), "Contributor should be USER");
        assert!(
            final_contribution.contributed_at == 1000000000, "Contribution timestamp should match",
        );
    }
}
