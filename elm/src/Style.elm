-- SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
--
-- SPDX-License-Identifier: GPL-3.0-only


module Style exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)


card : List (Attribute msg) -> List (Html msg) -> Html msg
card css content =
    div
        ([ style "border" "solid black 1px"
         , style "border-radius" "1em"
         , style "padding" "0.5em"
         ]
            ++ css
        )
        content
