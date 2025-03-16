use etcetera::{choose_base_strategy, BaseStrategy};
use kconfig_rs::Ini;
use std::{
    fs,
    io::{Error, ErrorKind},
    path::PathBuf,
};
use tabled::{settings::Style, Table, Tabled};

#[derive(Tabled)]
struct ConfigEntry {
    #[tabled(rename = "Group")]
    section: String,
    #[tabled(rename = "Key")]
    key: String,
    #[tabled(rename = "Value")]
    value: String,
}

#[derive(Tabled)]
struct SectionEntry {
    #[tabled(rename = "Key")]
    key: String,
    #[tabled(rename = "Value")]
    value: String,
}

pub fn write_configuration(
    file: &str,
    group: Option<&str>,
    key: &str,
    value: &str,
    xdg_dir: &str,
) -> Result<(), Error> {
    let base_dir = get_xdg_directory(xdg_dir)?;
    let full_path = base_dir.join(file);

    if let Some(parent) = full_path.parent() {
        fs::create_dir_all(parent)?;
    }

    let mut ini = if full_path.exists() {
        Ini::load_from_file(&full_path)
            .map_err(|e| Error::new(ErrorKind::Other, format!("Failed to parse INI file: {}", e)))?
    } else {
        Ini::new()
    };

    let section_parts = group.map(|g| {
        if g.contains('/') {
            g.split('/').map(String::from).collect::<Vec<String>>()
        } else {
            vec![g.to_string()]
        }
    });

    ini.with_section(section_parts).set(key, value);

    ini.write_to_file(full_path)
        .map_err(|e| Error::new(ErrorKind::Other, format!("Failed to write INI file: {}", e)))
}

pub fn read_configuration(
    file: &str,
    group: Option<&str>,
    key: Option<&str>,
    xdg_dir: &str,
    raw: bool,
) -> Result<String, Error> {
    let base_dir = get_xdg_directory(xdg_dir)?;
    let full_path = base_dir.join(file);

    if !full_path.exists() {
        return Err(Error::new(
            ErrorKind::NotFound,
            format!("Configuration file not found: {}", full_path.display()),
        ));
    }

    let ini = Ini::load_from_file(&full_path)
        .map_err(|e| Error::new(ErrorKind::Other, format!("Failed to parse INI file: {}", e)))?;

    let section_key = group.map(|g| {
        if g.contains('/') {
            g.split('/').map(String::from).collect::<Vec<String>>()
        } else {
            vec![g.to_string()]
        }
    });

    if let Some(section_key) = section_key.clone() {
        if let Some(k) = key {
            match ini.get_from(Some(section_key), k) {
                Some(value) => return Ok(value.to_string()),
                None => {
                    return Err(Error::new(
                        ErrorKind::NotFound,
                        format!("Key '{}' not found in group '{}'", k, group.unwrap()),
                    ))
                }
            }
        }
    }

    if raw {
        return format_raw_output(&ini, section_key.as_deref(), key);
    }

    if let Some(section_key) = section_key {
        match ini.section(Some(section_key.clone())) {
            Some(section) => {
                let mut section_entries = Vec::new();
                for (k, v) in section.iter() {
                    section_entries.push(SectionEntry {
                        key: k.to_string(),
                        value: v.to_string(),
                    });
                }

                if section_entries.is_empty() {
                    return Ok("No configuration entries found in this section.".to_string());
                }

                let table = Table::new(section_entries)
                    .with(Style::modern_rounded())
                    .to_string();
                Ok(table)
            }
            None => Err(Error::new(
                ErrorKind::NotFound,
                format!("Group '{}' not found", group.unwrap()),
            )),
        }
    } else {
        let mut entries = Vec::new();
        for (section_name, section) in ini.iter() {
            let section_str = match &section_name {
                Some(parts) => parts.join("/"),
                None => "".to_string(),
            };

            for (k, v) in section.iter() {
                entries.push(ConfigEntry {
                    section: section_str.clone(),
                    key: k.to_string(),
                    value: v.to_string(),
                });
            }
        }

        if entries.is_empty() {
            return Ok("No configuration entries found.".to_string());
        }

        let table = Table::new(entries)
            .with(Style::modern_rounded())
            .to_string();
        Ok(table)
    }
}

fn format_raw_output(
    ini: &Ini,
    section_key: Option<&[String]>,
    _key: Option<&str>,
) -> Result<String, Error> {
    let mut result = String::new();

    if let Some(section_key) = section_key {
        match ini.section(Some(section_key.to_vec())) {
            Some(section) => {
                let section_header = format!("[{}]\n", section_key.join("]["));
                result.push_str(&section_header);

                for (k, v) in section.iter() {
                    result.push_str(&format!("{}={}\n", k, v));
                }
            }
            None => {
                return Err(Error::new(
                    ErrorKind::NotFound,
                    format!("Group '{}' not found", section_key.join("][")),
                ))
            }
        }
    } else {
        for (section_name, section) in ini.iter() {
            if let Some(parts) = section_name {
                let section_header = format!("[{}]\n", parts.join("]["));
                result.push_str(&section_header);
            }

            for (k, v) in section.iter() {
                result.push_str(&format!("{}={}\n", k, v));
            }

            result.push('\n');
        }
    }

    Ok(result)
}

pub fn delete_configuration(
    file: &str,
    group: Option<&str>,
    key: Option<&str>,
    xdg_dir: &str,
) -> Result<(), Error> {
    let base_dir = get_xdg_directory(xdg_dir)?;
    let full_path = base_dir.join(file);

    if !full_path.exists() {
        return Err(Error::new(
            ErrorKind::NotFound,
            format!("Configuration file not found: {}", full_path.display()),
        ));
    }

    if group.is_none() && key.is_none() {
        fs::remove_file(&full_path)?;
    } else {
        let mut ini = Ini::load_from_file(&full_path).map_err(|e| {
            Error::new(ErrorKind::Other, format!("Failed to parse INI file: {}", e))
        })?;

        if let Some(key_name) = key {
            if let Some(group_name) = group {
                let section_key = if group_name.contains('/') {
                    group_name
                        .split('/')
                        .map(String::from)
                        .collect::<Vec<String>>()
                } else {
                    vec![group_name.to_string()]
                };

                if ini.delete_from(Some(section_key), key_name).is_none() {
                    return Err(Error::new(
                        ErrorKind::NotFound,
                        format!("Key '{}' not found in section '{}'", key_name, group_name),
                    ));
                }
            } else {
                if ini.delete_from(None::<Vec<String>>, key_name).is_none() {
                    return Err(Error::new(
                        ErrorKind::NotFound,
                        format!("Key '{}' not found in general section", key_name),
                    ));
                }
            }
        } else if let Some(group_name) = group {
            let section_key = if group_name.contains('/') {
                group_name
                    .split('/')
                    .map(String::from)
                    .collect::<Vec<String>>()
            } else {
                vec![group_name.to_string()]
            };

            if ini.delete(Some(section_key)).is_none() {
                return Err(Error::new(
                    ErrorKind::NotFound,
                    format!("Section '{}' not found in file", group_name),
                ));
            }
        }

        ini.write_to_file(&full_path).map_err(|e| {
            Error::new(ErrorKind::Other, format!("Failed to write INI file: {}", e))
        })?;
    }

    Ok(())
}

pub fn get_xdg_directory(directory: &str) -> Result<PathBuf, Error> {
    let strategy = choose_base_strategy().map_err(|e| Error::new(ErrorKind::Other, e))?;

    match directory.to_lowercase().as_str() {
        "config" => Ok(strategy.config_dir()),
        "data" => Ok(strategy.data_dir()),
        "cache" => Ok(strategy.cache_dir()),
        "state" => Ok(strategy
            .state_dir()
            .ok_or_else(|| Error::new(ErrorKind::NotFound, "State directory not found."))?),
        _ => Err(Error::new(
            ErrorKind::InvalidInput,
            format!(
                "Invalid directory type: {}. Valid values are: config, data, cache, state.",
                directory
            ),
        )),
    }
}
