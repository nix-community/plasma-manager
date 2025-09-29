use crate::{
    commands::Command,
    config::{delete_configuration, read_configuration, write_configuration},
    format::{detect_format, Format},
    schema::{ConfigFile, ConfigEntry},
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
            match entry {
                ConfigEntry::Write {
                    file,
                    group,
                    key,
                    value,
                    xdg_directory,
                    immutable,
                    expand_environment,
                } => {
                    let group_display =
                        group.as_deref().map_or(String::new(), |g| format!("[{}]", g));
                    match write_configuration(
                        &file,
                        group.as_deref(),
                        key.as_deref(),
                        value.as_deref(),
                        &xdg_directory,
                        immutable,
                        expand_environment,
                    ) {
                        Ok(()) => {
                            if self.verbose {
                                if let Some(k) = key {
                                    if let Some(v) = value {
                                        println!("Wrote {}{}:{} = {}", file, group_display, k, v);
                                    } else {
                                        println!(
                                            "Wrote/updated flags for {}{}:{}",
                                            file, group_display, k
                                        );
                                    }
                                } else {
                                    println!(
                                        "Wrote/updated flags for group in {}{}",
                                        file, group_display
                                    );
                                }
                            }
                            write_count += 1;
                        }
                        Err(e) => {
                            if let Some(k) = key {
                                eprintln!("Error writing {}{}:{}: {}", file, group_display, k, e);
                            } else {
                                eprintln!(
                                    "Error writing to group in {}{}: {}",
                                    file, group_display, e
                                );
                            }
                            skipped += 1;
                        }
                    }
                }
                ConfigEntry::Read {
                    file,
                    group,
                    key,
                    xdg_directory,
                    raw,
                } => {
                    let group_display =
                        group.as_deref().map_or(String::new(), |g| format!("[{}]", g));
                    match read_configuration(
                        &file,
                        group.as_deref(),
                        key.as_deref(),
                        &xdg_directory,
                        raw,
                    ) {
                        Ok(value) => {
                            if let Some(k) = key {
                                println!("{}{}:{} = {}", file, group_display, k, value);
                            } else {
                                println!(
                                    "Content of group in {}{}:\n{}",
                                    file, group_display, value
                                );
                            }
                            read_count += 1;
                        }
                        Err(e) => {
                            if self.verbose {
                                if let Some(k) = key {
                                    eprintln!(
                                        "Error reading {}{}:{}: {}",
                                        file, group_display, k, e
                                    );
                                } else {
                                    eprintln!(
                                        "Error reading group in {}{}: {}",
                                        file, group_display, e
                                    );
                                }
                            }
                            skipped += 1;
                        }
                    }
                }
                ConfigEntry::Delete {
                    file,
                    group,
                    key,
                    xdg_directory,
                } => {
                    let group_display =
                        group.as_deref().map_or(String::new(), |g| format!("[{}]", g));
                    match delete_configuration(
                        &file,
                        group.as_deref(),
                        key.as_deref(),
                        &xdg_directory,
                    ) {
                        Ok(()) => {
                            if self.verbose {
                                if let Some(k) = key {
                                    println!("Deleted: {}{}:{}", file, group_display, k);
                                } else {
                                    println!("Deleted group in {}{}", file, group_display);
                                }
                            }
                            delete_count += 1;
                        }
                        Err(e) => {
                            if self.verbose {
                                if let Some(k) = key {
                                    eprintln!(
                                        "Failed to delete {}{}:{}: {}",
                                        file, group_display, k, e
                                    );
                                } else {
                                    eprintln!(
                                        "Failed to delete group in {}{}: {}",
                                        file, group_display, e
                                    );
                                }
                            }
                            skipped += 1;
                        }
                    }
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
