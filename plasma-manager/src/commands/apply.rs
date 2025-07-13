use crate::{
    commands::Command,
    config::{delete_configuration, read_configuration, write_configuration},
    format::{detect_format, Format},
    schema::{ConfigFile, EntryContent, Operation},
};
use clap::Args;
use std::{
    fs,
    io::{Error, ErrorKind},
    path::PathBuf,
};

#[derive(Args)]
pub struct ApplyCommand {
    /// Path to the configuration file containing operations to apply
    file: PathBuf,

    /// Configuration file format (JSON, RON, TOML). If not specified, will auto-detect from file extension
    #[arg(short, long, value_name = "FORMAT")]
    format: Option<Format>,

    /// Print verbose output about operations being performed
    #[arg(short, long)]
    verbose: bool,
}

impl Command for ApplyCommand {
    type Err = Error;

    fn execute(&self) -> Result<(), Self::Err> {
        let file_content = fs::read_to_string(&self.file)?;

        let format = match &self.format {
            Some(format) => *format,
            None => detect_format(&self.file, Some(&file_content))?,
        };

        let config_file: ConfigFile = format.deserialize(&file_content)?;

        let mut delete_count = 0;
        let mut read_count = 0;
        let mut write_count = 0;
        let mut skipped = 0;

        for entry in config_file.operations {
            let file = entry.file.clone();
            let xdg_dir = entry.xdg_directory.clone();

            let group_display = match &entry.group {
                Some(g) => format!("[{}]", g),
                None => String::new(),
            };

            let group_ref = entry.group.as_deref();

            match (entry.operation, entry.entries) {
                (Operation::Write, EntryContent::WriteEntries(entries)) => {
                    for (key, value) in entries {
                        match write_configuration(&file, group_ref, &key, &value, &xdg_dir) {
                            Ok(()) => {
                                if self.verbose {
                                    println!("Wrote {}{}:{} = {}", file, group_display, key, value);
                                }
                                write_count += 1;
                            }
                            Err(e) => {
                                eprintln!("Error writing {}{}:{}: {}", file, group_display, key, e);
                                skipped += 1;
                            }
                        }
                    }
                }
                (Operation::Read, EntryContent::ReadDeleteEntries(keys)) => {
                    for key in keys {
                        match read_configuration(&file, group_ref, Some(&key), &xdg_dir, false) {
                            Ok(value) => {
                                println!("{}{}:{} = {}", file, group_display, key, value);
                                read_count += 1;
                            }
                            Err(e) => {
                                if self.verbose {
                                    eprintln!(
                                        "Error reading {}{}:{}: {}",
                                        file, group_display, key, e
                                    );
                                }
                                skipped += 1;
                            }
                        }
                    }
                }
                (Operation::Delete, EntryContent::ReadDeleteEntries(keys)) => {
                    for key in keys {
                        match delete_configuration(&file, group_ref, Some(&key), &xdg_dir) {
                            Ok(()) => {
                                if self.verbose {
                                    println!("Deleted: {}{}:{}", file, group_display, key);
                                }
                                delete_count += 1;
                            }
                            Err(e) => {
                                if self.verbose {
                                    eprintln!(
                                        "Failed to delete {}{}:{}: {}",
                                        file, group_display, key, e
                                    );
                                }
                                skipped += 1;
                            }
                        }
                    }
                }
                _ => {
                    return Err(Error::new(ErrorKind::InvalidData, "Invalid operation."));
                }
            }
        }

        println!(
            "Operations completed successfully. {} writes, {} reads, {} deletes, {} entries skipped.",
            write_count, read_count, delete_count, skipped
        );
        Ok(())
    }
}
