use crate::{commands::Command, config::write_configuration};
use clap::Args;
use std::io::Error;

#[derive(Args)]
pub struct WriteCommand {
    /// Configuration file name (e.g., kdeglobals, kwinrc)
    #[arg(short, long, value_name = "FILE")]
    file: String,

    /// Configuration group/section name within the file
    #[arg(short, long, value_name = "GROUP")]
    group: Option<String>,

    /// Configuration key to write
    #[arg(short, long, value_name = "KEY", required_unless_present_any = ["expand_environment", "immutable"])]
    key: Option<String>,

    /// Value to write for the specified key
    #[arg(value_name = "VALUE", required_unless_present_any = ["expand_environment", "immutable"])]
    value: Option<String>,

    /// XDG directory type
    #[arg(short, long, default_value = "config", value_name = "DIR")]
    xdg_dir: String,

    #[arg(long)]
    immutable: bool,

    #[arg(long)]
    expand_environment: bool,
}

impl Command for WriteCommand {
    type Err = Error;

    fn execute(&self) -> Result<(), Self::Err> {
        write_configuration(
            &self.file,
            self.group.as_deref(),
            self.key.as_deref(),
            self.value.as_deref(),
            &self.xdg_dir,
            self.immutable,
            self.expand_environment,
        )?;
        Ok(())
    }
}
