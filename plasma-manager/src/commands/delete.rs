use crate::{commands::Command, config::delete_configuration};
use clap::Args;
use std::io::Error;

#[derive(Args)]
pub struct DeleteCommand {
    /// Configuration file name (e.g., kdeglobals, kwinrc)
    #[arg(short, long, value_name = "FILE")]
    file: String,

    /// Configuration group/section name within the file
    #[arg(short, long, value_name = "GROUP")]
    group: Option<String>,

    /// Configuration key to delete. If not specified, deletes the entire group
    #[arg(short, long, value_name = "KEY")]
    key: Option<String>,

    /// XDG directory type
    #[arg(short, long, default_value = "config", value_name = "DIR")]
    xdg_dir: String,
}

impl Command for DeleteCommand {
    type Err = Error;

    fn execute(&self) -> Result<(), Self::Err> {
        delete_configuration(
            &self.file,
            self.group.as_deref(),
            self.key.as_deref(),
            &self.xdg_dir,
        )?;
        Ok(())
    }
}
