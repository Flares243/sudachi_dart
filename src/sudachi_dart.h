#ifndef SUDACHI_DART_H
#define SUDACHI_DART_H

#include <stdint.h>
#include <stdbool.h>

/* Opaque handles ------------------------------------------------------------*/

typedef struct DictionaryHandle DictionaryHandle;
typedef struct TokenizerHandle  TokenizerHandle;

/* API -----------------------------------------------------------------------*/

/* Load the Sudachi dictionary. Returns a handle on success, NULL on failure.
   Free with sudachi_free_dictionary(). */
DictionaryHandle *sudachi_init_dictionary(const char *config_path, const char *resource_dir, const char *dictionary_path);

/* Free a handle from sudachi_init_dictionary(). NULL is a no-op. */
void sudachi_free_dictionary(DictionaryHandle *handle);

/* Create a tokenizer from dict_handle. The tokenizer keeps its own reference
   to the dictionary, so dict_handle may be freed after this call.
   Returns a handle on success, NULL on failure.
   Free with sudachi_free_tokenizer(). */
TokenizerHandle *sudachi_init_tokenizer(const DictionaryHandle *dict_handle);

/* Free a handle from sudachi_init_tokenizer(). NULL is a no-op. */
void sudachi_free_tokenizer(TokenizerHandle *handle);

/* Tokenize text and return morphemes as a UTF-8 JSON string.
   mode:         0=A (short), 1=B (middle), 2=C (long)
   enable_debug: 0=off, non-zero=on
   Returns a NUL-terminated string on success, NULL on failure.
   Free the result with sudachi_free_string().

   JSON shape: [{"surface","dictionary_form","normalized_form","reading_form","part_of_speech":[]}, ...] */
char *sudachi_tokenize(TokenizerHandle *tokenizer,
                       const char      *text,
                       uint8_t          mode,
                       uint8_t          enable_debug);

/* Free a string from sudachi_tokenize(). NULL is a no-op. */
void sudachi_free_string(char *s);

/// Returns `true` if `dictionary_path` points to a valid `.dic` file.
bool sudachi_is_valid_dictionary(const char *dictionary_path);

#endif /* SUDACHI_DART_H */
