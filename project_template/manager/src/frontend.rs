use std::fs;
use std::thread;
use std::time::Duration;

use crate::process;
use crate::util::{AppError, AppResult, paths};

pub fn init_env() -> AppResult<()> {
    install()?;

    println!("==> 初始化前端 env");
    process::run_in("pnpm", &["env:init"], &paths::frontend_dir())
}

pub fn install() -> AppResult<()> {
    println!("==> 安装前端依赖");
    process::run_in("pnpm", &["install"], &paths::frontend_dir())
}

pub fn run(app: &str, action: &str) -> AppResult<()> {
    let app_dir = paths::frontend_dir().join("apps").join(app);
    if !app_dir.exists() {
        return Err(AppError::msg(format!(
            "错误：前端 app 不存在：frontend/apps/{app}"
        )));
    }

    let pid_file = process::pid_file(&format!("frontend-{app}.pid"));
    let log_file = process::log_file(&format!("frontend-{app}.log"));
    let name = format!("frontend:{app}");

    match action {
        "start" => {
            ensure_deps()?;
            process::start_managed(&name, &pid_file, &log_file, &app_dir, "pnpm", &["dev"])?;
            print_frontend_url(app, &pid_file, &log_file)
        }
        "stop" => process::stop_managed(&name, &pid_file),
        "restart" => {
            process::stop_managed(&name, &pid_file)?;
            run(app, "start")
        }
        "status" => process::print_status(&name, &pid_file),
        _ => Err(AppError::msg("未知 frontend 动作")),
    }
}

fn ensure_deps() -> AppResult<()> {
    if paths::frontend_dir().join("node_modules").exists() {
        Ok(())
    } else {
        Err(AppError::msg(
            "错误：前端依赖还没有安装。请先运行：cargo manage frontend install",
        ))
    }
}

fn print_frontend_url(
    app: &str,
    pid_file: &std::path::Path,
    log_file: &std::path::Path,
) -> AppResult<()> {
    let name = format!("frontend:{app}");
    for _ in 0..10 {
        if !process::is_running(pid_file) {
            process::print_log_tail(log_file);
            return Err(AppError::msg(format!("错误：{name} 启动失败")));
        }

        if let Some(url) = read_frontend_url(log_file) {
            println!(
                "{name} 已启动，PID: {}",
                fs::read_to_string(pid_file)?.trim()
            );
            println!("访问地址：{url}");
            return Ok(());
        }

        thread::sleep(Duration::from_secs(1));
    }

    process::print_log_tail(log_file);
    Err(AppError::msg(format!(
        "错误：{name} 未能在日志中找到访问地址\n日志：{}",
        log_file.display()
    )))
}

fn read_frontend_url(log_file: &std::path::Path) -> Option<String> {
    let content = fs::read_to_string(log_file).ok()?;
    content
        .split_whitespace()
        .find(|part| {
            part.starts_with("http://localhost:")
                || part.starts_with("http://127.0.0.1:")
                || part.starts_with("http://[::1]:")
                || part.starts_with("https://localhost:")
                || part.starts_with("https://127.0.0.1:")
                || part.starts_with("https://[::1]:")
        })
        .map(|part| {
            part.trim_end_matches(|ch: char| matches!(ch, ',' | ';' | ')' | ']' | '"' | '\''))
                .to_owned()
        })
}
