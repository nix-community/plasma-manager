use crate::{
    commands::Command,
    config::get_xdg_directory,
    format::{detect_format, Format},
    plasma_config::{
        should_skip_by_lambda, should_skip_file_specific, should_skip_group, should_skip_key,
        FileSettingsMap, SettingsMap, KNOWN_CONFIG_FILES, KNOWN_DATA_FILES,
    },
    schema::{ConfigEntry, ConfigFile},
};
use clap::Args;
use indexmap::IndexMap;
use kconfig_rs::Ini;
use std::{
    fs,
    io::{Error, ErrorKind},
    path::{Path, PathBuf},
};

#[derive(Args)]
pub struct BackupCommand {
    /// Clear the default file scan list and only process explicitly added files
    #[arg(short = 'C', long)]
    clear: bool,

    /// Add a config file to the scan list (can be used multiple times)
    #[arg(short = 'c', long = "add-config", value_name = "FILE")]
    add_config_files: Vec<String>,

    /// Add a data file to the scan list (can be used multiple times)
    #[arg(short = 'd', long = "add-data", value_name = "FILE")]
    add_data_files: Vec<String>,

    /// Output file format (JSON, RON, TOML). If not specified, will auto-detect from file extension
    #[arg(short, long, value_name = "FORMAT")]
    format: Option<Format>,

    /// Output file path where the backup will be saved
    #[arg(value_name = "OUTPUT")]
    output: PathBuf,
}

impl Command for BackupCommand {
    type Err = Error;

    fn execute(&self) -> Result<(), Self::Err> {
        let config_files = self.get_config_files()?;
        let data_files = self.get_data_files()?;

        let config_settings = self.process_files(&config_files, "config")?;
        let data_settings = self.process_files(&data_files, "data")?;

        let format = match &self.format {
            Some(format) => *format,
            None => detect_format(&self.output, None)?,
        };

        let config_file = self.build_config_file(&config_settings, &data_settings, format)?;
        self.save_config_file(&config_file, format)?;

        println!("Backup saved to: {}", self.output.display());
        Ok(())
    }
}

impl BackupCommand {
    fn get_config_files(&self) -> Result<Vec<PathBuf>, Error> {
        let config_dir = get_xdg_directory("config")?;
        let mut files = Vec::new();

        if !self.clear {
            for &file in KNOWN_CONFIG_FILES {
                files.push(config_dir.join(file));
            }
        }

        for file in &self.add_config_files {
            let path = if Path::new(file).is_absolute() {
                PathBuf::from(file)
            } else {
                config_dir.join(file)
            };
            files.push(path);
        }

        Ok(files)
    }

    fn get_data_files(&self) -> Result<Vec<PathBuf>, Error> {
        let data_dir = get_xdg_directory("data")?;
        let mut files = Vec::new();

        if !self.clear {
            for &file in KNOWN_DATA_FILES {
                files.push(data_dir.join(file));
            }
        }

        for file in &self.add_data_files {
            let path = if Path::new(file).is_absolute() {
                PathBuf::from(file)
            } else {
                data_dir.join(file)
            };
            files.push(path);
        }

        Ok(files)
    }

    fn process_files(&self, files: &[PathBuf], dir_type: &str) -> Result<FileSettingsMap, Error> {
        let base_dir = get_xdg_directory(dir_type)?;
        let mut file_settings = FileSettingsMap::new();

        for file_path in files {
            if !file_path.exists() {
                continue;
            }

            let relative_path = file_path
                .strip_prefix(&base_dir)
                .map_err(|_| {
                    Error::new(
                        ErrorKind::InvalidInput,
                        format!(
                            "File is not in {} directory: {}",
                            dir_type,
                            file_path.display()
                        ),
                    )
                })?
                .to_string_lossy()
                .to_string();

            let settings = self.parse_rc_file(file_path)?;
            if !settings.is_empty() {
                file_settings.insert(relative_path, settings);
            }
        }

        Ok(file_settings)
    }

    fn parse_rc_file(&self, file_path: &Path) -> Result<SettingsMap, Error> {
        let ini = Ini::load_from_file(file_path).map_err(|e| {
            Error::new(
                ErrorKind::InvalidData,
                format!("Failed to parse {}: {}", file_path.display(), e),
            )
        })?;

        let mut settings = SettingsMap::new();

        for (section_name, section) in ini.iter() {
            let group_name = match section_name {
                Some(parts) => parts.join("/"),
                None => String::new(),
            };

            if should_skip_group(&group_name) {
                continue;
            }

            let mut group_settings = IndexMap::new();

            for (key, value) in section.iter() {
                if should_skip_key(key) {
                    continue;
                }

                if should_skip_by_lambda(&group_name, key) {
                    continue;
                }

                let file_name = file_path.file_name().and_then(|n| n.to_str()).unwrap_or("");
                if should_skip_file_specific(file_name, key) {
                    continue;
                }

                group_settings.insert(key.to_string(), value.to_string());
            }

            if !group_settings.is_empty() {
                settings.insert(group_name, group_settings);
            }
        }

        Ok(settings)
    }

    fn build_config_file(
        &self,
        config_settings: &FileSettingsMap,
        data_settings: &FileSettingsMap,
        format: Format,
    ) -> Result<ConfigFile, Error> {
        let mut operations = Vec::new();

        for (file, file_settings) in config_settings {
            self.add_file_operations(&mut operations, file, file_settings, "config");
        }

        for (file, file_settings) in data_settings {
            self.add_file_operations(&mut operations, file, file_settings, "data");
        }

        Ok(ConfigFile {
            schema: if format == Format::Ron {
                None
            } else {
                Some("https://raw.githubusercontent.com/nix-community/plasma-manager/refs/heads/trunk/plasma-manager/schema.json".to_string())
            },
            operations,
        })
    }

    fn add_file_operations(
        &self,
        operations: &mut Vec<ConfigEntry>,
        file: &str,
        file_settings: &SettingsMap,
        xdg_directory: &str,
    ) {
        for (group, group_settings) in file_settings {
            for (key, value) in group_settings {
                operations.push(ConfigEntry::Write {
                    file: file.to_string(),
                    group: if group.is_empty() {
                        None
                    } else {
                        Some(group.clone())
                    },
                    key: Some(key.clone()),
                    value: Some(value.clone()),
                    xdg_directory: xdg_directory.to_string(),
                    immutable: false,
                    expand_environment: false,
                });
            }
        }
    }

    fn save_config_file(&self, config_file: &ConfigFile, format: Format) -> Result<(), Error> {
        if let Some(parent) = self.output.parent() {
            fs::create_dir_all(parent)?;
        }

        let content = format.serialize(config_file)?;

        fs::write(&self.output, content)?;
        Ok(())
    }
}
