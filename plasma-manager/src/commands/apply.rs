use crate::{
    commands::Command,
    config::{delete_configuration, read_configuration, write_configuration},
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
    /// Path to the JSON file containing configuration operations
    file: PathBuf,
    /// Print verbose output about operations
    #[arg(short, long)]
    verbose: bool,
}

impl Command for ApplyCommand {
    type Err = Error;

    fn execute(&self) -> Result<(), Self::Err> {
        if self.file.extension().and_then(|s| s.to_str()) != Some("json") {
            return Err(Error::new(
                ErrorKind::InvalidInput,
                "Configuration file must be a JSON file.",
            ));
        }

        let file_content = fs::read_to_string(&self.file)?;
        let config_file: ConfigFile = serde_json::from_str(&file_content)?;

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
