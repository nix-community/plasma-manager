mod read;
mod write;

use crate::commands::{read::ReadCommand, write::WriteCommand};
use clap::Subcommand;
use std::io::Error;

#[derive(Subcommand)]
pub enum Commands {
    Write(WriteCommand),
    Read(ReadCommand),
}

impl Commands {
    pub(crate) fn execute(&self) -> Result<(), Error> {
        match self {
            Commands::Write(cmd) => cmd.execute(),
            Commands::Read(cmd) => cmd.execute(),
        }
    }
}

pub trait Command {
    type Err;

    fn execute(&self) -> Result<(), Self::Err>;
}
