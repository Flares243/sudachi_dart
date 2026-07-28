use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::PathBuf;
use std::sync::Arc;

use serde::Serialize;
use sudachi::{
    analysis::stateless_tokenizer::StatelessTokenizer,
    analysis::{Mode, Tokenize},
    config::Config,
    dic::dictionary::JapaneseDictionary,
};

// Opaque handle types exposed over the C FFI boundary.

/// Holds a reference-counted Sudachi dictionary.
pub struct DictionaryHandle {
    dictionary: Arc<JapaneseDictionary>,
}

/// Holds a stateless tokenizer backed by a shared dictionary.
pub struct TokenizerHandle {
    tokenizer: StatelessTokenizer<Arc<JapaneseDictionary>>,
}

// JSON representation of a single morpheme returned by tokenization.

#[derive(Serialize)]
struct MorphemeData {
    surface: String,
    dictionary_form: String,
    normalized_form: String,
    reading_form: String,
    part_of_speech: Vec<String>,
}

// Maps a u8 mode value (0=A, 1=B, 2+=C) to a Sudachi Mode.
fn u8_to_mode(mode: u8) -> Mode {
    match mode {
        0 => Mode::A,
        1 => Mode::B,
        _ => Mode::C,
    }
}

// Exported C API

/// Load the Sudachi dictionary and return a handle to it.
///
/// Returns null on error. Free the handle with [`sudachi_free_dictionary`].
#[unsafe(no_mangle)]
pub extern "C" fn sudachi_init_dictionary(
    config_path: *const c_char,
    resource_dir: *const c_char,
    dictionary_path: *const c_char,
) -> *mut DictionaryHandle {
    let config_path_buf = if !config_path.is_null() {
        Some(PathBuf::from(
            match unsafe { CStr::from_ptr(config_path) }.to_str() {
                Ok(e) => e,
                Err(err) => {
                    eprintln!("[Sudachi Error] {err:?}");
                    return std::ptr::null_mut();
                }
            },
        ))
    } else {
        None
    };

    let resource_path_buf = if !resource_dir.is_null() {
        Some(PathBuf::from(
            match unsafe { CStr::from_ptr(resource_dir) }.to_str() {
                Ok(e) => e,
                Err(err) => {
                    eprintln!("[Sudachi Error] {err:?}");
                    return std::ptr::null_mut();
                }
            },
        ))
    } else {
        None
    };

    let dictionary_path_buf = if !dictionary_path.is_null() {
        Some(PathBuf::from(
            match unsafe { CStr::from_ptr(dictionary_path) }.to_str() {
                Ok(e) => e,
                Err(err) => {
                    eprintln!("[Sudachi Error] {err:?}");
                    return std::ptr::null_mut();
                }
            },
        ))
    } else {
        None
    };

    let config = match Config::new(config_path_buf, resource_path_buf, dictionary_path_buf) {
        Ok(c) => c,
        Err(err) => {
            eprintln!("[Sudachi Error] {err:?}");
            return std::ptr::null_mut();
        }
    };

    let dictionary = match JapaneseDictionary::from_cfg(&config) {
        Ok(d) => d,
        Err(err) => {
            eprintln!("[Sudachi Error] {err:?}");
            return std::ptr::null_mut();
        }
    };

    Box::into_raw(Box::new(DictionaryHandle {
        dictionary: Arc::new(dictionary),
    }))
}

/// Free a handle returned by [`sudachi_init_dictionary`]. Null is a no-op.
#[unsafe(no_mangle)]
pub extern "C" fn sudachi_free_dictionary(handle: *mut DictionaryHandle) {
    if !handle.is_null() {
        unsafe { drop(Box::from_raw(handle)) };
    }
}

/// Create a tokenizer from a dictionary handle.
///
/// The tokenizer holds its own `Arc` reference, so the dictionary handle can
/// be freed independently. Returns null on error.
/// Free the tokenizer with [`sudachi_free_tokenizer`].
#[unsafe(no_mangle)]
pub extern "C" fn sudachi_init_tokenizer(
    dict_handle: *const DictionaryHandle,
) -> *mut TokenizerHandle {
    if dict_handle.is_null() {
        return std::ptr::null_mut();
    }

    let dict_ref = unsafe { &*dict_handle };
    let tokenizer = StatelessTokenizer::new(dict_ref.dictionary.clone());

    Box::into_raw(Box::new(TokenizerHandle { tokenizer }))
}

/// Free a handle returned by [`sudachi_init_tokenizer`]. Null is a no-op.
#[unsafe(no_mangle)]
pub extern "C" fn sudachi_free_tokenizer(handle: *mut TokenizerHandle) {
    if !handle.is_null() {
        unsafe { drop(Box::from_raw(handle)) };
    }
}

/// Tokenize `text` and return the morphemes as a JSON string.
///
/// `mode` controls split granularity: 0=A (short), 1=B (middle), 2=C (default).
/// Set `enable_debug` to 1 to enable Sudachi debug output.
///
/// Returns a null-terminated UTF-8 string on success, or null on error.
/// The caller must free it with [`sudachi_free_string`].
#[unsafe(no_mangle)]
pub extern "C" fn sudachi_tokenize(
    tokenizer_handle: *mut TokenizerHandle,
    text: *const c_char,
    mode: u8,
    enable_debug: u8,
) -> *mut c_char {
    if tokenizer_handle.is_null() || text.is_null() {
        return std::ptr::null_mut();
    }

    let tokenizer_ref = unsafe { &*tokenizer_handle };

    let text_str = match unsafe { CStr::from_ptr(text) }.to_str() {
        Ok(s) => s,
        Err(err) => {
            eprintln!("[Sudachi Error] {err:?}");
            return std::ptr::null_mut();
        }
    };

    let morphemes =
        match tokenizer_ref
            .tokenizer
            .tokenize(text_str, u8_to_mode(mode), enable_debug != 0)
        {
            Ok(m) => m,
            Err(err) => {
                eprintln!("[Sudachi Error] {err:?}");
                return std::ptr::null_mut();
            }
        };

    let data: Vec<MorphemeData> = morphemes
        .iter()
        .map(|m| MorphemeData {
            surface: m.surface().to_string(),
            dictionary_form: m.dictionary_form().to_string(),
            normalized_form: m.normalized_form().to_string(),
            reading_form: m.reading_form().to_string(),
            part_of_speech: m.part_of_speech().iter().map(|s| s.to_string()).collect(),
        })
        .collect();

    match serde_json::to_string(&data) {
        Ok(json) => match CString::new(json) {
            Ok(cs) => cs.into_raw(),
            Err(err) => {
                eprintln!("[Sudachi Error] {err:?}");
                std::ptr::null_mut()
            }
        },
        Err(err) => {
            eprintln!("[Sudachi Error] {err:?}");
            std::ptr::null_mut()
        }
    }
}

/// Free a string returned by [`sudachi_tokenize`]. Null is a no-op.
#[unsafe(no_mangle)]
pub extern "C" fn sudachi_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe { drop(CString::from_raw(s)) };
    }
}

#[cfg(test)]
mod test;
