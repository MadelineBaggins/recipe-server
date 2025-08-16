// SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
//
// SPDX-License-Identifier: GPL-3.0-only

use rocket::{
    http::ContentType,
    response::content::{RawHtml, RawJavaScript},
};

#[macro_use]
extern crate rocket;

#[get("/")]
fn index() -> RawHtml<&'static str> {
    RawHtml(include_str!("index.html"))
}

#[get("/pkg/wasm.js")]
fn wasm_js() -> RawJavaScript<&'static str> {
    RawJavaScript(include_str!("pkg/wasm.js"))
}

#[get("/pkg/wasm_bg.wasm")]
fn wasm() -> (ContentType, &'static [u8]) {
    (ContentType::WASM, include_bytes!("pkg/wasm_bg.wasm"))
}

#[launch]
fn rocket() -> _ {
    println!("Hello, world!");
    rocket::build().mount("/", routes![index, wasm_js, wasm])
}
