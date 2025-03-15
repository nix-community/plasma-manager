use etcetera::{choose_base_strategy, BaseStrategy};
use kconfig_rs::Ini;
use std::{
    fs,
    io::{Error, ErrorKind},
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
