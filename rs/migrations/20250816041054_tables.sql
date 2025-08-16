-- SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
--
-- SPDX-License-Identifier: GPL-3.0-only

-- Set up the initial tables
CREATE TABLE recipes (
    slug TEXT NOT NULL PRIMARY KEY,
    content TEXT NOT NULL
);
