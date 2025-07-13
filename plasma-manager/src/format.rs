use crate::schema::ConfigFile;
use std::{
    fmt,
    io::{Error, ErrorKind},
    path::Path,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Format {
    Json,
    Ron,
    Toml,
}

impl fmt::Display for Format {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Format::Json => write!(f, "JSON"),
            Format::Ron => write!(f, "RON"),
            Format::Toml => write!(f, "TOML"),
        }
    }
}

impl std::str::FromStr for Format {
    type Err = Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "json" => Ok(Format::Json),
            "ron" => Ok(Format::Ron),
            "toml" => Ok(Format::Toml),
            _ => Err(Error::new(
                ErrorKind::InvalidInput,
                format!("Unsupported format: {}", s),
            )),
        }
    }
}

impl Format {
    /// Detect format from file extension
    pub fn from_extension(path: &Path) -> Option<Self> {
        path.extension()
            .and_then(|ext| ext.to_str())
            .and_then(|ext| match ext.to_lowercase().as_str() {
                "json" => Some(Format::Json),
                "ron" => Some(Format::Ron),
                "toml" => Some(Format::Toml),
                _ => None,
            })
    }

    /// Get the default file extension for this format
    #[allow(dead_code)]
    pub fn extension(&self) -> &'static str {
        match self {
            Format::Json => "json",
            Format::Ron => "ron",
            Format::Toml => "toml",
        }
    }

    /// Serialize a ConfigFile to a string in this format
    pub fn serialize(&self, config: &ConfigFile) -> Result<String, Error> {
        match self {
            Format::Json => serde_json::to_string_pretty(config).map_err(|e| {
                Error::new(
                    ErrorKind::InvalidData,
                    format!("Failed to serialize to JSON: {}", e),
                )
            }),
            Format::Ron => ron::to_string(config).map_err(|e| {
                Error::new(
                    ErrorKind::InvalidData,
                    format!("Failed to serialize to RON: {}", e),
                )
            }),
            Format::Toml => toml::to_string(config).map_err(|e| {
                Error::new(
                    ErrorKind::InvalidData,
                    format!("Failed to serialize to TOML: {}", e),
                )
            }),
        }
    }

    /// Deserialize a string to a ConfigFile from this format
    pub fn deserialize(&self, content: &str) -> Result<ConfigFile, Error> {
        match self {
            Format::Json => serde_json::from_str(content).map_err(|e| {
                Error::new(
                    ErrorKind::InvalidData,
                    format!("Failed to parse JSON: {}", e),
                )
            }),
            Format::Ron => ron::from_str(content).map_err(|e| {
                Error::new(
                    ErrorKind::InvalidData,
                    format!("Failed to parse RON: {}", e),
                )
            }),
            Format::Toml => toml::from_str(content).map_err(|e| {
                Error::new(
                    ErrorKind::InvalidData,
                    format!("Failed to parse TOML: {}", e),
                )
            }),
        }
    }

    /// Detect format from file content by trying to parse it
    pub fn detect_from_content(content: &str) -> Option<Self> {
        // Try JSON first (most common)
        if serde_json::from_str::<serde_json::Value>(content).is_ok() {
            return Some(Format::Json);
        }

        // Try RON
        if ron::from_str::<ron::Value>(content).is_ok() {
            return Some(Format::Ron);
        }

        // Try TOML
        if toml::from_str::<toml::Value>(content).is_ok() {
            return Some(Format::Toml);
        }

        None
    }
}

/// Auto-detect format from file path and optionally from content
pub fn detect_format(path: &Path, content: Option<&str>) -> Result<Format, Error> {
    // First try to detect from extension
    if let Some(format) = Format::from_extension(path) {
        return Ok(format);
    }

    // If no extension or unsupported extension, try content detection
    if let Some(content) = content {
        if let Some(format) = Format::detect_from_content(content) {
            return Ok(format);
        }
    }

    Err(Error::new(
        ErrorKind::InvalidInput,
        format!(
            "Could not determine format for file: {}. Supported formats: JSON, RON, TOML",
            path.display()
        ),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::schema::{ConfigEntry, EntryContent, Operation};
    use std::collections::HashMap;

    fn create_test_config() -> ConfigFile {
        let mut entries = HashMap::new();
        entries.insert("key1".to_string(), "value1".to_string());
        entries.insert("key2".to_string(), "value2".to_string());

        ConfigFile {
            schema: Some("test-schema".to_string()),
            operations: vec![ConfigEntry {
                file: "test.conf".to_string(),
                group: Some("TestGroup".to_string()),
                operation: Operation::Write,
                entries: EntryContent::WriteEntries(entries),
                xdg_directory: "config".to_string(),
            }],
        }
    }

    #[test]
    fn test_format_from_extension() {
        assert_eq!(
            Format::from_extension(Path::new("test.json")),
            Some(Format::Json)
        );
        assert_eq!(
            Format::from_extension(Path::new("test.ron")),
            Some(Format::Ron)
        );
        assert_eq!(
            Format::from_extension(Path::new("test.toml")),
            Some(Format::Toml)
        );
        assert_eq!(Format::from_extension(Path::new("test.txt")), None);
        assert_eq!(Format::from_extension(Path::new("test")), None);
    }

    #[test]
    fn test_format_extension() {
        assert_eq!(Format::Json.extension(), "json");
        assert_eq!(Format::Ron.extension(), "ron");
        assert_eq!(Format::Toml.extension(), "toml");
    }

    #[test]
    fn test_format_display() {
        assert_eq!(format!("{}", Format::Json), "JSON");
        assert_eq!(format!("{}", Format::Ron), "RON");
        assert_eq!(format!("{}", Format::Toml), "TOML");
    }

    #[test]
    fn test_format_from_str() {
        assert!(matches!("json".parse::<Format>(), Ok(Format::Json)));
        assert!(matches!("ron".parse::<Format>(), Ok(Format::Ron)));
        assert!(matches!("toml".parse::<Format>(), Ok(Format::Toml)));
        assert!(matches!("JSON".parse::<Format>(), Ok(Format::Json)));
        assert!("invalid".parse::<Format>().is_err());
    }

    #[test]
    fn test_serialize_deserialize_json() {
        let config = create_test_config();
        let serialized = Format::Json.serialize(&config).unwrap();
        let deserialized = Format::Json.deserialize(&serialized).unwrap();

        assert_eq!(config.operations.len(), deserialized.operations.len());
        assert_eq!(config.schema, deserialized.schema);
    }

    #[test]
    fn test_serialize_deserialize_ron() {
        let mut config = create_test_config();
        config.schema = None; // RON doesn't support schema field

        let serialized = Format::Ron.serialize(&config).unwrap();
        let deserialized = Format::Ron.deserialize(&serialized).unwrap();

        assert_eq!(config.operations.len(), deserialized.operations.len());
    }

    #[test]
    fn test_serialize_deserialize_toml() {
        let config = create_test_config();

        let serialized = Format::Toml.serialize(&config).unwrap();
        let deserialized = Format::Toml.deserialize(&serialized).unwrap();

        assert_eq!(config.operations.len(), deserialized.operations.len());
        assert_eq!(config.schema, deserialized.schema);
    }

    #[test]
    fn test_detect_format_from_path() {
        let json_path = Path::new("/tmp/config.json");
        let ron_path = Path::new("/tmp/config.ron");
        let toml_path = Path::new("/tmp/config.toml");

        assert!(matches!(detect_format(json_path, None), Ok(Format::Json)));
        assert!(matches!(detect_format(ron_path, None), Ok(Format::Ron)));
        assert!(matches!(detect_format(toml_path, None), Ok(Format::Toml)));
    }
}
