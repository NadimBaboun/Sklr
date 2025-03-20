-- Add new categories to the categories table
-- Execute this SQL in the Supabase SQL Editor

-- Add Business & Consulting category
INSERT INTO categories (name, description, asset)
VALUES ('Business & Consulting', 'Business strategy, consulting and professional services', 'business');

-- Add Education & Tutoring category
INSERT INTO categories (name, description, asset)
VALUES ('Education & Tutoring', 'Educational services, tutoring and academic support', 'edu');

-- Add Writing & Editing category
INSERT INTO categories (name, description, asset)
VALUES ('Writing & Editing', 'Content creation, copywriting and editing services', 'writing'); 