use crate::commands::Command;
use crate::config::get_xdg_directory;
use crate::plasma_config::{
    should_skip_by_lambda, should_skip_file_specific, should_skip_group, should_skip_key,
    FileSettingsMap, SettingsMap, KNOWN_CONFIG_FILES, KNOWN_DATA_FILES,
};
use clap::Args;
use indexmap::IndexMap;
use kconfig_rs::Ini;
use regex::Regex;
use std::io::{Error, ErrorKind};
use std::path::{Path, PathBuf};

#[derive(Args)]
pub struct Rc2NixCommand {
    /// Clear the default file list
    #[arg(short, long)]
    clear: bool,

    /// Add a file to the scan list
    #[arg(short, long = "add", value_name = "FILE")]
    add_files: Vec<String>,
}

#[derive(Debug, Clone)]
enum NestedValue {
    Leaf(String),
    Node(IndexMap<String, NestedValue>),
}

impl Command for Rc2NixCommand {
    type Err = Error;

    fn execute(&self) -> Result<(), Self::Err> {
        let config_files = self.get_config_files()?;
        let data_files = self.get_data_files()?;

        let config_settings = self.process_files(&config_files, "config")?;
        let data_settings = self.process_files(&data_files, "data")?;

        self.print_output(&config_settings, &data_settings)?;

        Ok(())
    }
}

impl Rc2NixCommand {
    fn get_config_files(&self) -> Result<Vec<PathBuf>, Error> {
        let config_dir = get_xdg_directory("config")?;
        let mut files = Vec::new();

        if !self.clear {
            for &file in KNOWN_CONFIG_FILES {
                files.push(config_dir.join(file));
            }
        }

        for file in &self.add_files {
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

            // Skip blocked groups
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

                // Skip special file-specific blocks
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

    fn print_output(
        &self,
        config_settings: &FileSettingsMap,
        data_settings: &FileSettingsMap,
    ) -> Result<(), Error> {
        println!("{{");
        println!("  programs.plasma = {{");
        println!("    enable = true;");

        if let Some(shortcuts) = config_settings.get("kglobalshortcutsrc") {
            println!("    shortcuts = {{");
            self.print_shortcuts_nested(shortcuts, 6);
            println!("    }};");
        } else {
            println!("    shortcuts = {{}};");
        }

        println!("    configFile = {{");
        self.print_settings_nested(config_settings, 6, true);
        println!("    }};");
        println!("    dataFile = {{");
        self.print_settings_nested(data_settings, 6, false);
        println!("    }};");
        println!("  }};");
        println!("}}");

        Ok(())
    }

    fn print_shortcuts_nested(&self, shortcuts: &SettingsMap, indent: usize) {
        // Group shortcuts by their component
        let mut grouped_shortcuts: IndexMap<String, IndexMap<String, String>> = IndexMap::new();

        for (group, group_settings) in shortcuts {
            for (action, value) in group_settings {
                if action == "_k_friendly_name" {
                    continue;
                }

                if !grouped_shortcuts.contains_key(group) {
                    grouped_shortcuts.insert(group.clone(), IndexMap::new());
                }

                let keys = self.parse_shortcut_keys(value);
                grouped_shortcuts
                    .get_mut(group)
                    .unwrap()
                    .insert(action.clone(), keys);
            }
        }

        // Sort and print grouped shortcuts
        for group in grouped_shortcuts.keys().collect::<Vec<_>>().into_iter() {
            let group_shortcuts = &grouped_shortcuts[group];

            if group_shortcuts.len() == 1 {
                // Single shortcut - use dot notation
                let (action, keys) = group_shortcuts.iter().next().unwrap();
                let group_ident = self.format_nix_identifier(group);
                let action_ident = self.format_nix_identifier(action);
                println!(
                    "{}{}.{} = {};",
                    " ".repeat(indent),
                    group_ident,
                    action_ident,
                    keys
                );
            } else {
                // Multiple shortcuts - use nested structure
                let group_ident = self.format_nix_identifier(group);
                println!("{}{} = {{", " ".repeat(indent), group_ident);

                for (action, keys) in group_shortcuts {
                    let action_ident = self.format_nix_identifier(action);
                    println!("{}{} = {};", " ".repeat(indent + 2), action_ident, keys);
                }

                println!("{}}};", " ".repeat(indent));
            }
        }
    }

    fn print_settings_nested(
        &self,
        settings: &FileSettingsMap,
        indent: usize,
        filter_shortcuts: bool,
    ) {
        for (file, file_settings) in settings {
            if filter_shortcuts && file == "kglobalshortcutsrc" {
                continue;
            }

            let file_structure = self.build_file_structure(file_settings, filter_shortcuts);
            self.print_nested_structure(&self.format_nix_identifier(file), &file_structure, indent);
        }
    }

    fn build_file_structure(
        &self,
        file_settings: &SettingsMap,
        filter_shortcuts: bool,
    ) -> NestedValue {
        let mut file_map = IndexMap::new();

        for (group, group_settings) in file_settings {
            let mut group_map = IndexMap::new();

            for (key, value) in group_settings {
                if filter_shortcuts && key == "_k_friendly_name" {
                    continue;
                }
                group_map.insert(key.clone(), NestedValue::Leaf(value.clone()));
            }

            if !group_map.is_empty() {
                if group.is_empty() {
                    for (key, value) in group_map {
                        file_map.insert(key, value);
                    }
                } else {
                    file_map.insert(group.clone(), NestedValue::Node(group_map));
                }
            }
        }

        NestedValue::Node(file_map)
    }

    fn print_nested_structure(&self, name: &str, structure: &NestedValue, indent: usize) {
        match structure {
            NestedValue::Leaf(value) => {
                println!(
                    "{}{} = {};",
                    " ".repeat(indent),
                    name,
                    self.nix_value(value)
                );
            }
            NestedValue::Node(map) => {
                if map.len() == 1 {
                    // Single child - use dot notation
                    let (child_name, child_structure) = map.iter().next().unwrap();
                    let child_ident = self.format_nix_identifier(child_name);

                    match child_structure {
                        NestedValue::Leaf(value) => {
                            println!(
                                "{}{}.{} = {};",
                                " ".repeat(indent),
                                name,
                                child_ident,
                                self.nix_value(value)
                            );
                        }
                        NestedValue::Node(child_map) => {
                            if child_map.len() == 1 {
                                // Continue with dot notation
                                let (grandchild_name, grandchild_structure) =
                                    child_map.iter().next().unwrap();
                                let grandchild_ident = self.format_nix_identifier(grandchild_name);

                                match grandchild_structure {
                                    NestedValue::Leaf(value) => {
                                        println!(
                                            "{}{}.{}.{} = {};",
                                            " ".repeat(indent),
                                            name,
                                            child_ident,
                                            grandchild_ident,
                                            self.nix_value(value)
                                        );
                                    }
                                    NestedValue::Node(_) => {
                                        // Too deep, switch to nested structure
                                        println!(
                                            "{}{}.{} = {{",
                                            " ".repeat(indent),
                                            name,
                                            child_ident
                                        );
                                        self.print_nested_structure(
                                            &grandchild_ident,
                                            grandchild_structure,
                                            indent + 2,
                                        );
                                        println!("{}}};", " ".repeat(indent));
                                    }
                                }
                            } else {
                                // Multiple children, use nested structure
                                println!("{}{}.{} = {{", " ".repeat(indent), name, child_ident);
                                for (child_child_name, child_child_structure) in child_map {
                                    let child_child_ident =
                                        self.format_nix_identifier(child_child_name);
                                    self.print_nested_structure(
                                        &child_child_ident,
                                        child_child_structure,
                                        indent + 2,
                                    );
                                }
                                println!("{}}};", " ".repeat(indent));
                            }
                        }
                    }
                } else {
                    // Multiple children - use nested structure
                    println!("{}{} = {{", " ".repeat(indent), name);
                    for (child_name, child_structure) in map {
                        let child_ident = self.format_nix_identifier(child_name);
                        self.print_nested_structure(&child_ident, child_structure, indent + 2);
                    }
                    println!("{}}};", " ".repeat(indent));
                }
            }
        }
    }

    // TODO: Find a better way to do this
    fn parse_shortcut_keys(&self, value: &str) -> String {
        // Parse shortcut string similar to Ruby/Python implementations
        let first_part = value.split(r"(?<!\\),").next().unwrap_or("");
        let unescaped = first_part.replace(r"\,", ",").replace(r"\t", "\t");
        let keys: Vec<&str> = unescaped.split('\t').collect();

        if keys.is_empty() || keys[0].is_empty() || keys[0] == "none" {
            "[ ]".to_string()
        } else if keys.len() > 1 {
            let key_values: Vec<String> = keys
                .iter()
                .filter(|k| !k.is_empty())
                .map(|k| self.nix_value(&k.trim_end_matches(',')))
                .collect();
            format!("[ {} ]", key_values.join(" "))
        } else {
            let key = keys[0].trim_end_matches(',');
            if key.is_empty() || key == "none" {
                "[ ]".to_string()
            } else {
                // Handle cases like "Meta+L,Meta+L,Lock Session" -> "Meta+L"
                let parts: Vec<&str> = key.split(',').collect();
                if parts.len() == 3 && parts[0] == parts[1] {
                    self.nix_value(parts[0])
                } else {
                    self.nix_value(key)
                }
            }
        }
    }

    fn format_nix_identifier(&self, s: &str) -> String {
        // Same pattern as `lib.strings.escapeNixIdentifier`
        let valid_pattern = Regex::new(r"^[a-zA-Z_][a-zA-Z0-9_'-]*$").unwrap();

        if valid_pattern.is_match(s) {
            s.to_string()
        } else {
            let escaped = s
                .replace('\\', r"\\")
                .replace('"', r#"\""#)
                .replace('$', r"\$");
            format!(r#""{}""#, escaped)
        }
    }

    fn nix_value(&self, s: &str) -> String {
        if s.is_empty() {
            return r#""""#.to_string();
        }

        if s.eq_ignore_ascii_case("true") || s.eq_ignore_ascii_case("false") {
            return s.to_lowercase();
        }

        if Regex::new(r"^[0-9]+(\.[0-9]+)?$").unwrap().is_match(s) {
            return s.to_string();
        }

        let escaped = s
            .replace('\\', r"\\")
            .replace('"', r#"\""#)
            .replace('$', r"\$");

        format!(r#""{}""#, escaped)
    }
}
