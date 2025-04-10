mod apply;
mod delete;
mod read;
mod write;

use crate::commands::{
    apply::ApplyCommand, delete::DeleteCommand, read::ReadCommand, write::WriteCommand,
};
use clap::Subcommand;
use std::io::Error;

#[derive(Subcommand)]
pub enum Commands {
    Apply(ApplyCommand),
    Delete(DeleteCommand),
    Read(ReadCommand),
    Write(WriteCommand),
}

impl Commands {
    pub(crate) fn execute(&self) -> Result<(), Error> {
        match self {
            Commands::Apply(cmd) => cmd.execute(),
            Commands::Delete(cmd) => cmd.execute(),
            Commands::Read(cmd) => cmd.execute(),
            Commands::Write(cmd) => cmd.execute(),
        }
    }
}

pub trait Command {
    type Err;

    fn execute(&self) -> Result<(), Self::Err>;
}
