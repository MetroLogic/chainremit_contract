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

pub mod components {
    pub mod admin;
    pub mod agents;
    pub mod kyc;
    pub mod loans;
    pub mod savings;
    pub mod user_management;
}
