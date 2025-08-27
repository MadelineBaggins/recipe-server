-- SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
--
-- SPDX-License-Identifier: GPL-3.0-only


port module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import File exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (on, onClick, onInput)
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
    | NewRecipe String
    | Error String


type alias Recipe =
    { slug : String
    , content : String
    , factors : List Int
    , image : String
    }


recipeDecoder : De.Decoder Recipe
recipeDecoder =
    De.map4 Recipe (De.field "slug" De.string) (De.field "content" De.string) (De.field "factors" (De.list De.int)) (De.field "image" De.string)


recipeName : Recipe -> String
recipeName recipe =
    recipe.content |> String.split "\n" |> List.head |> Maybe.withDefault recipe.content |> String.dropLeft 2


recipeDescription : Recipe -> String
recipeDescription recipe =
    recipe.content |> String.split "\n\n## Ingredients" |> List.head |> Maybe.withDefault recipe.content |> String.lines |> List.drop 2 |> String.join "\n"


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url key =
    case String.split "recipe/" (Url.toString url) of
        [ root, slug ] ->
            ( Model key url root Loading, getRecipe root slug )

        _ ->
            if Url.toString url |> String.endsWith "/" then
                ( Model key url (Url.toString url) Loading, getHome (Url.toString url) )

            else
                ( Model key url (Url.toString url) Loading, getHome (Url.toString url ++ "/") )


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


newRecipe : String -> String -> Cmd Msg
newRecipe root name =
    let
        slug =
            name |> String.toLower |> String.replace " " "-"
    in
    Http.post
        { url = root ++ "/api/new/recipe/" ++ slug
        , expect = Http.expectJson LoadedRecipe recipeDecoder
        , body = Http.stringBody "application/text" name
        }


setRecipeImage : String -> String -> File -> Cmd Msg
setRecipeImage root slug file =
    Http.post
        { url = root ++ "/api/set/image/" ++ slug ++ "/" ++ File.name file
        , expect = Http.expectJson LoadedRecipe recipeDecoder
        , body = Http.fileBody file
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
    | NewRecipeNameFieldChanged String
    | ToNewRecipe
    | CreateRecipe String
    | GotFiles (List File)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ToNewRecipe ->
            ( { model | page = NewRecipe "" }, Cmd.none )

        CreateRecipe name ->
            ( { model | page = Loading }, newRecipe model.rootUrl name )

        NewRecipeNameFieldChanged name ->
            case model.page of
                NewRecipe _ ->
                    ( { model | page = NewRecipe name }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

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

        GotFiles files ->
            case model.page of
                Editing recipe ->
                    case files of
                        [ file ] ->
                            ( { model | page = Loading }
                            , setRecipeImage model.rootUrl recipe.slug file
                            )

                        _ ->
                            ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )



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
            viewHome model.rootUrl recipes

        Viewing recipe ->
            viewRecipeViewer model.rootUrl recipe

        Editing recipe ->
            viewRecipeEditor model.rootUrl recipe

        NewRecipe name ->
            { title = "New Recipe"
            , body =
                [ pageHeader model.rootUrl
                , centeredPage []
                    [ card
                        [ style "margin" "0.5em"
                        , style "text-align" "center"
                        ]
                        [ strong [] [ text "New Recipe" ] ]
                        [ input
                            [ placeholder "Recipe Name"
                            , value name
                            , onInput NewRecipeNameFieldChanged
                            ]
                            []
                        , niceButton [ onClick (CreateRecipe name) ] [ text "Create" ]
                        ]
                    ]
                ]
            }

        Error message ->
            { title = "Error"
            , body = [ text message ]
            }


pageHeader : String -> Html msg
pageHeader rootUrl =
    a
        [ href rootUrl
        , style "text-decoration" "none"
        , style "width" "100%"
        ]
        [ div
            [ style "width" "100%"
            , style "margin" "0em"
            , style "background-color" "#252525"
            , style "text-align" "center"
            , style "box-sizing" "border-box"
            , style "color" "white"
            , style "padding" "0.1rem"
            , style "border-bottom-left-radius" "2em"
            , style "border-bottom-right-radius" "2em"
            , style "margin-bottom" "1em"
            , style "box-shadow" "rgba(0, 0, 0, 0.6) 0px 0.2em 0.4em 0px"
            ]
            [ h5
                [ style "margin-bottom" "0em"
                , style "margin-top" "0.5rem"
                ]
                [ text "Sophie & Maddie's" ]
            , h1
                [ style "margin-top" "0em"
                , style "margin-bottom" "0.5rem"
                ]
                [ text "Recipe Box" ]
            ]
        ]


viewHome : String -> List Recipe -> Browser.Document Msg
viewHome rootUrl recipes =
    { title = "Recipes"
    , body =
        [ pageHeader rootUrl
        , centeredPage []
            ((recipes |> List.map (viewRecipeThumbnail rootUrl))
                ++ [ niceButton [ onClick ToNewRecipe ] [ text "New" ] ]
            )
        ]
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
    niceButton
        [ style "margin" "0.1em"
        , onClick (Scale (String.fromFloat scale))
        ]
        [ text label ]


viewRecipeViewer : String -> Recipe -> Browser.Document Msg
viewRecipeViewer rootUrl recipe =
    { title = recipeName recipe
    , body =
        [ pageHeader rootUrl
        , centeredPage []
            [ card [ style "margin" "0.5em" ]
                [ strong [] [ text "Image" ] ]
                [ img [ src (rootUrl ++ "/api/get/recipe/" ++ recipe.slug ++ "/" ++ recipe.image) ] [] ]
            , card [ style "margin" "0.5em" ]
                [ strong [] [ text "Recipe  " ]
                , niceButton
                    [ onClick (LoadedEditor recipe)
                    , style "margin-left" "0.5em"
                    , style "float" "right"
                    ]
                    [ text "Edit" ]
                , niceButton
                    [ onClick Print
                    , style "float" "right"
                    ]
                    [ text "Print" ]
                ]
                [ div [ id "recipe" ] []
                ]
            , card [ style "margin" "0.5em" ]
                [ strong [] [ text "Scale Recipe" ] ]
                [ input
                    [ onInput Scale
                    , placeholder "Custom scale"
                    ]
                    []
                , div [] (recipe.factors |> List.map viewScaleButton)
                ]
            ]
        ]
    }


filesDecoder : De.Decoder (List File)
filesDecoder =
    De.at [ "target", "files" ] (De.list File.decoder)


viewRecipeEditor : String -> Recipe -> Browser.Document Msg
viewRecipeEditor rootUrl recipe =
    { title = "Edit: " ++ recipeName recipe
    , body =
        [ pageHeader rootUrl
        , centeredPage []
            [ card [ style "margin" "0.5em" ]
                [ strong [] [ text "Editor" ]
                , niceButton
                    [ onClick Save
                    , style "float" "right"
                    ]
                    [ text "Save" ]
                ]
                [ textarea
                    [ style "width" "100%"
                    , style "height" "50vh"
                    , style "color" "white"
                    , style "background-color" "#353535"
                    , style "padding" "1em"
                    , style "box-sizing" "border-box"
                    , style "resize" "vertical"
                    , style "font-size" "1.1em"
                    , value recipe.content
                    , onInput Edit
                    ]
                    []
                ]
            , card [ style "margin" "0.5em" ]
                [ strong [] [ text "Preview" ] ]
                [ div [ id "recipe" ] []
                ]
            , card [ style "margin" "0.5em" ]
                [ strong [] [ text "Upload Image" ] ]
                [ input
                    [ type_ "file"
                    , multiple True
                    , on "change" (De.map GotFiles filesDecoder)
                    ]
                    []
                ]
            ]
        ]
    }


viewRecipeThumbnail : String -> Recipe -> Html Msg
viewRecipeThumbnail rootUrl recipe =
    a
        [ href (rootUrl ++ "recipe/" ++ recipe.slug)
        , style "text-decoration" "none"
        ]
        [ card
            [ style "text-align" "center"
            ]
            [ strong [] [ text (recipeName recipe) ] ]
            [ p [] [ text (recipeDescription recipe) ]
            ]
        ]


viewLink : String -> Html msg
viewLink path =
    li [] [ a [ href path ] [ text path ] ]
