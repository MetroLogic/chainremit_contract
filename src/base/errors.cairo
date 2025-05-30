pub mod ERC20Errors {
    /// Error triggered when transfer amount exceeds balance
    pub const INSUFFICIENT_BALANCE: felt252 = 'ERC20: insufficient balance';

    /// Error triggered when spender tries to transfer more than allowed
    pub const INSUFFICIENT_ALLOWANCE: felt252 = 'ERC20: insufficient allowance';

    /// Error triggered when transferring to the zero address
    pub const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0 address';

    /// Error triggered when approving the zero address
    pub const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0 address';

    /// Error triggered when minting to the zero address
    pub const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0 address';

    /// Error triggered when burning from the zero address
    pub const BURN_FROM_ZERO: felt252 = 'ERC20: burn from 0 address';

    /// Error triggered when the caller is not the owner of the token
    pub const NotAdmin: felt252 = 'ERC20: not admin';
}


pub mod GroupsErrors {
    /// Error triggered when the max members is less than two
    pub const INVALID_GROUP_SIZE: felt252 = 'GROUP: mini 2 members expected';

    /// Error triggered when trying to join an inactive group
    pub const GROUP_INACTIVE: felt252 = 'GROUP: group is inactive';

    /// Error triggered when trying to join a group twice
    pub const ALREADY_MEMBER: felt252 = 'GROUP: caller already a member';

    /// Error triggered when the group is full
    pub const GROUP_FULL: felt252 = 'GROUP: group is full';
}
