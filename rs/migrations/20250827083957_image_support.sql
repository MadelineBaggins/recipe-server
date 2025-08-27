-- SPDX-FileCopyrightText: 2025 Madeline Baggins <madeline@baggins.family>
--
-- SPDX-License-Identifier: GPL-3.0-only

-- Set up the columns for uploading images
ALTER TABLE recipes ADD COLUMN image BLOB;
ALTER TABLE recipes ADD COLUMN image_slug BLOB;
