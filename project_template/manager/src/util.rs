use std::env;
use std::fmt::{self, Display};
use std::path::PathBuf;

pub type AppResult<T> = Result<T, AppError>;

#[derive(Debug)]
pub struct AppError {
    message: String,
}

impl AppError {
    pub fn msg(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
        }
    }
}

impl Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.message)
    }
}

impl std::error::Error for AppError {}

impl From<std::io::Error> for AppError {
    fn from(value: std::io::Error) -> Self {
        Self::msg(value.to_string())
    }
}

pub mod paths {
    use super::*;

    pub fn root_dir() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .expect("manager must live under project root")
            .to_path_buf()
    }

    pub fn run_dir() -> PathBuf {
        root_dir().join("temp/run")
    }

    pub fn log_dir() -> PathBuf {
        root_dir().join("temp/logs")
    }

    pub fn backend_dir() -> PathBuf {
        root_dir().join("backend")
    }

    pub fn frontend_dir() -> PathBuf {
        root_dir().join("frontend")
    }
}

pub fn command_name(name: &str) -> String {
    if cfg!(windows) && name == "pnpm" {
        "pnpm.cmd".to_owned()
    } else {
        name.to_owned()
    }
}
