mod backend;
mod frontend;
mod process;
mod util;

use std::env;

use util::{AppError, AppResult, paths};

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}

fn run() -> AppResult<()> {
    let mut args = env::args().skip(1).collect::<Vec<_>>();

    if args.is_empty() || matches!(args[0].as_str(), "help" | "--help" | "-h") {
        print_usage();
        return Ok(());
    }

    let area = args.remove(0);
    match area.as_str() {
        "init-env" | "init_env" => {
            let target = args.first().map(String::as_str).unwrap_or("all");
            init_env(target)
        }
        "backend" => {
            let action = args
                .first()
                .ok_or_else(|| AppError::msg("缺少 backend 动作"))?;
            backend::run(action)
        }
        "frontend" => {
            let target = args
                .first()
                .ok_or_else(|| AppError::msg("缺少 frontend 目标"))?;
            if target == "install" {
                return frontend::install();
            }

            let action = args
                .get(1)
                .ok_or_else(|| AppError::msg("缺少 frontend 动作"))?;
            frontend::run(target, action)
        }
        _ => {
            print_usage();
            Err(AppError::msg(format!("未知命令：{area}")))
        }
    }
}

fn init_env(target: &str) -> AppResult<()> {
    match target {
        "all" => {
            backend::init_env()?;
            frontend::init_env()
        }
        "backend" => backend::init_env(),
        "frontend" => frontend::init_env(),
        _ => Err(AppError::msg(format!("未知 init-env 目标：{target}"))),
    }
}

fn print_usage() {
    let root = paths::root_dir();
    println!(
        r#"用法：
  cargo manage init-env [frontend|backend]
  cargo manage backend start|stop|restart|status
  cargo manage frontend install
  cargo manage frontend <app> start|stop|restart|status

示例：
  cargo manage init-env
  cargo manage init-env frontend
  cargo manage init-env backend
  cargo manage backend start
  cargo manage backend stop
  cargo manage frontend install
  cargo manage frontend admin start
  cargo manage frontend admin stop

目录：
  {}

日志：
  temp/logs/backend.log
  temp/logs/frontend-<app>.log"#,
        root.display()
    );
}
