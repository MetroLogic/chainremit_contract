pub mod base {
    pub mod errors;
    pub mod events;
    pub mod types;
}

pub mod interfaces {
    pub mod IERC20;
    pub mod IStarkRemit;
}

pub mod utils {
    pub mod constants;
    pub mod helpers;
}

pub mod starkremit {
    pub mod StarkRemit;
}

pub mod presets {
    pub mod ERC20;
}
pub mod component {
    pub mod agent;
    pub mod contribution {
        pub mod contribution;
        pub mod mock;
        pub mod test;
    }
    pub mod emergency;
    pub mod penalty;
    pub mod kyc;
    pub mod loan;
    pub mod savings_group;
    pub mod token_management;
    pub mod transfer;
    pub mod user_management;
    pub mod auto_schedule;
    pub mod member_profile;
    pub mod payment_flexibility;
    pub mod analytics;
}
