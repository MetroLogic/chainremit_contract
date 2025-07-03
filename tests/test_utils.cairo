// // *************************************************************************
// //                              TEST
// // *************************************************************************
// // core imports
// use core::result::ResultTrait;

// // OZ imports
// use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// // snforge imports
// use snforge_std::{
//     ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
//     start_cheat_block_timestamp, start_cheat_caller_address_global,
//     stop_cheat_caller_address_global,
// };

// // starknet imports
// use starknet::{ContractAddress, contract_address_const};

// // starkremit imports
// use starkremit_contract::base::errors::*;
// use starkremit_contract::base::events::*;
// use starkremit_contract::base::types::*;
// use starkremit_contract::interfaces::IERC20::{
//     IERC20MintableDispatcher, IERC20MintableDispatcherTrait,
// };
// use starkremit_contract::interfaces::IStarkRemit::{
//     IStarkRemitDispatcher, IStarkRemitDispatcherTrait,
// };

// pub fn OWNER() -> ContractAddress {
//     contract_address_const::<'OWNER'>()
// }
// pub fn TOKEN_ADDRESS() -> ContractAddress {
//     contract_address_const::<'TOKEN_ADDRESS'>()
// }

// pub fn ORACLE_ADDRESS() -> ContractAddress {
//     contract_address_const::<0x2a85bd616f912537c50a49a4076db02c00b29b2cdc8a197ce92ed1837fa875b>()
// }

// pub fn USER() -> ContractAddress {
//     contract_address_const::<'USER'>()
// }

// // *************************************************************************
// //                              SETUP
// // *************************************************************************
// // return istrkremit contract address,
// fn __setup__() -> (ContractAddress, IStarkRemitDispatcher, IERC20Dispatcher) {
//     let strk_token_name: ByteArray = "STARKNET_TOKEN";

//     let strk_token_symbol: ByteArray = "STRK";

//     let decimals: u8 = 18;

//     let erc20_class_hash = declare("ERC20Upgradeable").unwrap().contract_class();
//     let mut strk_constructor_calldata = array![];
//     strk_token_name.serialize(ref strk_constructor_calldata);
//     strk_token_symbol.serialize(ref strk_constructor_calldata);
//     decimals.serialize(ref strk_constructor_calldata);
//     OWNER().serialize(ref strk_constructor_calldata);

//     let (strk_contract_address, _) =
//     erc20_class_hash.deploy(@strk_constructor_calldata).unwrap();

//     let strk_mintable_dispatcher = IERC20MintableDispatcher {
//         contract_address: strk_contract_address,
//     };
//     start_cheat_caller_address_global(OWNER());
//     strk_mintable_dispatcher.mint(USER(), 1_000_000_000_000_000_000);
//     stop_cheat_caller_address_global();

//     let ierc20_dispatcher = IERC20Dispatcher { contract_address: strk_contract_address };

//     let (starkremit_contract_address, starkremit_dispatcher) = deploy_starkremit_contract();

//     return (starkremit_contract_address, starkremit_dispatcher, ierc20_dispatcher);
// }

// fn deploy_starkremit_contract() -> (ContractAddress, IStarkRemitDispatcher) {
//     let starkremit_class_hash = declare("StarkRemit").unwrap().contract_class();
//     let mut starkremit_constructor_calldata = array![];
//     OWNER().serialize(ref starkremit_constructor_calldata);
//     ORACLE_ADDRESS().serialize(ref starkremit_constructor_calldata);
//     TOKEN_ADDRESS().serialize(ref starkremit_constructor_calldata);
//     let (starkremit_contract_address, _) = starkremit_class_hash
//         .deploy(@starkremit_constructor_calldata)
//         .unwrap();

//     let starkremit_dispatcher = IStarkRemitDispatcher {
//         contract_address: starkremit_contract_address,
//     };

//     (starkremit_contract_address, starkremit_dispatcher)
// }

// #[test]
// fn test_constructor_initializes_correctly() {
//     let (_, starkremit_dispatcher, _) = __setup__();

//     // Check owner address
//     let owner = starkremit_dispatcher.get_owner();
//     assert_eq!(owner, OWNER(), "Owner address should match the initialized owner");
// }
