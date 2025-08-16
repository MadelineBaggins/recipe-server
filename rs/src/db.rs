// SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
//
// SPDX-License-Identifier: GPL-3.0-only

use rocket::{Build, Rocket, fairing};
use rocket_db_pools::Database;

#[derive(Database)]
#[database("sqlite_recipes")]
pub struct Recipes(sqlx::SqlitePool);

// Create the database if it doesn't exist and
// run any migrations against it to ensure it's
// ready to use.
pub async fn setup(mut rocket: Rocket<Build>) -> fairing::Result {
    // Connect to the database,
    let options = sqlx::sqlite::SqliteConnectOptions::new()
        .filename("recipes.db")
        // Creating it if needed.
        .create_if_missing(true);
    let pool = sqlx::SqlitePool::connect_with(options).await.unwrap();
    rocket = rocket.manage(Recipes(pool));

    // Run any migrations against the database
    match Recipes::fetch(&rocket) {
        Some(db) => match sqlx::migrate!("./migrations").run(&**db).await {
            Ok(_) => Ok(rocket),
            Err(e) => {
                error!("Failed to run migrations: {e}");
                Err(rocket)
            }
        },
        None => {
            error!("Failed to connect to the database");
            Err(rocket)
        }
    }
}
