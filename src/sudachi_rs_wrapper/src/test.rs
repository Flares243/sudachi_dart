use std::ffi::{CStr, CString};

use crate::{
    sudachi_free_dictionary, sudachi_free_string, sudachi_free_tokenizer, sudachi_init_dictionary,
    sudachi_init_tokenizer, sudachi_is_valid_dictionary, sudachi_tokenize,
};

const CONFIG_PATH: &str = "resources/sudachi.json";
const DICT_PATH: &str = "resources/system_full.dic";
const FALSE_DICT_PATH: &str = "resources/sudachi.dic";

#[test]
fn test_tokenize_returns_json() {
    let config_c = CString::new(CONFIG_PATH).unwrap();
    let dict_c = CString::new(DICT_PATH).unwrap();
    let false_dict_c = CString::new(FALSE_DICT_PATH).unwrap();
    let text_c = CString::new("私は東京大学で日本語を勉強しています。").unwrap();

    unsafe {
        if sudachi_is_valid_dictionary(false_dict_c.as_ptr()) {
            println!("Valid")
        } else {
            println!("Invalid")
        }

        let dict_handle =
            sudachi_init_dictionary(config_c.as_ptr(), std::ptr::null(), dict_c.as_ptr());

        println!("{dict_handle:?}");

        assert!(!dict_handle.is_null(), "dictionary init failed");

        let tok_handle = sudachi_init_tokenizer(dict_handle);

        assert!(!tok_handle.is_null(), "tokenizer init failed");

        // Mode 0 = A (most granular)
        let result = sudachi_tokenize(tok_handle, text_c.as_ptr(), 0, 0);

        assert!(!result.is_null(), "tokenize returned null");

        let json = CStr::from_ptr(result).to_str().unwrap();
        println!("{json}");

        assert!(json.starts_with('['), "expected a JSON array");

        sudachi_free_string(result);
        sudachi_free_tokenizer(tok_handle);
        sudachi_free_dictionary(dict_handle);
    }
}
