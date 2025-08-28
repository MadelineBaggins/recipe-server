// SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
//
// SPDX-License-Identifier: GPL-3.0-only

mod db;

use rocket::{
    Config,
    data::{Limits, ToByteUnit},
    fairing::AdHoc,
    http::ContentType,
    response::content::{RawHtml, RawJavaScript},
};

#[macro_use]
extern crate rocket;

mod r#static {
    use super::*;

    #[catch(default)]
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
    use rocket::http::ContentType;
    use rocket::serde::Serialize;
    use rocket::serde::json::Json;
    use rocket_db_pools::Connection;
    use sqlx::FromRow;
    use sqlx::Row;
    use sqlx::sqlite::SqliteRow;

    #[derive(Serialize)]
    pub struct Recipe {
        slug: String,
        content: String,
        factors: Vec<i32>,
        image: String,
    }

    impl FromRow<'_, SqliteRow> for Recipe {
        fn from_row(row: &'_ SqliteRow) -> Result<Self, sqlx::Error> {
            let slug = row.try_get("slug")?;
            let content: String = row.try_get("content")?;
            let recipe = maddi_recipe::Recipe::parse(&content);
            let image = row.try_get("image_slug").ok().unwrap_or_else(String::new);
            Ok(Self {
                slug,
                factors: recipe.divisors(),
                content,
                image,
            })
        }
    }

    #[get("/get/recipes")]
    pub async fn get_recipes(mut db: Connection<Recipes>) -> Json<Vec<Recipe>> {
        Json(
            sqlx::query_as("SELECT slug, content FROM recipes")
                .fetch_all(&mut **db)
                .await
                .unwrap(),
        )
    }

    #[get("/get/recipe/<slug>")]
    pub async fn get_recipe(mut db: Connection<Recipes>, slug: String) -> Option<Json<Recipe>> {
        Some(Json(
            sqlx::query_as("SELECT * FROM recipes WHERE slug = ?")
                .bind(slug)
                .fetch_optional(&mut **db)
                .await
                .unwrap()?,
        ))
    }

    #[get("/get/recipe/<slug>/<image>")]
    pub async fn get_recipe_image(
        mut db: Connection<Recipes>,
        slug: &str,
        image: &str,
    ) -> Option<(ContentType, Vec<u8>)> {
        println!("{slug} / {image}");
        let bytes =
            sqlx::query_scalar("SELECT image FROM recipes WHERE slug = ? AND  image_slug = ?")
                .bind(slug)
                .bind(image)
                .fetch_one(&mut **db)
                .await
                .unwrap();
        let image_type = match image.rsplit_once(".") {
            Some((_, "png")) => "png",
            Some((_, "jpeg" | "jpg")) => "jpeg",
            Some((_, "svg")) => "svg+xml",
            _ => return None,
        };
        Some((ContentType::new("image", image_type), bytes))
    }

    #[post("/new/recipe/<slug>", data = "<name>")]
    pub async fn new_recipe(
        mut db: Connection<Recipes>,
        slug: String,
        name: String,
    ) -> Option<Json<Recipe>> {
        let content = format!(
            "# {name}\n\n## Ingredients\n\n- 1 cup ingredient\n\n## Directions\n\n- An instruction"
        );
        sqlx::query!("INSERT INTO recipes VALUES(?,?,NULL,NULL)", slug, content)
            .execute(&mut **db)
            .await
            .unwrap();
        get_recipe(db, slug).await
    }

    #[post("/set/recipe/<slug>", data = "<content>")]
    pub async fn set_recipe(
        mut db: Connection<Recipes>,
        slug: String,
        content: String,
    ) -> Option<Json<Recipe>> {
        sqlx::query!("UPDATE recipes SET content=? WHERE slug=?", content, slug)
            .execute(&mut **db)
            .await
            .unwrap();
        get_recipe(db, slug).await
    }

    #[post("/set/image/<slug>/<image_slug>", data = "<image>")]
    pub async fn set_image(
        mut db: Connection<Recipes>,
        slug: String,
        image: Vec<u8>,
        image_slug: String,
    ) -> Option<Json<Recipe>> {
        sqlx::query!(
            "UPDATE recipes SET image=?, image_slug=? WHERE slug=?",
            image,
            image_slug,
            slug
        )
        .execute(&mut **db)
        .await
        .unwrap();
        get_recipe(db, slug).await
    }
}

#[launch]
fn rocket() -> _ {
    let db_setup = AdHoc::try_on_ignite("database", db::setup);
    let limits = Limits::default().limit("bytes", 20.megabytes());
    rocket::build()
        .configure(Config::figment().merge(("limits", limits)))
        .attach(db_setup)
        // Mount the routes that serve static files
        .mount("/", routes![r#static::wasm_js, r#static::wasm])
        .register("/", catchers![r#static::index])
        .mount(
            "/api",
            routes![
                api::get_recipes,
                api::get_recipe,
                api::get_recipe_image,
                api::new_recipe,
                api::set_recipe,
                api::set_image,
            ],
        )
}
