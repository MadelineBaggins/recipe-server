-- SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
--
-- SPDX-License-Identifier: GPL-3.0-only


module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as De
import Url



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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl model.key (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        UrlChanged url ->
            ( { model | url = url }
            , Cmd.none
            )

        LoadedHome (Ok recipes) ->
            ( { model | page = Home recipes }, Cmd.none )

        LoadedHome (Err _) ->
            ( { model | page = Error "Could not load recipes" }, Cmd.none )

        LoadedRecipe (Ok recipe) ->
            ( { model | page = Viewing recipe }, Cmd.none )

        LoadedRecipe (Err _) ->
            ( { model | page = Error "Could not load recipe" }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> Browser.Document Msg
view model =
    { title = "URL Interceptor"
    , body =
        [ text "The current URL is: "
        , b [] [ text (Url.toString model.url) ]
        , ul []
            [ viewLink "/home"
            , viewLink "/profile"
            , viewLink "/reviews/the-century-of-the-self"
            , viewLink "/reviews/public-opinion"
            , viewLink "/reviews/shah-of-shahs"
            ]
        ]
    }


viewLink : String -> Html msg
viewLink path =
    li [] [ a [ href path ] [ text path ] ]
