mod commands;
mod config;
mod format;
mod plasma_config;
mod schema;

use crate::commands::Commands;
use clap::Parser;

#[derive(Parser)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

fn main() {
    let cli = Cli::parse();

    if let Err(e) = cli.command.execute() {
        eprintln!("Error: {}", e);
        std::process::exit(1);
    }
}
