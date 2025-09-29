use serde::{Deserialize, Serialize};

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "lowercase", tag = "operation")]
pub enum ConfigEntry {
    Write {
        file: String,
        group: Option<String>,
        key: Option<String>,
        value: Option<String>,
        xdg_directory: String,
        #[serde(default)]
        immutable: bool,
        #[serde(default)]
        expand_environment: bool,
    },
    Read {
        file: String,
        group: Option<String>,
        key: Option<String>,
        xdg_directory: String,
        #[serde(default)]
        raw: bool,
    },
    Delete {
        file: String,
        group: Option<String>,
        key: Option<String>,
        xdg_directory: String,
    },
}

#[derive(Deserialize, Serialize)]
pub struct ConfigFile {
    #[serde(rename = "$schema", skip_serializing_if = "Option::is_none")]
    pub schema: Option<String>,
    pub operations: Vec<ConfigEntry>,
}
