// The MIT License (MIT)

// Copyright (c) 2025 Plasma Manager contributors
// Copyright (c) 2014 Y. T. CHUNG

// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//! KDE Configuration file parser and writer based on rust-ini
//!
//! ```no_run
//! use kconfig_rs::Ini;
//!
//! let mut conf = Ini::new();
//! conf.with_section(Some(vec!["User".to_string()]))
//!     .set("name", "Raspberry树莓")
//!     .set("value", "Pi");
//! conf.with_section(Some(vec!["Library".to_string()]))
//!     .set("name", "Sun Yat-sen U")
//!     .set("location", "Guangzhou=world");
//! // Nested sections
//! conf.with_section(Some(vec!["Display".to_string(), "Screen".to_string(), "Resolution".to_string()]))
//!     .set("width", "1920")
//!     .set("height", "1080");
//! conf.write_to_file("conf.ini").unwrap();
//!
//! let i = Ini::load_from_file("conf.ini").unwrap();
//! for (sec, prop) in i.iter() {
//!     println!("Section: {:?}", sec);
//!     for (k, v) in prop.iter() {
//!         println!("{}:{}", k, v);
//!     }
//! }
//! ```

use std::{
    borrow::Cow,
    char, error,
    fmt::{self, Display},
    fs::{File, OpenOptions},
    io::{self, Read, Seek, SeekFrom, Write},
    ops::{Index, IndexMut},
    path::Path,
    str::Chars,
};

use cfg_if::cfg_if;
use ordered_multimap::{
    list_ordered_multimap::{Entry, IntoIter, Iter, IterMut, OccupiedEntry, VacantEntry},
    ListOrderedMultimap,
};
use trim_in_place::TrimInPlace;
#[cfg(feature = "case-insensitive")]
use unicase::UniCase;

/// Policies for escaping logic
#[derive(Debug, PartialEq, Copy, Clone)]
pub enum EscapePolicy {
    /// Escape absolutely nothing (dangerous)
    Nothing,
    /// Only escape the most necessary things.
    /// This means backslashes, control characters (codepoints U+0000 to U+001F), and delete (U+007F).
    /// Quotes (single or double) are not escaped.
    Basics,
    /// Escape basics and non-ASCII characters in the [Basic Multilingual Plane](https://www.compart.com/en/unicode/plane)
    /// (i.e. between U+007F - U+FFFF)
    /// Codepoints above U+FFFF, e.g. '🐱' U+1F431 "CAT FACE" will *not* be escaped!
    BasicsUnicode,
    /// Escape basics and all non-ASCII characters, including codepoints above U+FFFF.
    /// This will escape emoji - if you want them to remain raw, use BasicsUnicode instead.
    BasicsUnicodeExtended,
    /// Escape reserved symbols.
    /// This includes everything in EscapePolicy::Basics, plus the comment characters ';' and '#' and the key/value-separating characters '=' and ':'.
    Reserved,
    /// Escape reserved symbols and non-ASCII characters in the BMP.
    /// Codepoints above U+FFFF, e.g. '🐱' U+1F431 "CAT FACE" will *not* be escaped!
    ReservedUnicode,
    /// Escape reserved symbols and all non-ASCII characters, including codepoints above U+FFFF.
    ReservedUnicodeExtended,
    /// Escape everything that some INI implementations assume
    Everything,
}

impl EscapePolicy {
    fn escape_basics(self) -> bool {
        self != EscapePolicy::Nothing
    }

    fn escape_reserved(self) -> bool {
        matches!(
            self,
            EscapePolicy::Reserved
                | EscapePolicy::ReservedUnicode
                | EscapePolicy::ReservedUnicodeExtended
                | EscapePolicy::Everything
        )
    }

    fn escape_unicode(self) -> bool {
        matches!(
            self,
            EscapePolicy::BasicsUnicode
                | EscapePolicy::BasicsUnicodeExtended
                | EscapePolicy::ReservedUnicode
                | EscapePolicy::ReservedUnicodeExtended
                | EscapePolicy::Everything
        )
    }

    fn escape_unicode_extended(self) -> bool {
        matches!(
            self,
            EscapePolicy::BasicsUnicodeExtended
                | EscapePolicy::ReservedUnicodeExtended
                | EscapePolicy::Everything
        )
    }

    /// Given a character this returns true if it should be escaped as
    /// per this policy or false if not.
    pub fn should_escape(self, c: char) -> bool {
        match c {
            // A single backslash, must be escaped
            // ASCII control characters, U+0000 NUL..= U+001F UNIT SEPARATOR, or U+007F DELETE. The same as char::is_ascii_control()
            '\\' | '\x00'..='\x1f' | '\x7f' => self.escape_basics(),
            ';' | '#' | '=' | ':' => self.escape_reserved(),
            '\u{0080}'..='\u{FFFF}' => self.escape_unicode(),
            '\u{10000}'..='\u{10FFFF}' => self.escape_unicode_extended(),
            _ => false,
        }
    }
}

// Escape non-INI characters
//
// Common escape sequences: https://en.wikipedia.org/wiki/INI_file#Escape_characters
//
// * `\\` \ (a single backslash, escaping the escape character)
// * `\0` Null character
// * `\a` Bell/Alert/Audible
// * `\b` Backspace, Bell character for some applications
// * `\t` Tab character
// * `\r` Carriage return
// * `\n` Line feed
// * `\;` Semicolon
// * `\#` Number sign
// * `\=` Equals sign
// * `\:` Colon
// * `\x????` Unicode character with hexadecimal code point corresponding to ????
fn escape_str(s: &str, policy: EscapePolicy) -> String {
    let mut escaped: String = String::with_capacity(s.len());
    for c in s.chars() {
        // if we know this is not something to escape as per policy, we just
        // write it and continue.
        if !policy.should_escape(c) {
            escaped.push(c);
            continue;
        }

        match c {
            '\\' => escaped.push_str("\\\\"),
            '\0' => escaped.push_str("\\0"),
            '\x01'..='\x06' | '\x0e'..='\x1f' | '\x7f'..='\u{00ff}' => {
                escaped.push_str(&format!("\\x{:04x}", c as isize)[..])
            }
            '\x07' => escaped.push_str("\\a"),
            '\x08' => escaped.push_str("\\b"),
            '\x0c' => escaped.push_str("\\f"),
            '\x0b' => escaped.push_str("\\v"),
            '\n' => escaped.push_str("\\n"),
            '\t' => escaped.push_str("\\t"),
            '\r' => escaped.push_str("\\r"),
            '\u{0080}'..='\u{FFFF}' => escaped.push_str(&format!("\\x{:04x}", c as isize)[..]),
            // Longer escapes.
            '\u{10000}'..='\u{FFFFF}' => escaped.push_str(&format!("\\x{:05x}", c as isize)[..]),
            '\u{100000}'..='\u{10FFFF}' => escaped.push_str(&format!("\\x{:06x}", c as isize)[..]),
            _ => {
                escaped.push('\\');
                escaped.push(c);
            }
        }
    }
    escaped
}

/// Parsing configuration
pub struct ParseOption {
    /// Allow quote (`"` or `'`) in value
    /// For example
    /// ```ini
    /// [Section]
    /// Key1="Quoted value"
    /// Key2='Single Quote' with extra value
    /// ```
    ///
    /// In this example, Value of `Key1` is `Quoted value`,
    /// and value of `Key2` is `Single Quote with extra value`
    /// if `enabled_quote` is set to `true`.
    pub enabled_quote: bool,

    /// Interpret `\` as an escape character
    /// For example
    /// ```ini
    /// [Section]
    /// Key1=C:\Windows
    /// ```
    ///
    /// If `enabled_escape` is true, then the value of `Key` will become `C:Windows` (`\W` equals to `W`).
    pub enabled_escape: bool,

    /// Enables values that span lines
    /// ```ini
    /// [Section]
    /// foo=
    ///   b
    ///   c
    /// ```
    pub enabled_indented_mutiline_value: bool,
}

impl Default for ParseOption {
    fn default() -> ParseOption {
        ParseOption {
            enabled_quote: true,
            enabled_escape: true,
            enabled_indented_mutiline_value: false,
        }
    }
}

/// Newline style
#[derive(Debug, Copy, Clone, Eq, PartialEq)]
pub enum LineSeparator {
    /// System-dependent line separator
    ///
    /// On UNIX system, uses "\n"
    /// On Windows system, uses "\r\n"
    SystemDefault,

    /// Uses "\n" as new line separator
    CR,

    /// Uses "\r\n" as new line separator
    CRLF,
}

#[cfg(not(windows))]
static DEFAULT_LINE_SEPARATOR: &str = "\n";

#[cfg(windows)]
static DEFAULT_LINE_SEPARATOR: &str = "\r\n";

static DEFAULT_KV_SEPARATOR: &str = "=";

impl fmt::Display for LineSeparator {
    fn fmt(&self, f: &mut fmt::Formatter) -> Result<(), fmt::Error> {
        f.write_str(self.as_str())
    }
}

impl LineSeparator {
    /// String representation
    pub fn as_str(self) -> &'static str {
        match self {
            LineSeparator::SystemDefault => DEFAULT_LINE_SEPARATOR,
            LineSeparator::CR => "\n",
            LineSeparator::CRLF => "\r\n",
        }
    }
}

/// Writing configuration
#[derive(Debug, Clone)]
pub struct WriteOption {
    /// Policies about how to escape characters
    pub escape_policy: EscapePolicy,

    /// Newline style
    pub line_separator: LineSeparator,

    /// Key value separator
    pub kv_separator: &'static str,
}

impl Default for WriteOption {
    fn default() -> WriteOption {
        WriteOption {
            escape_policy: EscapePolicy::Basics,
            line_separator: LineSeparator::SystemDefault,
            kv_separator: DEFAULT_KV_SEPARATOR,
        }
    }
}

cfg_if! {
    if #[cfg(feature = "case-insensitive")] {
        /// Internal storage of section's key
        pub type SectionKey = Option<Vec<UniCase<String>>>;
        /// Internal storage of property's key
        pub type PropertyKey = UniCase<String>;

        macro_rules! property_get_key {
            ($s:expr) => {
                &UniCase::from($s)
            };
        }

        macro_rules! property_insert_key {
            ($s:expr) => {
                UniCase::from($s)
            };
        }

        macro_rules! section_key {
            ($s:expr) => {
                $s.map(|s| s.into_iter().map(|part| UniCase::from(part)).collect())
            };
        }

    } else {
        /// Internal storage of section's key
        pub type SectionKey = Option<Vec<String>>;
        /// Internal storage of property's key
        pub type PropertyKey = String;

        macro_rules! property_get_key {
            ($s:expr) => {
                $s
            };
        }

        macro_rules! property_insert_key {
            ($s:expr) => {
                $s
            };
        }

        macro_rules! section_key {
            ($s:expr) => {
                $s.map(|s| s.into_iter().map(Into::into).collect())
            };
        }
    }
}

/// A setter which could be used to set key-value pair in a specified section
pub struct SectionSetter<'a> {
    ini: &'a mut Ini,
    section_name: Option<Vec<String>>,
}

impl<'a> SectionSetter<'a> {
    fn new(ini: &'a mut Ini, section_name: Option<Vec<String>>) -> SectionSetter<'a> {
        SectionSetter { ini, section_name }
    }

    /// Set (replace) key-value pair in this section (all with the same name)
    pub fn set<'b, K, V>(&'b mut self, key: K, value: V) -> &'b mut SectionSetter<'a>
    where
        K: Into<String>,
        V: Into<String>,
        'a: 'b,
    {
        self.ini
            .entry(self.section_name.clone())
            .or_insert_with(Default::default)
            .insert(key, value);

        self
    }

    /// Add (append) key-value pair in this section
    pub fn add<'b, K, V>(&'b mut self, key: K, value: V) -> &'b mut SectionSetter<'a>
    where
        K: Into<String>,
        V: Into<String>,
        'a: 'b,
    {
        self.ini
            .entry(self.section_name.clone())
            .or_insert_with(Default::default)
            .append(key, value);

        self
    }

    /// Delete the first entry in this section with `key`
    pub fn delete<'b, K>(&'b mut self, key: &K) -> &'b mut SectionSetter<'a>
    where
        K: AsRef<str>,
        'a: 'b,
    {
        for prop in self.ini.section_all_mut(self.section_name.as_ref()) {
            prop.remove(key);
        }

        self
    }

    /// Get the entry in this section with `key`
    pub fn get<K: AsRef<str>>(&'a self, key: K) -> Option<&'a str> {
        self.ini
            .section(self.section_name.as_ref())
            .and_then(|prop| prop.get(key))
            .map(AsRef::as_ref)
    }
}

/// Properties type (key-value pairs)
#[derive(Clone, Default, Debug, PartialEq)]
pub struct Properties {
    data: ListOrderedMultimap<PropertyKey, String>,
}

impl Properties {
    /// Create an instance
    pub fn new() -> Properties {
        Default::default()
    }

    /// Get the number of the properties
    pub fn len(&self) -> usize {
        self.data.keys_len()
    }

    /// Check if properties has 0 elements
    pub fn is_empty(&self) -> bool {
        self.data.is_empty()
    }

    /// Get an iterator of the properties
    pub fn iter(&self) -> PropertyIter {
        PropertyIter {
            inner: self.data.iter(),
        }
    }

    /// Get a mutable iterator of the properties
    pub fn iter_mut(&mut self) -> PropertyIterMut {
        PropertyIterMut {
            inner: self.data.iter_mut(),
        }
    }

    /// Return true if property exist
    pub fn contains_key<S: AsRef<str>>(&self, s: S) -> bool {
        self.data.contains_key(property_get_key!(s.as_ref()))
    }

    /// Insert (key, value) pair by replace
    pub fn insert<K, V>(&mut self, k: K, v: V)
    where
        K: Into<String>,
        V: Into<String>,
    {
        self.data.insert(property_insert_key!(k.into()), v.into());
    }

    /// Append key with (key, value) pair
    pub fn append<K, V>(&mut self, k: K, v: V)
    where
        K: Into<String>,
        V: Into<String>,
    {
        self.data.append(property_insert_key!(k.into()), v.into());
    }

    /// Get the first value associate with the key
    pub fn get<S: AsRef<str>>(&self, s: S) -> Option<&str> {
        self.data
            .get(property_get_key!(s.as_ref()))
            .map(|v| v.as_str())
    }

    /// Get all values associate with the key
    pub fn get_all<S: AsRef<str>>(&self, s: S) -> impl DoubleEndedIterator<Item = &str> {
        self.data
            .get_all(property_get_key!(s.as_ref()))
            .map(|v| v.as_str())
    }

    /// Remove the property with the first value of the key
    pub fn remove<S: AsRef<str>>(&mut self, s: S) -> Option<String> {
        self.data.remove(property_get_key!(s.as_ref()))
    }

    /// Remove the property with all values with the same key
    pub fn remove_all<S: AsRef<str>>(
        &mut self,
        s: S,
    ) -> impl DoubleEndedIterator<Item = String> + '_ {
        self.data.remove_all(property_get_key!(s.as_ref()))
    }

    fn get_mut<S: AsRef<str>>(&mut self, s: S) -> Option<&mut str> {
        self.data
            .get_mut(property_get_key!(s.as_ref()))
            .map(|v| v.as_mut_str())
    }
}

impl<S: AsRef<str>> Index<S> for Properties {
    type Output = str;

    fn index(&self, index: S) -> &str {
        let s = index.as_ref();
        match self.get(s) {
            Some(p) => p,
            None => panic!("Key `{}` does not exist", s),
        }
    }
}

pub struct PropertyIter<'a> {
    inner: Iter<'a, PropertyKey, String>,
}

impl<'a> Iterator for PropertyIter<'a> {
    type Item = (&'a str, &'a str);

    fn next(&mut self) -> Option<Self::Item> {
        self.inner.next().map(|(k, v)| (k.as_ref(), v.as_ref()))
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.inner.size_hint()
    }
}

impl DoubleEndedIterator for PropertyIter<'_> {
    fn next_back(&mut self) -> Option<Self::Item> {
        self.inner
            .next_back()
            .map(|(k, v)| (k.as_ref(), v.as_ref()))
    }
}

/// Iterator for traversing sections
pub struct PropertyIterMut<'a> {
    inner: IterMut<'a, PropertyKey, String>,
}

impl<'a> Iterator for PropertyIterMut<'a> {
    type Item = (&'a str, &'a mut String);

    fn next(&mut self) -> Option<Self::Item> {
        self.inner.next().map(|(k, v)| (k.as_ref(), v))
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.inner.size_hint()
    }
}

impl DoubleEndedIterator for PropertyIterMut<'_> {
    fn next_back(&mut self) -> Option<Self::Item> {
        self.inner.next_back().map(|(k, v)| (k.as_ref(), v))
    }
}

pub struct PropertiesIntoIter {
    inner: IntoIter<PropertyKey, String>,
}

impl Iterator for PropertiesIntoIter {
    type Item = (String, String);

    #[cfg_attr(not(feature = "case-insensitive"), allow(clippy::useless_conversion))]
    fn next(&mut self) -> Option<Self::Item> {
        self.inner.next().map(|(k, v)| (k.into(), v))
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.inner.size_hint()
    }
}

impl DoubleEndedIterator for PropertiesIntoIter {
    #[cfg_attr(not(feature = "case-insensitive"), allow(clippy::useless_conversion))]
    fn next_back(&mut self) -> Option<Self::Item> {
        self.inner.next_back().map(|(k, v)| (k.into(), v))
    }
}

impl<'a> IntoIterator for &'a Properties {
    type IntoIter = PropertyIter<'a>;
    type Item = (&'a str, &'a str);

    fn into_iter(self) -> Self::IntoIter {
        self.iter()
    }
}

impl<'a> IntoIterator for &'a mut Properties {
    type IntoIter = PropertyIterMut<'a>;
    type Item = (&'a str, &'a mut String);

    fn into_iter(self) -> Self::IntoIter {
        self.iter_mut()
    }
}

impl IntoIterator for Properties {
    type IntoIter = PropertiesIntoIter;
    type Item = (String, String);

    fn into_iter(self) -> Self::IntoIter {
        PropertiesIntoIter {
            inner: self.data.into_iter(),
        }
    }
}

/// A view into a vacant entry in a `Ini`
pub struct SectionVacantEntry<'a> {
    inner: VacantEntry<'a, SectionKey, Properties>,
}

impl<'a> SectionVacantEntry<'a> {
    /// Insert one new section
    pub fn insert(self, value: Properties) -> &'a mut Properties {
        self.inner.insert(value)
    }
}

/// A view into a occupied entry in a `Ini`
pub struct SectionOccupiedEntry<'a> {
    inner: OccupiedEntry<'a, SectionKey, Properties>,
}

impl<'a> SectionOccupiedEntry<'a> {
    /// Into the first internal mutable properties
    pub fn into_mut(self) -> &'a mut Properties {
        self.inner.into_mut()
    }

    /// Append a new section
    pub fn append(&mut self, prop: Properties) {
        self.inner.append(prop);
    }

    fn last_mut(&'a mut self) -> &'a mut Properties {
        self.inner
            .iter_mut()
            .next_back()
            .expect("occupied section shouldn't have 0 property")
    }
}

/// A view into an `Ini`, which may either be vacant or occupied.
pub enum SectionEntry<'a> {
    Vacant(SectionVacantEntry<'a>),
    Occupied(SectionOccupiedEntry<'a>),
}

impl<'a> SectionEntry<'a> {
    /// Ensures a value is in the entry by inserting the default if empty, and returns a mutable reference to the value in the entry.
    pub fn or_insert(self, properties: Properties) -> &'a mut Properties {
        match self {
            SectionEntry::Occupied(e) => e.into_mut(),
            SectionEntry::Vacant(e) => e.insert(properties),
        }
    }

    /// Ensures a value is in the entry by inserting the result of the default function if empty, and returns a mutable reference to the value in the entry.
    pub fn or_insert_with<F: FnOnce() -> Properties>(self, default: F) -> &'a mut Properties {
        match self {
            SectionEntry::Occupied(e) => e.into_mut(),
            SectionEntry::Vacant(e) => e.insert(default()),
        }
    }
}

impl<'a> From<Entry<'a, SectionKey, Properties>> for SectionEntry<'a> {
    fn from(e: Entry<'a, SectionKey, Properties>) -> SectionEntry<'a> {
        match e {
            Entry::Occupied(inner) => SectionEntry::Occupied(SectionOccupiedEntry { inner }),
            Entry::Vacant(inner) => SectionEntry::Vacant(SectionVacantEntry { inner }),
        }
    }
}

/// Helper function to format a section for display
pub fn format_section(section: Option<&[String]>) -> String {
    section
        .map(|parts| {
            parts
                .iter()
                .map(|part| format!("[{}]", part))
                .collect::<String>()
        })
        .unwrap_or_else(|| "General".to_string())
}

/// Ini struct
#[derive(Debug, Clone)]
pub struct Ini {
    sections: ListOrderedMultimap<SectionKey, Properties>,
}

impl Ini {
    /// Create an instance
    pub fn new() -> Ini {
        Default::default()
    }

    /// Set with a specified section, `None` is for the general section
    pub fn with_section<S>(&mut self, section: Option<S>) -> SectionSetter
    where
        S: IntoIterator,
        S::Item: Into<String>,
    {
        let section_vec = section.map(|s| s.into_iter().map(Into::into).collect());
        SectionSetter::new(self, section_vec)
    }

    /// Set with general section, a simple wrapper of `with_section(None::<String>)`
    pub fn with_general_section(&mut self) -> SectionSetter {
        self.with_section(None::<Vec<String>>)
    }

    /// Get the immutable general section
    pub fn general_section(&self) -> &Properties {
        self.section(None::<Vec<String>>)
            .expect("There is no general section in this Ini")
    }

    /// Get the mutable general section
    pub fn general_section_mut(&mut self) -> &mut Properties {
        self.section_mut(None::<Vec<String>>)
            .expect("There is no general section in this Ini")
    }

    /// Get a immutable section
    pub fn section<S>(&self, name: Option<S>) -> Option<&Properties>
    where
        S: IntoIterator,
        S::Item: Into<String>,
    {
        self.sections.get(&section_key!(name))
    }

    /// Get a mutable section
    pub fn section_mut<S>(&mut self, name: Option<S>) -> Option<&mut Properties>
    where
        S: IntoIterator,
        S::Item: Into<String>,
    {
        self.sections.get_mut(&section_key!(name))
    }

    /// Get all sections immutable with the same key
    pub fn section_all<S>(&self, name: Option<S>) -> impl DoubleEndedIterator<Item = &Properties>
    where
        S: IntoIterator,
        S::Item: Into<String>,
    {
        self.sections.get_all(&section_key!(name))
    }

    /// Get all sections mutable with the same key
    pub fn section_all_mut<S>(
        &mut self,
        name: Option<S>,
    ) -> impl DoubleEndedIterator<Item = &mut Properties>
    where
        S: IntoIterator,
        S::Item: Into<String>,
    {
        self.sections.get_all_mut(&section_key!(name))
    }

    /// Get the entry
    #[cfg(not(feature = "case-insensitive"))]
    pub fn entry(&mut self, name: Option<Vec<String>>) -> SectionEntry<'_> {
        SectionEntry::from(self.sections.entry(name))
    }

    /// Get the entry
    #[cfg(feature = "case-insensitive")]
    pub fn entry(&mut self, name: Option<Vec<String>>) -> SectionEntry<'_> {
        SectionEntry::from(
            self.sections
                .entry(name.map(|v| v.into_iter().map(UniCase::from).collect())),
        )
    }

    /// Clear all entries
    pub fn clear(&mut self) {
        self.sections.clear()
    }

    /// Iterate with sections
    pub fn sections(&self) -> impl DoubleEndedIterator<Item = Option<Vec<&str>>> {
        self.sections.keys().map(|s| {
            s.as_ref()
                .map(|vec| vec.iter().map(|s| s.as_ref()).collect())
        })
    }

    /// Set key-value to a section
    pub fn set_to<S>(&mut self, section: Option<S>, key: String, value: String)
    where
        S: IntoIterator,
        S::Item: Into<String>,
    {
        self.with_section(section).set(key, value);
    }

    /// Get the first value from the sections with key
    ///
    /// Example:
    ///
    /// ```
    /// use kconfig_rs::Ini;
    /// let input = "[sec]\nabc = def\n";
    /// let ini = Ini::load_from_str(input).unwrap();
    /// assert_eq!(ini.get_from(Some(vec!["sec"]), "abc"), Some("def"));
    /// ```
    pub fn get_from<'a, S>(&'a self, section: Option<S>, key: &str) -> Option<&'a str>
    where
        S: IntoIterator,
        S::Item: Into<String>,
    {
        self.sections
            .get(&section_key!(section))
            .and_then(|prop| prop.get(key))
    }

    /// Get the first value from the sections with key, return the default value if it does not exist
    ///
    /// Example:
    ///
    /// ```
    /// use kconfig_rs::Ini;
    /// let input = "[sec]\n";
    /// let ini = Ini::load_from_str(input).unwrap();
    /// assert_eq!(ini.get_from_or(Some(vec!["sec"]), "key", "default"), "default");
    /// ```
    pub fn get_from_or<'a, S>(&'a self, section: Option<S>, key: &str, default: &'a str) -> &'a str
    where
        S: IntoIterator,
        S::Item: Into<String>,
    {
        self.get_from(section, key).unwrap_or(default)
    }

    /// Get the first mutable value from the sections with key
    pub fn get_from_mut<'a, S>(&'a mut self, section: Option<S>, key: &str) -> Option<&'a mut str>
    where
        S: IntoIterator,
        S::Item: Into<String>,
    {
        self.sections
            .get_mut(&section_key!(section))
            .and_then(|prop| prop.get_mut(key))
    }

    /// Delete the first section with key, return the properties if it exists
    pub fn delete<S>(&mut self, section: Option<S>) -> Option<Properties>
    where
        S: IntoIterator,
        S::Item: Into<String>,
    {
        let key = section_key!(section);
        self.sections.remove(&key)
    }

    /// Delete the key from the section, return the value if key exists or None
    pub fn delete_from<S>(&mut self, section: Option<S>, key: &str) -> Option<String>
    where
        S: IntoIterator,
        S::Item: Into<String>,
    {
        self.section_mut(section).and_then(|prop| prop.remove(key))
    }

    /// Total sections count
    pub fn len(&self) -> usize {
        self.sections.keys_len()
    }

    /// Check if object contains no section
    pub fn is_empty(&self) -> bool {
        self.sections.is_empty()
    }
}

impl Default for Ini {
    /// Creates an ini instance with an empty general section. This allows [Ini::general_section]
    /// and [Ini::with_general_section] to be called without panicking.
    fn default() -> Self {
        let mut result = Ini {
            sections: Default::default(),
        };

        result.sections.insert(None, Default::default());

        result
    }
}

impl<S: IntoIterator> Index<Option<S>> for Ini
where
    S::Item: Into<String>,
{
    type Output = Properties;

    fn index(&self, index: Option<S>) -> &Properties {
        match self.section(index) {
            Some(p) => p,
            None => panic!("Section does not exist"),
        }
    }
}

impl<S: IntoIterator> IndexMut<Option<S>> for Ini
where
    S::Item: Into<String>,
{
    fn index_mut(&mut self, index: Option<S>) -> &mut Properties {
        match self.section_mut(index) {
            Some(p) => p,
            None => panic!("Section does not exist"),
        }
    }
}

impl<'q> Index<&'q str> for Ini {
    type Output = Properties;

    fn index<'a>(&'a self, index: &'q str) -> &'a Properties {
        match self.section(Some(vec![index.to_string()])) {
            Some(p) => p,
            None => panic!("Section `{}` does not exist", index),
        }
    }
}

impl<'q> IndexMut<&'q str> for Ini {
    fn index_mut<'a>(&'a mut self, index: &'q str) -> &'a mut Properties {
        match self.section_mut(Some(vec![index.to_string()])) {
            Some(p) => p,
            None => panic!("Section `{}` does not exist", index),
        }
    }
}

impl Ini {
    /// Write to a file
    pub fn write_to_file<P: AsRef<Path>>(&self, filename: P) -> io::Result<()> {
        self.write_to_file_policy(filename, EscapePolicy::Basics)
    }

    /// Write to a file
    pub fn write_to_file_policy<P: AsRef<Path>>(
        &self,
        filename: P,
        policy: EscapePolicy,
    ) -> io::Result<()> {
        let mut file = OpenOptions::new()
            .write(true)
            .truncate(true)
            .create(true)
            .open(filename.as_ref())?;
        self.write_to_policy(&mut file, policy)
    }

    /// Write to a file with options
    pub fn write_to_file_opt<P: AsRef<Path>>(
        &self,
        filename: P,
        opt: WriteOption,
    ) -> io::Result<()> {
        let mut file = OpenOptions::new()
            .write(true)
            .truncate(true)
            .create(true)
            .open(filename.as_ref())?;
        self.write_to_opt(&mut file, opt)
    }

    /// Write to a writer
    pub fn write_to<W: Write>(&self, writer: &mut W) -> io::Result<()> {
        self.write_to_opt(writer, Default::default())
    }

    /// Write to a writer
    pub fn write_to_policy<W: Write>(
        &self,
        writer: &mut W,
        policy: EscapePolicy,
    ) -> io::Result<()> {
        self.write_to_opt(
            writer,
            WriteOption {
                escape_policy: policy,
                ..Default::default()
            },
        )
    }

    /// Write to a writer with options
    pub fn write_to_opt<W: Write>(&self, writer: &mut W, opt: WriteOption) -> io::Result<()> {
        let mut firstline = true;

        for (section, props) in &self.sections {
            if !props.data.is_empty() {
                if firstline {
                    firstline = false;
                } else {
                    // Write an empty line between sections
                    writer.write_all(opt.line_separator.as_str().as_bytes())?;
                }
            }

            if let Some(ref section_parts) = *section {
                // Write nested sections in KDE format [Section][Subsection][Example]
                let section_str = section_parts
                    .iter()
                    .map(|part| format!("[{}]", escape_str(part, opt.escape_policy)))
                    .collect::<String>();
                write!(writer, "{}{}", section_str, opt.line_separator)?;
            }
            for (k, v) in props.iter() {
                let k_str = escape_str(k, opt.escape_policy);
                let v_str = escape_str(v, opt.escape_policy);
                write!(
                    writer,
                    "{}{}{}{}",
                    k_str, opt.kv_separator, v_str, opt.line_separator
                )?;
            }
        }
        Ok(())
    }
}

impl Ini {
    /// Load from a string
    pub fn load_from_str(buf: &str) -> Result<Ini, ParseError> {
        Ini::load_from_str_opt(buf, ParseOption::default())
    }

    /// Load from a string, but do not interpret '\' as an escape character
    pub fn load_from_str_noescape(buf: &str) -> Result<Ini, ParseError> {
        Ini::load_from_str_opt(
            buf,
            ParseOption {
                enabled_escape: false,
                ..ParseOption::default()
            },
        )
    }

    /// Load from a string with options
    pub fn load_from_str_opt(buf: &str, opt: ParseOption) -> Result<Ini, ParseError> {
        let mut parser = Parser::new(buf.chars(), opt);
        parser.parse()
    }

    /// Load from a reader
    pub fn read_from<R: Read>(reader: &mut R) -> Result<Ini, Error> {
        Ini::read_from_opt(reader, ParseOption::default())
    }

    /// Load from a reader, but do not interpret '\' as an escape character
    pub fn read_from_noescape<R: Read>(reader: &mut R) -> Result<Ini, Error> {
        Ini::read_from_opt(
            reader,
            ParseOption {
                enabled_escape: false,
                ..ParseOption::default()
            },
        )
    }

    /// Load from a reader with options
    pub fn read_from_opt<R: Read>(reader: &mut R, opt: ParseOption) -> Result<Ini, Error> {
        let mut s = String::new();
        reader.read_to_string(&mut s).map_err(Error::Io)?;
        let mut parser = Parser::new(s.chars(), opt);
        match parser.parse() {
            Err(e) => Err(Error::Parse(e)),
            Ok(success) => Ok(success),
        }
    }

    /// Load from a file
    pub fn load_from_file<P: AsRef<Path>>(filename: P) -> Result<Ini, Error> {
        Ini::load_from_file_opt(filename, ParseOption::default())
    }

    /// Load from a file, but do not interpret '\' as an escape character
    pub fn load_from_file_noescape<P: AsRef<Path>>(filename: P) -> Result<Ini, Error> {
        Ini::load_from_file_opt(
            filename,
            ParseOption {
                enabled_escape: false,
                ..ParseOption::default()
            },
        )
    }

    /// Load from a file with options
    pub fn load_from_file_opt<P: AsRef<Path>>(filename: P, opt: ParseOption) -> Result<Ini, Error> {
        let mut reader = match File::open(filename.as_ref()) {
            Err(e) => {
                return Err(Error::Io(e));
            }
            Ok(r) => r,
        };

        let mut with_bom = false;

        // Check if file starts with a BOM marker
        // UTF-8: EF BB BF
        let mut bom = [0u8; 3];
        if reader.read_exact(&mut bom).is_ok() && &bom == b"\xEF\xBB\xBF" {
            with_bom = true;
        }

        if !with_bom {
            // Reset file pointer
            reader.seek(SeekFrom::Start(0))?;
        }

        Ini::read_from_opt(&mut reader, opt)
    }
}

/// Iterator for traversing sections
pub struct SectionIter<'a> {
    inner: Iter<'a, SectionKey, Properties>,
}

impl<'a> Iterator for SectionIter<'a> {
    type Item = (Option<Vec<&'a str>>, &'a Properties);

    fn next(&mut self) -> Option<Self::Item> {
        self.inner.next().map(|(k, v)| {
            (
                k.as_ref()
                    .map(|s| s.iter().map(|part| part.as_ref()).collect()),
                v,
            )
        })
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.inner.size_hint()
    }
}

impl DoubleEndedIterator for SectionIter<'_> {
    fn next_back(&mut self) -> Option<Self::Item> {
        self.inner.next_back().map(|(k, v)| {
            (
                k.as_ref()
                    .map(|s| s.iter().map(|part| part.as_ref()).collect()),
                v,
            )
        })
    }
}

/// Iterator for traversing sections
pub struct SectionIterMut<'a> {
    inner: IterMut<'a, SectionKey, Properties>,
}

impl<'a> Iterator for SectionIterMut<'a> {
    type Item = (Option<Vec<&'a str>>, &'a mut Properties);

    fn next(&mut self) -> Option<Self::Item> {
        self.inner.next().map(|(k, v)| {
            (
                k.as_ref()
                    .map(|s| s.iter().map(|part| part.as_ref()).collect()),
                v,
            )
        })
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.inner.size_hint()
    }
}

impl DoubleEndedIterator for SectionIterMut<'_> {
    fn next_back(&mut self) -> Option<Self::Item> {
        self.inner.next_back().map(|(k, v)| {
            (
                k.as_ref()
                    .map(|s| s.iter().map(|part| part.as_ref()).collect()),
                v,
            )
        })
    }
}

/// Iterator for traversing sections
pub struct SectionIntoIter {
    inner: IntoIter<SectionKey, Properties>,
}

impl Iterator for SectionIntoIter {
    type Item = (SectionKey, Properties);

    fn next(&mut self) -> Option<Self::Item> {
        self.inner.next()
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.inner.size_hint()
    }
}

impl DoubleEndedIterator for SectionIntoIter {
    fn next_back(&mut self) -> Option<Self::Item> {
        self.inner.next_back()
    }
}

impl<'a> Ini {
    /// Immutable iterate though sections
    pub fn iter(&'a self) -> SectionIter<'a> {
        SectionIter {
            inner: self.sections.iter(),
        }
    }

    /// Mutable iterate though sections
    #[deprecated(note = "Use `iter_mut` instead!")]
    pub fn mut_iter(&'a mut self) -> SectionIterMut<'a> {
        self.iter_mut()
    }

    /// Mutable iterate though sections
    pub fn iter_mut(&'a mut self) -> SectionIterMut<'a> {
        SectionIterMut {
            inner: self.sections.iter_mut(),
        }
    }
}

impl<'a> IntoIterator for &'a Ini {
    type IntoIter = SectionIter<'a>;
    type Item = (Option<Vec<&'a str>>, &'a Properties);

    fn into_iter(self) -> Self::IntoIter {
        self.iter()
    }
}

impl<'a> IntoIterator for &'a mut Ini {
    type IntoIter = SectionIterMut<'a>;
    type Item = (Option<Vec<&'a str>>, &'a mut Properties);

    fn into_iter(self) -> Self::IntoIter {
        self.iter_mut()
    }
}

impl IntoIterator for Ini {
    type IntoIter = SectionIntoIter;
    type Item = (SectionKey, Properties);

    fn into_iter(self) -> Self::IntoIter {
        SectionIntoIter {
            inner: self.sections.into_iter(),
        }
    }
}

// Ini parser
struct Parser<'a> {
    ch: Option<char>,
    rdr: Chars<'a>,
    line: usize,
    col: usize,
    opt: ParseOption,
}

#[derive(Debug)]
/// Parse error
pub struct ParseError {
    pub line: usize,
    pub col: usize,
    pub msg: Cow<'static, str>,
}

impl Display for ParseError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}:{} {}", self.line, self.col, self.msg)
    }
}

impl error::Error for ParseError {}

/// Error while parsing an INI document
#[derive(Debug)]
pub enum Error {
    Io(io::Error),
    Parse(ParseError),
}

impl Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match *self {
            Error::Io(ref err) => err.fmt(f),
            Error::Parse(ref err) => err.fmt(f),
        }
    }
}

impl error::Error for Error {
    fn source(&self) -> Option<&(dyn error::Error + 'static)> {
        match *self {
            Error::Io(ref err) => err.source(),
            Error::Parse(ref err) => err.source(),
        }
    }
}

impl From<io::Error> for Error {
    fn from(err: io::Error) -> Self {
        Error::Io(err)
    }
}

impl<'a> Parser<'a> {
    // Create a parser
    pub fn new(rdr: Chars<'a>, opt: ParseOption) -> Parser<'a> {
        let mut p = Parser {
            ch: None,
            line: 0,
            col: 0,
            rdr,
            opt,
        };
        p.bump();
        p
    }

    fn bump(&mut self) {
        self.ch = self.rdr.next();
        match self.ch {
            Some('\n') => {
                self.line += 1;
                self.col = 0;
            }
            Some(..) => {
                self.col += 1;
            }
            None => {}
        }
    }

    #[cold]
    #[inline(never)]
    fn error<U, M: Into<Cow<'static, str>>>(&self, msg: M) -> Result<U, ParseError> {
        Err(ParseError {
            line: self.line + 1,
            col: self.col + 1,
            msg: msg.into(),
        })
    }

    #[cold]
    fn eof_error(&self, expecting: &[Option<char>]) -> Result<char, ParseError> {
        self.error(format!("expecting \"{:?}\" but found EOF.", expecting))
    }

    fn char_or_eof(&self, expecting: &[Option<char>]) -> Result<char, ParseError> {
        match self.ch {
            Some(ch) => Ok(ch),
            None => self.eof_error(expecting),
        }
    }

    /// Consume all the white space until the end of the line or a tab
    fn parse_whitespace(&mut self) {
        while let Some(c) = self.ch {
            if !c.is_whitespace() && c != '\n' && c != '\t' && c != '\r' {
                break;
            }
            self.bump();
        }
    }

    /// Consume all the white space except line break
    fn parse_whitespace_except_line_break(&mut self) {
        while let Some(c) = self.ch {
            if (c == '\n' || c == '\r' || !c.is_whitespace()) && c != '\t' {
                break;
            }
            self.bump();
        }
    }

    /// Parse the whole INI input
    pub fn parse(&mut self) -> Result<Ini, ParseError> {
        let mut result = Ini::new();
        let mut curkey: String = "".into();
        let mut cursec: Option<Vec<String>> = None;

        self.parse_whitespace();
        while let Some(cur_ch) = self.ch {
            match cur_ch {
                ';' | '#' => {
                    if cfg!(not(feature = "inline-comment")) {
                        // Inline comments is not supported, so comments must starts from a new line
                        //
                        // https://en.wikipedia.org/wiki/INI_file#Comments
                        if self.col > 1 {
                            return self.error("doesn't support inline comment");
                        }
                    }

                    self.parse_comment();
                }
                '[' => match self.parse_section() {
                    Ok(mut sec_parts) => {
                        for part in sec_parts.iter_mut() {
                            part.trim_in_place();
                        }
                        cursec = Some(sec_parts);
                        match result.entry(cursec.clone()) {
                            SectionEntry::Vacant(v) => {
                                v.insert(Default::default());
                            }
                            SectionEntry::Occupied(mut o) => {
                                o.append(Default::default());
                            }
                        }
                    }
                    Err(e) => return Err(e),
                },
                '=' | ':' => {
                    if (curkey[..]).is_empty() {
                        return self.error("missing key");
                    }
                    match self.parse_val() {
                        Ok(mval) => {
                            match result.entry(cursec.clone()) {
                                SectionEntry::Vacant(v) => {
                                    // cursec must be None (the General Section)
                                    let mut prop = Properties::new();
                                    prop.insert(curkey, mval);
                                    v.insert(prop);
                                }
                                SectionEntry::Occupied(mut o) => {
                                    // Insert into the last (current) section
                                    o.last_mut().append(curkey, mval);
                                }
                            }
                            curkey = "".into();
                        }
                        Err(e) => return Err(e),
                    }
                }
                _ => match self.parse_key() {
                    Ok(mut mkey) => {
                        mkey.trim_in_place();
                        curkey = mkey;
                    }
                    Err(e) => return Err(e),
                },
            }

            self.parse_whitespace();
        }

        Ok(result)
    }

    fn parse_comment(&mut self) {
        while let Some(c) = self.ch {
            self.bump();
            if c == '\n' {
                break;
            }
        }
    }

    fn parse_str_until(
        &mut self,
        endpoint: &[Option<char>],
        check_inline_comment: bool,
    ) -> Result<String, ParseError> {
        let mut result: String = String::new();

        let mut in_line_continuation = false;

        while !endpoint.contains(&self.ch) {
            match self.char_or_eof(endpoint)? {
                #[cfg(feature = "inline-comment")]
                ch if check_inline_comment && (ch == ' ' || ch == '\t') => {
                    self.bump();

                    match self.ch {
                        Some('#') | Some(';') => {
                            // [space]#, [space]; starts an inline comment
                            self.parse_comment();
                            if in_line_continuation {
                                result.push(ch);
                                continue;
                            } else {
                                break;
                            }
                        }
                        Some(_) => {
                            result.push(ch);
                            continue;
                        }
                        None => {
                            result.push(ch);
                        }
                    }
                }
                #[cfg(feature = "inline-comment")]
                ch if check_inline_comment && in_line_continuation && (ch == '#' || ch == ';') => {
                    self.parse_comment();
                    continue;
                }
                '\\' => {
                    self.bump();
                    let Some(ch) = self.ch else {
                        result.push('\\');
                        continue;
                    };

                    if matches!(ch, '\n') {
                        in_line_continuation = true;
                    } else if self.opt.enabled_escape {
                        match ch {
                            '0' => result.push('\0'),
                            'a' => result.push('\x07'),
                            'b' => result.push('\x08'),
                            't' => result.push('\t'),
                            'r' => result.push('\r'),
                            'n' => result.push('\n'),
                            '\n' => self.bump(),
                            'x' => {
                                // Unicode 4 character
                                let mut code: String = String::with_capacity(4);
                                for _ in 0..4 {
                                    self.bump();
                                    let ch = self.char_or_eof(endpoint)?;
                                    if ch == '\\' {
                                        self.bump();
                                        if self.ch != Some('\n') {
                                            return self.error(format!(
                                                "expecting \"\\\\n\" but \
                                             found \"{:?}\".",
                                                self.ch
                                            ));
                                        }
                                    }

                                    code.push(ch);
                                }
                                let r = u32::from_str_radix(&code[..], 16);
                                match r.ok().and_then(char::from_u32) {
                                    Some(ch) => result.push(ch),
                                    None => return self.error("unknown character in \\xHH form"),
                                }
                            }
                            c => result.push(c),
                        }
                    } else {
                        result.push('\\');
                        result.push(ch);
                    }
                }
                ch => result.push(ch),
            }
            self.bump();
        }

        let _ = check_inline_comment;
        let _ = in_line_continuation;

        Ok(result)
    }

    fn parse_section(&mut self) -> Result<Vec<String>, ParseError> {
        let mut sections = Vec::new();

        // Parse nested sections in KDE format [Section][Subsection][Example]
        while self.ch == Some('[') {
            // Skip [
            self.bump();
            let section_part = self.parse_str_until(&[Some(']')], false)?;
            sections.push(section_part);

            // Skip ]
            if self.ch == Some(']') {
                self.bump();
            } else {
                return self.error("section must be ended with ']'");
            }
        }

        // Deal with inline comment
        #[cfg(feature = "inline-comment")]
        if matches!(self.ch, Some('#') | Some(';')) {
            self.parse_comment();
        }

        if sections.is_empty() {
            return self.error("empty section name");
        }

        Ok(sections)
    }

    fn parse_key(&mut self) -> Result<String, ParseError> {
        self.parse_str_until(&[Some('='), Some(':')], false)
    }

    fn parse_val(&mut self) -> Result<String, ParseError> {
        self.bump();
        // Issue #35: Allow empty value
        self.parse_whitespace_except_line_break();

        let mut val = String::new();
        let mut val_first_part = true;
        // Parse the first line of value
        'parse_value_line_loop: loop {
            match self.ch {
                // EOF. Just break
                None => break,

                // Double Quoted
                Some('"') if self.opt.enabled_quote => {
                    // Bump the current "
                    self.bump();
                    // Parse until the next "
                    let quoted_val = self.parse_str_until(&[Some('"')], false)?;
                    val.push_str(&quoted_val);

                    // Eats the "
                    self.bump();

                    // characters after " are still part of the value line
                    val_first_part = false;
                    continue;
                }

                // Single Quoted
                Some('\'') if self.opt.enabled_quote => {
                    // Bump the current '
                    self.bump();
                    // Parse until the next '
                    let quoted_val = self.parse_str_until(&[Some('\'')], false)?;
                    val.push_str(&quoted_val);

                    // Eats the '
                    self.bump();

                    // characters after ' are still part of the value line
                    val_first_part = false;
                    continue;
                }

                // Standard value string
                _ => {
                    // Parse until EOL. White spaces are trimmed (both start and end)
                    let standard_val =
                        self.parse_str_until_eol(cfg!(feature = "inline-comment"))?;

                    let trimmed_value = if val_first_part {
                        // If it is the first part of the value, just trim all of them
                        standard_val.trim()
                    } else {
                        // Otherwise, trim the ends
                        standard_val.trim_end()
                    };
                    val_first_part = false;

                    val.push_str(trimmed_value);

                    if self.opt.enabled_indented_mutiline_value {
                        // Multiline value is supported. We now check whether the next line is started with ' ' or '\t'.
                        self.bump();

                        loop {
                            match self.ch {
                                Some(' ') | Some('\t') => {
                                    // Multiline value
                                    // Eats the leading spaces
                                    self.parse_whitespace_except_line_break();
                                    // Push a line-break to the current value
                                    val.push('\n');
                                    // continue. Let read the whole value line
                                    continue 'parse_value_line_loop;
                                }

                                Some('\r') => {
                                    // Probably \r\n, try to eat one more
                                    self.bump();
                                    if self.ch == Some('\n') {
                                        self.bump();
                                        val.push('\n');
                                    } else {
                                        // \r with a character?
                                        return self.error("\\r is not followed by \\n");
                                    }
                                }

                                Some('\n') => {
                                    // New-line, just push and continue
                                    self.bump();
                                    val.push('\n');
                                }

                                // Not part of the multiline value
                                _ => break 'parse_value_line_loop,
                            }
                        }
                    } else {
                        break;
                    }
                }
            }
        }

        if self.opt.enabled_indented_mutiline_value {
            // multiline value, trims line-breaks
            val.trim_matches_in_place('\n');
        }

        Ok(val)
    }

    #[inline]
    fn parse_str_until_eol(&mut self, check_inline_comment: bool) -> Result<String, ParseError> {
        self.parse_str_until(&[Some('\n'), Some('\r'), None], check_inline_comment)
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn property_replace() {
        let mut props = Properties::new();
        props.insert("k1", "v1");

        assert_eq!(Some("v1"), props.get("k1"));
        let res = props.get_all("k1").collect::<Vec<&str>>();
        assert_eq!(res, vec!["v1"]);

        props.insert("k1", "v2");
        assert_eq!(Some("v2"), props.get("k1"));

        let res = props.get_all("k1").collect::<Vec<&str>>();
        assert_eq!(res, vec!["v2"]);
    }

    #[test]
    fn property_get_vec() {
        let mut props = Properties::new();
        props.append("k1", "v1");

        assert_eq!(Some("v1"), props.get("k1"));

        props.append("k1", "v2");

        assert_eq!(Some("v1"), props.get("k1"));

        let res = props.get_all("k1").collect::<Vec<&str>>();
        assert_eq!(res, vec!["v1", "v2"]);

        let res = props.get_all("k2").collect::<Vec<&str>>();
        assert!(res.is_empty());
    }

    #[test]
    fn property_remove() {
        let mut props = Properties::new();
        props.append("k1", "v1");
        props.append("k1", "v2");

        let res = props.remove_all("k1").collect::<Vec<String>>();
        assert_eq!(res, vec!["v1", "v2"]);
        assert!(!props.contains_key("k1"));
    }

    #[test]
    fn load_from_str_with_empty_general_section() {
        let input = "[sec1]\nkey1=val1\n";
        let opt = Ini::load_from_str(input);
        assert!(opt.is_ok());

        let mut output = opt.unwrap();
        assert_eq!(output.len(), 2);

        assert!(output.general_section().is_empty());
        assert!(output.general_section_mut().is_empty());

        let props1 = output.section(None::<Vec<&str>>).unwrap();
        assert!(props1.is_empty());
        let props2 = output.section(Some(vec!["sec1"])).unwrap();
        assert_eq!(props2.len(), 1);
        assert_eq!(props2.get("key1"), Some("val1"));
    }

    #[test]
    fn load_from_str_with_nested_sections() {
        let input = "[Display][Screen][Resolution]\nwidth=1920\nheight=1080\n";
        let opt = Ini::load_from_str(input);
        assert!(opt.is_ok());

        let output = opt.unwrap();
        let props = output
            .section(Some(vec!["Display", "Screen", "Resolution"]))
            .unwrap();
        assert_eq!(props.len(), 2);
        assert_eq!(props.get("width"), Some("1920"));
        assert_eq!(props.get("height"), Some("1080"));
    }

    #[test]
    fn write_nested_sections() {
        let mut ini = Ini::new();
        ini.with_section(Some(vec!["Display", "Screen", "Resolution"]))
            .set("width", "1920")
            .set("height", "1080");

        let mut buf = Vec::new();
        ini.write_to(&mut buf).unwrap();

        let content = String::from_utf8(buf).unwrap();
        let expected = format!(
            "[Display][Screen][Resolution]{}width=1920{}height=1080{}",
            DEFAULT_LINE_SEPARATOR, DEFAULT_LINE_SEPARATOR, DEFAULT_LINE_SEPARATOR
        );
        assert_eq!(content, expected);
    }

    #[test]
    fn format_section_test() {
        assert_eq!(
            format_section(Some(&[
                "Display".to_string(),
                "Screen".to_string(),
                "Resolution".to_string()
            ])),
            "[Display][Screen][Resolution]"
        );
        assert_eq!(format_section(Some(&["Section".to_string()])), "[Section]");
        assert_eq!(format_section(None), "General");
    }

    #[test]
    fn load_from_str_with_empty_input() {
        let input = "";
        let opt = Ini::load_from_str(input);
        assert!(opt.is_ok());

        let mut output = opt.unwrap();
        assert!(output.general_section().is_empty());
        assert!(output.general_section_mut().is_empty());
        assert_eq!(output.len(), 1);
    }

    #[test]
    fn write_and_read_nested_sections() {
        let mut ini = Ini::new();
        ini.with_section(Some(vec!["Section1", "Subsection"]))
            .set("key1", "value1");
        ini.with_section(Some(vec!["Section2", "Subsection", "Deep"]))
            .set("key2", "value2");

        let mut buf = Vec::new();
        ini.write_to(&mut buf).unwrap();

        let content = String::from_utf8(buf).unwrap();
        let read_ini = Ini::load_from_str(&content).unwrap();

        assert_eq!(
            read_ini.get_from(Some(vec!["Section1", "Subsection"]), "key1"),
            Some("value1")
        );
        assert_eq!(
            read_ini.get_from(Some(vec!["Section2", "Subsection", "Deep"]), "key2"),
            Some("value2")
        );
    }

    #[test]
    fn parse_error_numbers() {
        let invalid_input = "\n\\x";
        let ini = Ini::load_from_str_opt(
            invalid_input,
            ParseOption {
                enabled_escape: true,
                ..Default::default()
            },
        );
        assert!(ini.is_err());

        let err = ini.unwrap_err();
        assert_eq!(err.line, 2);
        assert_eq!(err.col, 3);
    }
}
