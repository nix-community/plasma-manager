use crate::{commands::Command, config::delete_configuration};
use clap::Args;
use std::io::Error;

#[derive(Args)]
pub struct DeleteCommand {
    #[arg(short, long)]
    file: String,

    #[arg(short, long)]
    group: Option<String>,

    #[arg(short, long)]
    key: Option<String>,

    #[arg(short, long, default_value = "config")]
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
