use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

use crate::util::{AppError, AppResult, command_name};

pub fn require_command(command: &str) -> AppResult<()> {
    let status = if cfg!(windows) {
        Command::new("where")
            .arg(command)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
    } else {
        Command::new("command")
            .arg("-v")
            .arg(command)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
    }?;

    if status.success() {
        Ok(())
    } else {
        Err(AppError::msg(format!("错误：缺少命令 '{command}'")))
    }
}

pub fn run_in(command: &str, args: &[&str], cwd: &Path) -> AppResult<()> {
    require_command(command)?;
    let status = Command::new(command_name(command))
        .args(args)
        .current_dir(cwd)
        .status()?;

    if status.success() {
        Ok(())
    } else {
        Err(AppError::msg(format!(
            "命令执行失败：{} {}",
            command,
            args.join(" ")
        )))
    }
}

pub fn is_running(pid_file: &Path) -> bool {
    let Some(pid) = read_pid(pid_file) else {
        return false;
    };

    process_exists(pid)
}

pub fn start_managed(
    name: &str,
    pid_file: &Path,
    log_file: &Path,
    cwd: &Path,
    command: &str,
    args: &[&str],
) -> AppResult<()> {
    if is_running(pid_file) {
        println!(
            "{name} 已在运行，PID: {}",
            fs::read_to_string(pid_file)?.trim()
        );
        return Ok(());
    }

    if let Some(parent) = pid_file.parent() {
        fs::create_dir_all(parent)?;
    }
    if let Some(parent) = log_file.parent() {
        fs::create_dir_all(parent)?;
    }

    println!("==> 启动 {name}");
    println!("    日志：{}", log_file.display());

    let log = fs::File::create(log_file)?;
    let err_log = fs::OpenOptions::new().append(true).open(log_file)?;
    let child = Command::new(command_name(command))
        .args(args)
        .current_dir(cwd)
        .stdout(Stdio::from(log))
        .stderr(Stdio::from(err_log))
        .spawn()?;

    fs::write(pid_file, child.id().to_string())?;
    Ok(())
}

pub fn stop_managed(name: &str, pid_file: &Path) -> AppResult<()> {
    let Some(pid) = read_pid(pid_file) else {
        let _ = fs::remove_file(pid_file);
        println!("{name} 未运行");
        return Ok(());
    };

    if !process_exists(pid) {
        let _ = fs::remove_file(pid_file);
        println!("{name} 未运行");
        return Ok(());
    }

    println!("==> 停止 {name}，PID: {pid}");
    terminate_process(pid)?;

    for _ in 0..5 {
        if !process_exists(pid) {
            let _ = fs::remove_file(pid_file);
            println!("{name} 已停止");
            return Ok(());
        }
        thread::sleep(Duration::from_secs(1));
    }

    kill_process(pid)?;
    let _ = fs::remove_file(pid_file);
    println!("{name} 已停止");
    Ok(())
}

pub fn print_status(name: &str, pid_file: &Path) -> AppResult<()> {
    if is_running(pid_file) {
        println!(
            "{name} 运行中，PID: {}",
            fs::read_to_string(pid_file)?.trim()
        );
    } else {
        let _ = fs::remove_file(pid_file);
        println!("{name} 未运行");
    }
    Ok(())
}

pub fn wait_http_url(
    name: &str,
    pid_file: &Path,
    log_file: &Path,
    url: &str,
    seconds: u64,
) -> AppResult<()> {
    println!("    等待访问地址：{url}");

    for _ in 0..seconds {
        if !is_running(pid_file) {
            return fail_start(name, pid_file, log_file);
        }

        if http_probe(url) {
            println!(
                "{name} 已启动，PID: {}",
                fs::read_to_string(pid_file)?.trim()
            );
            println!("访问地址：{url}");
            return Ok(());
        }

        thread::sleep(Duration::from_secs(1));
    }

    print_log_tail(log_file);
    Err(AppError::msg(format!(
        "错误：{name} 进程仍在运行，但没有在 {seconds} 秒内连上访问地址\n日志：{}",
        log_file.display()
    )))
}

pub fn print_log_tail(log_file: &Path) {
    let Ok(content) = fs::read_to_string(log_file) else {
        return;
    };

    println!();
    println!("最近日志：");
    let lines = content.lines().rev().take(80).collect::<Vec<_>>();
    for line in lines.into_iter().rev() {
        println!("{line}");
    }
}

fn fail_start(name: &str, pid_file: &Path, log_file: &Path) -> AppResult<()> {
    let _ = fs::remove_file(pid_file);
    print_log_tail(log_file);
    Err(AppError::msg(format!(
        "错误：{name} 启动失败\n日志：{}",
        log_file.display()
    )))
}

fn read_pid(pid_file: &Path) -> Option<u32> {
    fs::read_to_string(pid_file)
        .ok()
        .and_then(|value| value.trim().parse::<u32>().ok())
}

fn process_exists(pid: u32) -> bool {
    if cfg!(windows) {
        Command::new("tasklist")
            .args(["/FI", &format!("PID eq {pid}")])
            .output()
            .map(|output| String::from_utf8_lossy(&output.stdout).contains(&pid.to_string()))
            .unwrap_or(false)
    } else {
        Command::new("kill")
            .args(["-0", &pid.to_string()])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map(|status| status.success())
            .unwrap_or(false)
    }
}

fn terminate_process(pid: u32) -> AppResult<()> {
    if cfg!(windows) {
        let _ = Command::new("taskkill")
            .args(["/PID", &pid.to_string(), "/T"])
            .status()?;
    } else {
        let _ = Command::new("kill").arg(pid.to_string()).status()?;
    }
    Ok(())
}

fn kill_process(pid: u32) -> AppResult<()> {
    if cfg!(windows) {
        let _ = Command::new("taskkill")
            .args(["/PID", &pid.to_string(), "/T", "/F"])
            .status()?;
    } else {
        let _ = Command::new("kill")
            .args(["-9", &pid.to_string()])
            .status()?;
    }
    Ok(())
}

fn http_probe(url: &str) -> bool {
    let curl = if cfg!(windows) { "curl.exe" } else { "curl" };
    Command::new(curl)
        .args(["-sS", "-o", dev_null(), "--max-time", "2", url])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn dev_null() -> &'static str {
    if cfg!(windows) { "NUL" } else { "/dev/null" }
}

pub fn pid_file(name: &str) -> PathBuf {
    crate::util::paths::run_dir().join(name)
}

pub fn log_file(name: &str) -> PathBuf {
    crate::util::paths::log_dir().join(name)
}
