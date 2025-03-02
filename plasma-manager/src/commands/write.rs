use crate::{commands::Command, config::write_configuration};
use clap::Args;
use std::io::Error;

#[derive(Args)]
pub struct WriteCommand {
    #[arg(short, long)]
    file: String,
    #[arg(short, long)]
    group: Option<String>,
    #[arg(short, long)]
    key: String,
    value: String,
    #[arg(short, long, default_value = "config")]
    xdg_dir: String,
}

impl Command for WriteCommand {
    type Err = Error;

    fn execute(&self) -> Result<(), Self::Err> {
        write_configuration(
            &self.file,
            self.group.as_deref(),
            &self.key,
            &self.value,
            &self.xdg_dir,
        )?;
        Ok(())
    }
}
