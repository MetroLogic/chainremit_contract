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
    pub mod contribution;
    pub mod kyc;
    pub mod loan;
    pub mod user_management;
    pub mod savings_group;
    pub mod token_management;
    pub mod transfer;
}