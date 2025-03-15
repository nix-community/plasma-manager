use crate::{commands::Command, config::read_configuration};
use clap::Args;
use std::io::Error;

#[derive(Args)]
pub struct ReadCommand {
    #[arg(short, long)]
    file: String,
    #[arg(short, long)]
    group: Option<String>,
    #[arg(short, long)]
    key: Option<String>,
    #[arg(short, long, default_value = "config")]
    xdg_dir: String,
    #[arg(long, default_value = "false")]
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
