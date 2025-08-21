-- SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
--
-- SPDX-License-Identifier: GPL-3.0-only


module Style exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)


borderRadius : String
borderRadius =
    "0.5em"


centeredPage : List (Attribute msg) -> List (Html msg) -> Html msg
centeredPage css content =
    div
        ([ style "max-width" "50em"
         , style "margin-left" "auto"
         , style "margin-right" "auto"
         , style "padding" "0.5em"
         ]
            ++ css
        )
        content


niceButton : List (Attribute msg) -> List (Html msg) -> Html msg
niceButton css content =
    button
        ([ style "border" "solid 1px #555555"
         , style "border-radius" borderRadius
         , style "background-color" "#303030"
         , style "color" "white"
         , style "box-shadow" "rgba(0, 0, 0, 0.6) 0px 0.2em 0.4em 0px"
         ]
            ++ css
        )
        content


card : List (Attribute msg) -> List (Html msg) -> List (Html msg) -> Html msg
card css heading content =
    div
        ([ style "padding" "0em"
         , style "margin-bottom" "1em"
         , style "border" "solid 1px #555555"
         , style "border-radius" borderRadius
         , style "color" "white"
         , style "box-shadow" "rgba(0, 0, 0, 0.6) 0px 0.2em 0.4em 0px"
         ]
            ++ css
        )
        [ div
            [ style "border-top-right-radius" borderRadius
            , style "border-top-left-radius" borderRadius
            , style "background-color" "#252525"
            , style "padding" "0.5em"
            , style "color" "white"
            , style "border-bottom" "solid 1px #555555"
            ]
            heading
        , div
            [ style "padding" "0.5em"
            , style "background-color" "#303030"
            , style "border-bottom-right-radius" borderRadius
            , style "border-bottom-left-radius" borderRadius
            ]
            content
        ]
