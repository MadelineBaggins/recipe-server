// SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
//
// SPDX-License-Identifier: GPL-3.0-only

mod db;

use rocket::{
    fairing::AdHoc,
    http::ContentType,
    response::content::{RawHtml, RawJavaScript},
};

#[macro_use]
extern crate rocket;

mod r#static {
    use super::*;

    #[get("/")]
    pub fn index() -> RawHtml<&'static str> {
        RawHtml(include_str!("index.html"))
    }

    #[get("/pkg/wasm.js")]
    pub fn wasm_js() -> RawJavaScript<&'static str> {
        RawJavaScript(include_str!("pkg/wasm.js"))
    }

    #[get("/pkg/wasm_bg.wasm")]
    pub fn wasm() -> (ContentType, &'static [u8]) {
        (ContentType::WASM, include_bytes!("pkg/wasm_bg.wasm"))
    }
}

mod api {
    use crate::db::Recipes;
    use rocket::serde::Serialize;
    use rocket::serde::json::Json;
    use rocket_db_pools::Connection;

    #[derive(Serialize)]
    pub struct Recipe {
        slug: String,
        content: String,
    }

    #[get("/get/recipes")]
    pub async fn get_recipes(mut db: Connection<Recipes>) -> Json<Vec<Recipe>> {
        Json(
            sqlx::query_as!(Recipe, "SELECT * FROM recipes")
                .fetch_all(&mut **db)
                .await
                .unwrap(),
        )
    }

    #[get("/get/recipe/<slug>")]
    pub async fn get_recipe(mut db: Connection<Recipes>, slug: String) -> Option<Json<Recipe>> {
        Some(Json(
            sqlx::query_as!(Recipe, "SELECT * FROM recipes WHERE slug = ?", slug)
                .fetch_optional(&mut **db)
                .await
                .unwrap()?,
        ))
    }

    #[post("/new/recipe/<slug>", data = "<name>")]
    pub async fn new_recipe(
        mut db: Connection<Recipes>,
        slug: String,
        name: String,
    ) -> Option<Json<Recipe>> {
        let content = format!(
            "## {name}\n\n## Ingredients\n\n- 1 cup ingredient\n\n## Directions\n\n- An instruction"
        );
        sqlx::query!("INSERT INTO recipes VALUES(?,?)", slug, content)
            .execute(&mut **db)
            .await
            .unwrap();
        get_recipe(db, slug).await
    }
}

#[launch]
fn rocket() -> _ {
    println!("Hello, world!");
    let db_setup = AdHoc::try_on_ignite("database", db::setup);
    rocket::build()
        .attach(db_setup)
        // Mount the routes that serve static files
        .mount(
            "/",
            routes![r#static::index, r#static::wasm_js, r#static::wasm],
        )
        .mount(
            "/api",
            routes![api::get_recipes, api::get_recipe, api::new_recipe],
        )
}
