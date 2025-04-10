use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Operation {
    Write,
    Read,
    Delete,
}

#[derive(Deserialize, Serialize)]
#[serde(untagged)]
pub enum EntryContent {
    WriteEntries(HashMap<String, String>),
    ReadDeleteEntries(Vec<String>),
}

#[derive(Deserialize, Serialize)]
pub struct ConfigEntry {
    pub file: String,
    pub group: Option<String>,
    pub operation: Operation,
    pub entries: EntryContent,
    pub xdg_directory: String,
}

#[derive(Deserialize, Serialize)]
pub struct ConfigFile {
    #[serde(rename = "$schema")]
    pub schema: String,
    pub operations: Vec<ConfigEntry>,
}
