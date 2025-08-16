# SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
#
# SPDX-License-Identifier: GPL-3.0-only

rs/target/debug/recipe-server: rs/src rs/src/index.html rs/Cargo.toml rs/Cargo.toml rs/src/pkg
	cd rs && cargo build

rs/target/release/recipe-server: rs/src rs/src/index.html rs/Cargo.toml rs/Cargo.lock rs/src/pkg
	cd rs && cargo build --release

rs/src/pkg: wasm/src wasm/Cargo.toml wasm/Cargo.lock
	cd wasm && wasm-pack build --target web --out-dir ../rs/src/pkg

rs/src/index.html: rs/src/main.js rs/src/index.header.html rs/src/index.footer.html
	cat rs/src/index.header.html rs/src/main.js rs/src/index.footer.html > rs/src/index.html

rs/src/main.js: elm/src elm/elm.json
	cd elm && elm make src/Main.elm --output ../rs/src/main.js

clean:
	rm -rf recipes.db
	cd rs && cargo clean
	cd rs && rm -rf src/pkg src/index.html src/main.js recipes.db
	cd elm && rm -rf elm-stuff
	cd wasm && cargo clean

.PHONY: clean
	
