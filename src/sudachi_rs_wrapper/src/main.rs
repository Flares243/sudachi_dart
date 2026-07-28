use std::{path::PathBuf, sync::Arc};

use sudachi::{
    analysis::stateless_tokenizer::StatelessTokenizer,
    analysis::{Mode, Tokenize},
    config::Config,
    dic::dictionary::JapaneseDictionary,
};

fn main() {
    let dictionary_config = Config::new(
        Some(PathBuf::from("resources/sudachi.json")),
        None,
        Some(PathBuf::from("resources/system_full.dic")),
    );

    let dictionary_config = match dictionary_config {
        Ok(dict) => dict,
        Err(e) => panic!("Failed to load dictionary config: {e}"),
    };

    let dictionary = JapaneseDictionary::from_cfg(&dictionary_config);

    let dictionary = Arc::new(match dictionary {
        Ok(e) => e,
        Err(e) => panic!("Failed to create dictionary {e:?}"),
    });

    let tokenizer = StatelessTokenizer::new(dictionary);

    let morphemes = tokenizer.tokenize("私は東京大学で日本語を勉強しています。", Mode::A, false);

    let morphemes = match morphemes {
        Ok(result) => result,
        Err(e) => panic!("Fauiled {e:?}"),
    };

    for morpheme in morphemes.iter() {
        println!("surface: {}", morpheme.surface());
        println!("dictionary_form: {}", morpheme.dictionary_form());
        println!("normalized_form: {}", morpheme.normalized_form());
        println!("reading: {}", morpheme.reading_form());
        println!("part_of_speech: {:?}", morpheme.part_of_speech());
        println!("---");
    }
}
