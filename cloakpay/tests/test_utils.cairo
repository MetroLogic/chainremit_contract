use cloakpay::interfaces::ICloakpay::{ICloakPayDispatcher, ICloakPayDispatcherTrait};
use openzeppelin::token::erc20::interface::IERC20Dispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;


pub const owner: ContractAddress = 'owner'.try_into().unwrap();
pub const test_address_1: ContractAddress = 'test_address_1'.try_into().unwrap();
pub const test_address_2: ContractAddress = 'test_address_2'.try_into().unwrap();
pub const test_address_3: ContractAddress = 'test_address_3'.try_into().unwrap();


pub fn deploy_cloakpay() -> (ICloakPayDispatcher, IERC20Dispatcher) {
    let (erc20, erc20_address) = deploy_token();
    let cloakpay_class = declare("cloakpay").unwrap().contract_class();
    let (contract_address, _) = cloakpay_class.deploy(@array![erc20_address.into()]).unwrap();

    (ICloakPayDispatcher { contract_address }, erc20)
}

pub fn deploy_token() -> (IERC20Dispatcher, ContractAddress) {
    let erc20_class = declare("token").unwrap().contract_class();
    let mut calldata = array![owner.into(), owner.into(), 6];
    let (erc20_address, _) = erc20_class.deploy(@calldata).unwrap();
    (IERC20Dispatcher { contract_address: erc20_address }, erc20_address)
}

fn create_default_deposit(cloakpay_dispatcher: ICloakPayDispatcher) -> u256 {
    cloakpay_dispatcher.deposit(1, 8000, 4443242);
    1
}

pub fn to_18_decimals(num: u256) -> u256 {
    1000000000000000000 * num
}
