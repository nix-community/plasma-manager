use crate::{commands::Command, config::read_configuration};
use clap::Args;
use std::io::Error;

#[derive(Args)]
pub struct ReadCommand {
    /// Configuration file name (e.g., kdeglobals, kwinrc)
    #[arg(short, long, value_name = "FILE")]
    file: String,

    /// Configuration group/section name within the file
    #[arg(short, long, value_name = "GROUP")]
    group: Option<String>,

    /// Configuration key to read. If not specified, reads the entire group
    #[arg(short, long, value_name = "KEY")]
    key: Option<String>,

    /// XDG directory type
    #[arg(short, long, default_value = "config", value_name = "DIR")]
    xdg_dir: String,

    /// Output raw value without formatting
    #[arg(long)]
    raw: bool,
}

impl Command for ReadCommand {
    type Err = Error;

    fn execute(&self) -> Result<(), Self::Err> {
        let value = read_configuration(
            &self.file,
            self.group.as_deref(),
            self.key.as_deref(),
            &self.xdg_dir,
            self.raw,
        )?;

        println!("{}", value);
        Ok(())
    }
}
