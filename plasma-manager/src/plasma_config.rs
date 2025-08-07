use indexmap::IndexMap;
use regex::Regex;

// Shared type definitions
pub type SettingsMap = IndexMap<String, IndexMap<String, String>>;
pub type FileSettingsMap = IndexMap<String, SettingsMap>;

/// Known configuration files to scan by default
pub const KNOWN_CONFIG_FILES: &[&str] = &[
    "kcminputrc",
    "kglobalshortcutsrc",
    "kactivitymanagerdrc",
    "ksplashrc",
    "kwin_rules_dialogrc",
    "kmixrc",
    "kwalletrc",
    "kgammarc",
    "krunnerrc",
    "klaunchrc",
    "plasmanotifyrc",
    "systemsettingsrc",
    "kscreenlockerrc",
    "kwinrulesrc",
    "khotkeysrc",
    "ksmserverrc",
    "kded5rc",
    "plasmarc",
    "kwinrc",
    "kdeglobals",
    "baloofilerc",
    "dolphinrc",
    "klipperrc",
    "plasma-localerc",
    "kxkbrc",
    "ffmpegthumbsrc",
    "kservicemenurc",
    "kiorc",
    "ktrashrc",
    "kuriikwsfilterrc",
    "plasmaparc",
    "spectaclerc",
    "katerc",
];

/// Known data files to scan by default
pub const KNOWN_DATA_FILES: &[&str] = &[
    "kate/anonymous.katesession",
    "dolphin/view_properties/global/.directory",
];

/// Group patterns that should be blocked from being processed
pub const GROUP_BLOCK_LIST: &[&str] = &[
    r"^(ConfigDialog|FileDialogSize|ViewPropertiesDialog|KPropertiesDialog)$",
    r"^\$Version$",
    r"^ColorEffects:",
    r"^Colors:",
    r"^DoNotDisturb$",
    r"^LegacySession:",
    r"^MainWindow$",
    r"^PlasmaViews",
    r"^ScreenConnectors$",
    r"^Session:",
    r"^Recent (Files|URLs)",
];

/// Key patterns that should be blocked from being processed
pub const KEY_BLOCK_LIST: &[&str] = &[
    r"^activate widget \d+$", // Depends on state
    r"^ColorScheme(Hash)?$",
    r"^History Items",
    r"^LookAndFeelPackage$",
    r"^Recent (Files|URLs)",
    r"(?i)^Theme$",
    r"^Version$",
    r"State$",
    r"Timestamp$",
];

/// Check if a group should be skipped based on block list patterns
pub fn should_skip_group(group: &str) -> bool {
    GROUP_BLOCK_LIST
        .iter()
        .any(|pattern| Regex::new(pattern).unwrap().is_match(group))
}

/// Check if a key should be skipped based on block list patterns
pub fn should_skip_key(key: &str) -> bool {
    KEY_BLOCK_LIST
        .iter()
        .any(|pattern| Regex::new(pattern).unwrap().is_match(key))
}

/// Check if a specific group/key combination should be skipped based on custom rules
pub fn should_skip_by_lambda(group: &str, key: &str) -> bool {
    // Lambda-based blocking rules from the original implementations
    group == "org.kde.kdecoration2" && key == "library"
}

/// Check if a file-specific key should be skipped
pub fn should_skip_file_specific(file_name: &str, key: &str) -> bool {
    file_name == "plasmanotifyrc" && key == "Seen"
}
