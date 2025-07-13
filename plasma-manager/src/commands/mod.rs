mod apply;
mod backup;
mod delete;
mod rc2nix;
mod read;
mod write;

use crate::commands::{
    apply::ApplyCommand, backup::BackupCommand, delete::DeleteCommand, rc2nix::Rc2NixCommand,
    read::ReadCommand, write::WriteCommand,
};
use clap::Subcommand;
use std::io::Error;

#[derive(Subcommand)]
pub enum Commands {
    /// Apply configuration operations from a file to the system
    Apply(ApplyCommand),
    /// Create a backup of current Plasma configuration
    Backup(BackupCommand),
    /// Delete specific configuration entries
    Delete(DeleteCommand),
    /// Convert KDE configuration files to plasma-manager configurations
    #[command(name = "rc2nix")]
    Rc2Nix(Rc2NixCommand),
    /// Read configuration values from files
    Read(ReadCommand),
    /// Write configuration values to files
    Write(WriteCommand),
}

impl Commands {
    pub(crate) fn execute(&self) -> Result<(), Error> {
        match self {
            Commands::Apply(cmd) => cmd.execute(),
            Commands::Backup(cmd) => cmd.execute(),
            Commands::Delete(cmd) => cmd.execute(),
            Commands::Rc2Nix(cmd) => cmd.execute(),
            Commands::Read(cmd) => cmd.execute(),
            Commands::Write(cmd) => cmd.execute(),
        }
    }
}

pub trait Command {
    type Err;

    fn execute(&self) -> Result<(), Self::Err>;
}
