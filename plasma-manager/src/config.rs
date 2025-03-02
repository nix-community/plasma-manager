use etcetera::{choose_base_strategy, BaseStrategy};
use std::{
    collections::HashMap,
    fs::{self, File},
    io::{Error, ErrorKind, Write},
    path::PathBuf,
};

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

    if !full_path.exists() {
        File::create(&full_path)?;
    }

    let content = fs::read_to_string(&full_path)?;
    let lines: Vec<String> = content.lines().map(String::from).collect();
    let mut sections: HashMap<String, Vec<(String, String)>> = HashMap::new();
    let mut current_section = String::new();

    for line in &lines {
        let trimmed = line.trim();

        if trimmed.starts_with('[') && trimmed.ends_with(']') {
            current_section = trimmed
                .trim_start_matches('[')
                .trim_end_matches(']')
                .to_string();
            sections
                .entry(current_section.clone())
                .or_default();
        } else if !trimmed.is_empty() && trimmed.contains('=') {
            let parts: Vec<&str> = trimmed.splitn(2, '=').collect();
            if parts.len() == 2 {
                sections
                    .entry(current_section.clone())
                    .or_default()
                    .push((parts[0].trim().to_string(), parts[1].trim().to_string()));
            }
        }
    }

    let target_section = match group {
        Some(group) if group.contains('/') => {
            let parts: Vec<&str> = group.split('/').collect();
            let mut section_name = String::from("[");
            section_name.push_str(parts[0]);
            section_name.push(']');

            for part in parts.iter().skip(1) {
                section_name.push('[');
                section_name.push_str(part);
                section_name.push(']');
            }

            section_name
                .trim_start_matches('[')
                .trim_end_matches(']')
                .to_string()
        }
        Some(group) => group.to_string(),
        None => String::new(),
    };

    let key_exists = sections
        .get(&target_section)
        .map(|entries| entries.iter().any(|(k, _)| k == key))
        .unwrap_or(false);

    if key_exists {
        if let Some(entries) = sections.get_mut(&target_section) {
            for entry in entries.iter_mut() {
                if entry.0 == key {
                    entry.1 = value.to_string();
                    break;
                }
            }
        }
    } else {
        sections
            .entry(target_section.clone())
            .or_default()
            .push((key.to_string(), value.to_string()));
    }

    let mut output = File::create(&full_path)?;

    if let Some(global_entries) = sections.get("") {
        for (k, v) in global_entries {
            writeln!(output, "{}={}", k, v)?;
        }

        if !global_entries.is_empty() && sections.len() > 1 {
            writeln!(output)?;
        }
    }

    for (section, entries) in &sections {
        if section.is_empty() {
            continue;
        }

        if !entries.is_empty() {
            writeln!(output, "[{}]", section)?;
            for (k, v) in entries {
                writeln!(output, "{}={}", k, v)?;
            }

            writeln!(output)?;
        }
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
