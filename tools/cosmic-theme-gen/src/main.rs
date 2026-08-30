//! Build a full COSMIC theme from a ThemeBuilder RON file.
//! usage: cosmic-theme-gen <builder.ron> <out-dir>
//! Writes <out-dir>/cosmic/com.system76.CosmicTheme.Dark{,.Builder}/v2/*
use cosmic_config::{Config, CosmicConfigEntry};
use cosmic_theme::{ThemeBuilder, DARK_THEME_BUILDER_ID, DARK_THEME_ID};
use std::{fs, path::PathBuf, process::exit};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let [_, input, out] = args.as_slice() else {
        eprintln!("usage: cosmic-theme-gen <builder.ron> <out-dir>");
        exit(2);
    };
    let src = fs::read_to_string(input).unwrap_or_else(|e| { eprintln!("{input}: {e}"); exit(1) });
    let builder: ThemeBuilder = ron::from_str(&src).unwrap_or_else(|e| { eprintln!("{input}: {e}"); exit(1) });
    let out = PathBuf::from(out);

    let builder_cfg = Config::with_custom_path(DARK_THEME_BUILDER_ID, 2, out.clone()).unwrap();
    builder.write_entry(&builder_cfg).unwrap();

    let theme = builder.build();
    let theme_cfg = Config::with_custom_path(DARK_THEME_ID, 2, out).unwrap();
    theme.write_entry(&theme_cfg).unwrap();

    println!("wrote {} + {} (v2)", DARK_THEME_BUILDER_ID, DARK_THEME_ID);
}
