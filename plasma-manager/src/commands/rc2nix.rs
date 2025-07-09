use crate::commands::Command;
use clap::Args;
use std::io::Error;

#[derive(Args)]
pub struct Rc2NixCommand {}

impl Command for Rc2NixCommand {
    type Err = Error;

    fn execute(&self) -> Result<(), Self::Err> {
        todo!()
    }
}
