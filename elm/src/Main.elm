-- SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
--
-- SPDX-License-Identifier: GPL-3.0-only


port module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode as De
import Style exposing (..)
import Url



-- PORTS


port showRecipe : String -> Cmd msg


port scaleRecipe : String -> Cmd msg


port print : String -> Cmd msg


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
    , factors : List Int
    }


recipeDecoder : De.Decoder Recipe
recipeDecoder =
    De.map3 Recipe (De.field "slug" De.string) (De.field "content" De.string) (De.field "factors" (De.list De.int))


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


setRecipe : String -> String -> String -> Cmd Msg
setRecipe root slug content =
    Http.post
        { url = root ++ "/api/set/recipe/" ++ slug
        , expect = Http.expectJson LoadedRecipe recipeDecoder
        , body = Http.stringBody "application/json" content
        }



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | LoadedHome (Result Http.Error (List Recipe))
    | LoadedRecipe (Result Http.Error Recipe)
    | LoadedEditor Recipe
    | Scale String
    | Ready
    | Print
    | Edit String
    | Save


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Edit content ->
            case model.page of
                Editing recipe ->
                    ( { model | page = Editing { recipe | content = content } }, showRecipe content )

                _ ->
                    ( model, Cmd.none )

        Save ->
            case model.page of
                Editing recipe ->
                    ( { model | page = Loading }
                    , setRecipe model.rootUrl recipe.slug recipe.content
                    )

                _ ->
                    ( model, Cmd.none )

        Print ->
            ( model, print "" )

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

        LoadedEditor recipe ->
            ( { model | page = Editing recipe }, showRecipe recipe.content )

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
            viewRecipeViewer recipe

        Editing recipe ->
            viewRecipeEditor recipe

        Error message ->
            { title = "Error"
            , body = [ text message ]
            }


viewScaleButton : Int -> Html Msg
viewScaleButton factor =
    let
        scale =
            1.0 / toFloat factor

        label =
            if factor == 1 then
                "1"

            else
                "1/" ++ String.fromInt factor
    in
    button [ onClick (Scale (String.fromFloat scale)) ] [ text label ]


viewRecipeViewer : Recipe -> Browser.Document Msg
viewRecipeViewer recipe =
    { title = recipeName recipe
    , body =
        [ input [ onInput Scale ] []
        , div [ id "recipe" ] []
        , div [] (recipe.factors |> List.map viewScaleButton)
        , div []
            [ button [ onClick Print ] [ text "Print" ]
            , button [ onClick (LoadedEditor recipe) ] [ text "Edit" ]
            ]
        ]
    }


viewRecipeEditor : Recipe -> Browser.Document Msg
viewRecipeEditor recipe =
    { title = "Edit: " ++ recipeName recipe
    , body =
        [ textarea
            [ style "width" "100%"
            , style "height" "50vh"
            , value recipe.content
            , onInput Edit
            ]
            []
        , button [ onClick Save ] [ text "Save" ]
        , div [ id "recipe" ] []
        ]
    }


viewRecipeThumbnail : String -> Recipe -> Html Msg
viewRecipeThumbnail rootUrl recipe =
    a [ href (rootUrl ++ "recipe/" ++ recipe.slug) ]
        [ card []
            [ h2 [] [ text (recipeName recipe) ]
            , p [] [ text (recipeDescription recipe) ]
            ]
        ]


viewLink : String -> Html msg
viewLink path =
    li [] [ a [ href path ] [ text path ] ]
