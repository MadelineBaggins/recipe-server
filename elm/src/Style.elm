-- SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
--
-- SPDX-License-Identifier: GPL-3.0-only


module Style exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)


card : List (Attribute msg) -> List (Html msg) -> Html msg
card css content =
    div
        ([ style "padding" "1em"
         , style "margin" "1em"
         , style "border" "1px solid black"
         , style "border-radius" "1em"
         ]
            ++ css
        )
        content
