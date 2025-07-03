
pub mod GroupErrors {
    /// Error triggered when the max members is less than two
    pub const INVALID_GROUP_SIZE: felt252 = 'GROUP: mini 2 members expected';

    /// Error triggered when trying to join an inactive group
    pub const GROUP_INACTIVE: felt252 = 'GROUP: group is inactive';

    /// Error triggered when trying to access an inactive group
    pub const GROUP_NOT_ACTIVE: felt252 = 'GROUP: group is not active';

    /// Error triggered when trying to join a group twice
    pub const ALREADY_MEMBER: felt252 = 'GROUP: caller already a member';

    /// Error triggered when the group is full
    pub const GROUP_FULL: felt252 = 'GROUP: group is full';
}
