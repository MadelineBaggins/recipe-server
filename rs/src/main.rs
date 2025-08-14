use rocket::response::content::RawHtml;

#[macro_use]
extern crate rocket;

#[get("/")]
fn index() -> RawHtml<&'static str> {
    RawHtml(include_str!("index.html"))
}

#[launch]
fn rocket() -> _ {
    println!("Hello, world!");
    rocket::build().mount("/", routes![index])
}
