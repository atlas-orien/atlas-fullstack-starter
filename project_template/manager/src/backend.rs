use std::fs;
use std::path::Path;

use crate::process;
use crate::util::{AppError, AppResult, paths};

pub fn init_env() -> AppResult<()> {
    let backend_dir = paths::backend_dir();
    if !backend_dir.exists() {
        return Err(AppError::msg("错误：后端目录不存在：backend/"));
    }

    println!("==> 初始化后端 env");
    if !backend_dir.join(".env").exists() {
        process::run_in("cargo", &["xtask", "init"], &backend_dir)?;
    } else {
        println!("后端 .env 已存在，跳过 cargo xtask init");
    }

    println!("==> 启动后端 PostgreSQL 并确认数据库");
    process::run_in("cargo", &["xtask", "db", "up"], &backend_dir)?;

    println!("==> 执行后端 migration");
    process::run_in("cargo", &["xtask", "migrate", "up"], &backend_dir)?;

    println!("后端 env 已初始化");
    Ok(())
}

pub fn run(action: &str) -> AppResult<()> {
    let pid_file = process::pid_file("backend.pid");
    let log_file = process::log_file("backend.log");
    let backend_dir = paths::backend_dir();

    match action {
        "start" => {
            process::require_command("cargo")?;
            process::start_managed(
                "backend",
                &pid_file,
                &log_file,
                &backend_dir,
                "cargo",
                &["run", "-p", "web-server"],
            )?;
            process::wait_http_url(
                "backend",
                &pid_file,
                &log_file,
                &backend_url(&backend_dir),
                120,
            )
        }
        "stop" => process::stop_managed("backend", &pid_file),
        "restart" => {
            process::stop_managed("backend", &pid_file)?;
            run("start")
        }
        "status" => process::print_status("backend", &pid_file),
        _ => Err(AppError::msg("未知 backend 动作")),
    }
}

fn backend_url(backend_dir: &Path) -> String {
    let config_file = backend_dir.join("config/services.toml");
    let port = fs::read_to_string(config_file)
        .ok()
        .and_then(|content| read_http_port(&content))
        .unwrap_or_else(|| "19878".to_owned());

    format!("http://127.0.0.1:{port}/")
}

fn read_http_port(content: &str) -> Option<String> {
    let mut in_http = false;
    for line in content.lines() {
        let line = line.trim();
        if line == "[http]" {
            in_http = true;
            continue;
        }
        if line.starts_with('[') {
            in_http = false;
        }
        if in_http && line.starts_with("port") {
            let (_, value) = line.split_once('=')?;
            let port = value.trim().trim_matches('"');
            if !port.is_empty() {
                return Some(port.to_owned());
            }
        }
    }
    None
}
