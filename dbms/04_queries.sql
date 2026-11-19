-- CP3 queries for the Kitaab library discovery and selection schema.
-- Tables/columns match dbms/03_schema.sql. Use bound parameters in the app
-- in place of the clearly labeled sample values below.
-- Owner application review, plans, payments, reviews and inventory are not
-- represented by this schema and therefore are not queried here.

-- @R1 -- READ
-- Find an account by email for sign-in; compare the stored password hash in the application.
SELECT user_id, full_name, email, password_hash, role
FROM users
WHERE lower(email) = lower('owner@example.com');

-- @R2 -- READ
-- Load a user's account details by primary key.
SELECT user_id, full_name, email, role, created_at
FROM users
WHERE user_id = 2;

-- @R3 -- READ
-- Search city/area listings within a monthly-price ceiling, ordered by price then name.
SELECT library_id, library_name, area, city, monthly_price, rating, seat_capacity
FROM libraries
WHERE city ILIKE 'Sonipat'
  AND area ILIKE '%Model Town%'
  AND monthly_price <= 1000
ORDER BY monthly_price, library_name;

-- @R4 -- READ
-- Load a library profile and its optional owner's public name.
SELECT l.library_id, l.library_name, l.area, l.city, l.monthly_price,
       l.seat_capacity, l.rating, l.opening_hours, l.image_path,
       u.user_id AS owner_id, u.full_name AS owner_name
FROM libraries AS l
LEFT JOIN users AS u ON u.user_id = l.owner_id
WHERE l.library_id = 1;

-- @R5 -- READ
-- List a library's facilities through the many-to-many junction table.
SELECT f.facility_id, f.facility_name
FROM library_facilities AS lf
JOIN facilities AS f ON f.facility_id = lf.facility_id
WHERE lf.library_id = 1
ORDER BY f.facility_name;

-- @R6 -- READ
-- Browse listings with facilities aggregated into one display field.
SELECT l.library_id, l.library_name, l.area, l.city, l.monthly_price,
       l.rating, l.seat_capacity,
       COALESCE(string_agg(f.facility_name, ', ' ORDER BY f.facility_name), '') AS facilities
FROM libraries AS l
LEFT JOIN library_facilities AS lf ON lf.library_id = l.library_id
LEFT JOIN facilities AS f ON f.facility_id = lf.facility_id
WHERE l.city = 'Sonipat'
GROUP BY l.library_id
ORDER BY l.rating DESC NULLS LAST, l.library_name
LIMIT 20;

-- @R7 -- READ
-- Find libraries that provide a selected facility.
SELECT l.library_id, l.library_name, l.area, l.city, l.monthly_price
FROM libraries AS l
JOIN library_facilities AS lf ON lf.library_id = l.library_id
JOIN facilities AS f ON f.facility_id = lf.facility_id
WHERE f.facility_name = 'High-speed Wi-Fi'
ORDER BY l.monthly_price, l.library_name;

-- @R8 -- READ
-- Show a customer's current and past library selections, newest first.
SELECT s.selection_id, s.status, s.selected_at, s.updated_at,
       l.library_id, l.library_name, l.area, l.city, l.monthly_price
FROM library_selections AS s
JOIN libraries AS l ON l.library_id = s.library_id
WHERE s.user_id = 2
ORDER BY s.selected_at DESC;

-- @R9 -- READ
-- Count active selections for each library, including libraries with none.
SELECT l.library_id, l.library_name,
       count(s.selection_id) FILTER (WHERE s.status = 'active') AS active_selections
FROM libraries AS l
LEFT JOIN library_selections AS s ON s.library_id = l.library_id
GROUP BY l.library_id
ORDER BY active_selections DESC, l.library_name;

-- @R10 -- READ
-- Summarize listing price and rating by city.
SELECT city, count(*) AS library_count,
       round(avg(monthly_price), 2) AS average_monthly_price,
       round(avg(rating), 2) AS average_rating
FROM libraries
GROUP BY city
ORDER BY library_count DESC, city;

-- @R11 -- READ
-- Find libraries with at least one facility using an EXISTS subquery.
SELECT l.library_id, l.library_name, l.city
FROM libraries AS l
WHERE EXISTS (
    SELECT 1
    FROM library_facilities AS lf
    WHERE lf.library_id = l.library_id
)
ORDER BY l.library_name;

-- @R12 -- READ
-- Find libraries that have no active customer selections using NOT EXISTS.
SELECT l.library_id, l.library_name
FROM libraries AS l
WHERE NOT EXISTS (
    SELECT 1
    FROM library_selections AS s
    WHERE s.library_id = l.library_id
      AND s.status = 'active'
)
ORDER BY l.library_name;

-- @W1 -- WRITE
-- Register a user account; the application must supply a securely hashed password.
INSERT INTO users (full_name, email, password_hash, role)
VALUES ('CP3 Sample Owner', 'cp3-owner@example.com', '$2b$12$replace_with_real_hash', 'owner')
RETURNING user_id, full_name, email, role;

-- @W2 -- WRITE
-- Create a library listing for the selected owner account.
INSERT INTO libraries
    (owner_id, library_name, area, city, monthly_price, seat_capacity, rating, opening_hours, image_path)
VALUES
    (1, 'CP3 Sample Library', 'Model Town', 'Sonipat', 800.00, 20, NULL,
     '6:00 AM – 10:00 PM', '/images/cp3-sample.webp')
RETURNING library_id, library_name;

-- @W3 -- WRITE
-- Attach an existing facility to a library.
INSERT INTO library_facilities (library_id, facility_id)
VALUES (1, 2)
ON CONFLICT (library_id, facility_id) DO NOTHING
RETURNING library_id, facility_id;

-- @W4 -- WRITE
-- Record a customer's library selection.
INSERT INTO library_selections (user_id, library_id, status)
VALUES (2, 1, 'active')
RETURNING selection_id, user_id, library_id, status, selected_at;

-- @W5 -- WRITE
-- Cancel a selection only when it belongs to the requesting customer.
UPDATE library_selections
SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP
WHERE selection_id = 1
  AND user_id = 2
RETURNING selection_id, status, updated_at;

-- @W6 -- WRITE
-- Update the price and capacity of a library owned by the authenticated owner.
UPDATE libraries
SET monthly_price = 850.00, seat_capacity = 24
WHERE library_id = 1
  AND owner_id = 1
RETURNING library_id, monthly_price, seat_capacity;

-- @W7 -- WRITE
-- Remove one facility association without deleting the shared facility.
DELETE FROM library_facilities
WHERE library_id = 1
  AND facility_id = 2
RETURNING library_id, facility_id;

-- @W8 -- WRITE
-- Delete a selection belonging to the requesting customer.
DELETE FROM library_selections
WHERE selection_id = 1
  AND user_id = 2
RETURNING selection_id, user_id, library_id;
