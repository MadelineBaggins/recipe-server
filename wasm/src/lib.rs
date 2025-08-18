// SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
//
// SPDX-License-Identifier: GPL-3.0-only

use wasm_bindgen::prelude::*;
use web_sys::window;

#[wasm_bindgen(js_name = Recipe)]
pub struct Recipe(maddi_recipe::Recipe<'static>);

#[wasm_bindgen]
impl Recipe {
    #[wasm_bindgen]
    pub fn markdown(&self) -> String {
        format!("{}", self.0)
    }

    #[wasm_bindgen]
    pub fn html(&self) -> String {
        markdown::to_html(&self.markdown())
    }

    #[wasm_bindgen]
    pub fn scale(&self, factor: f32) -> Self {
        Self(self.0.scale(factor))
    }
}

#[wasm_bindgen]
pub fn recipe(str: String) -> Recipe {
    Recipe(maddi_recipe::Recipe::parse(&str).into_static())
}

#[wasm_bindgen(start)]
fn main() -> Result<(), JsValue> {
    Ok(())
}
