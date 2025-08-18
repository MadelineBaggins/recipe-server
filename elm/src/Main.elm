-- SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
--
-- SPDX-License-Identifier: GPL-3.0-only


port module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput)
import Http
import Json.Decode as De
import Url



-- PORTS


port showRecipe : String -> Cmd msg


port scaleRecipe : String -> Cmd msg


port ready : (String -> msg) -> Sub msg



-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , rootUrl : String
    , page : Page
    }


type Page
    = Loading
    | Home (List Recipe)
    | Viewing Recipe
    | Editing Recipe
    | Error String


type alias Recipe =
    { slug : String
    , content : String
    }


recipeDecoder : De.Decoder Recipe
recipeDecoder =
    De.map2 Recipe (De.field "slug" De.string) (De.field "content" De.string)


recipeName : Recipe -> String
recipeName recipe =
    recipe.content |> String.split "\n" |> List.head |> Maybe.withDefault recipe.content |> String.dropLeft 2


recipeDescription : Recipe -> String
recipeDescription recipe =
    recipe.content |> String.split "\n\n## Ingredients" |> List.head |> Maybe.withDefault recipe.content |> String.lines |> List.drop 2 |> String.join "\n"


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    case String.split "/recipe/" (Url.toString url) of
        [ root, slug ] ->
            ( Model key url root Loading, getRecipe root slug )

        _ ->
            ( Model key url (Url.toString url) Loading, getHome (Url.toString url) )


getHome : String -> Cmd Msg
getHome root =
    Http.get
        { url = root ++ "/api/get/recipes"
        , expect = Http.expectJson LoadedHome (De.list recipeDecoder)
        }


getRecipe : String -> String -> Cmd Msg
getRecipe root slug =
    Http.get
        { url = root ++ "/api/get/recipe/" ++ slug
        , expect = Http.expectJson LoadedRecipe recipeDecoder
        }



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | LoadedHome (Result Http.Error (List Recipe))
    | LoadedRecipe (Result Http.Error Recipe)
    | Scale String
    | Ready


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Scale factor ->
            ( model, scaleRecipe factor )

        Ready ->
            init () model.url model.key

        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            init () url model.key

        LoadedHome (Ok recipes) ->
            ( { model | page = Home recipes }, Cmd.none )

        LoadedHome (Err _) ->
            ( { model | page = Error "Could not load recipes" }, Cmd.none )

        LoadedRecipe (Ok recipe) ->
            ( { model | page = Viewing recipe }, showRecipe recipe.content )

        LoadedRecipe (Err _) ->
            ( { model | page = Error "Could not load recipe" }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    ready (\_ -> Ready)



-- VIEW


view : Model -> Browser.Document Msg
view model =
    case model.page of
        Loading ->
            { title = "Loading...", body = [] }

        Home recipes ->
            { title = "Recipes"
            , body = recipes |> List.map (viewRecipeThumbnail model.rootUrl)
            }

        Viewing recipe ->
            { title = recipeName recipe
            , body =
                [ input [ onInput Scale ] [], div [ id "recipe" ] [] ]
            }

        Editing recipe ->
            { title = "Edit: " ++ recipeName recipe
            , body = [ div [ id "editor" ] [], div [ id "recipe" ] [] ]
            }

        Error message ->
            { title = "Error"
            , body = [ text message ]
            }


viewRecipeThumbnail : String -> Recipe -> Html Msg
viewRecipeThumbnail rootUrl recipe =
    a [ href (rootUrl ++ "recipe/" ++ recipe.slug) ]
        [ div []
            [ h2 [] [ text (recipeName recipe) ]
            , p [] [ text (recipeDescription recipe) ]
            ]
        ]


viewLink : String -> Html msg
viewLink path =
    li [] [ a [ href path ] [ text path ] ]
