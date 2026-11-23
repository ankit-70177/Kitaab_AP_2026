-- Kitaab Library Platform
-- CP2: Proposed PostgreSQL relational schema
-- This schema is a database design, not an already-connected backend.

CREATE TABLE users (
    user_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'customer'
        CHECK (role IN ('customer', 'owner')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE libraries (
    library_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    owner_id BIGINT REFERENCES users(user_id) ON DELETE SET NULL,
    library_name VARCHAR(150) NOT NULL,
    area VARCHAR(120) NOT NULL,
    city VARCHAR(100) NOT NULL,
    monthly_price NUMERIC(10, 2) NOT NULL CHECK (monthly_price >= 0),
    seat_capacity INTEGER NOT NULL CHECK (seat_capacity > 0),
    rating NUMERIC(2, 1) CHECK (rating >= 0 AND rating <= 5),
    opening_hours VARCHAR(100) NOT NULL,
    image_path TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE facilities (
    facility_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    facility_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE library_facilities (
    library_id BIGINT NOT NULL
        REFERENCES libraries(library_id) ON DELETE CASCADE,
    facility_id BIGINT NOT NULL
        REFERENCES facilities(facility_id) ON DELETE RESTRICT,
    PRIMARY KEY (library_id, facility_id)
);

CREATE TABLE library_selections (
    selection_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL
        REFERENCES users(user_id) ON DELETE CASCADE,
    library_id BIGINT NOT NULL
        REFERENCES libraries(library_id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'cancelled')),
    selected_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common lookup and relationship queries.
CREATE INDEX idx_libraries_city_area
    ON libraries(city, area);

CREATE INDEX idx_library_selections_user
    ON library_selections(user_id);

CREATE INDEX idx_library_selections_library
    ON library_selections(library_id);

-- Note:
-- This schema does not implement payments, paid subscriptions,
-- individual seat reservations, or individual customer reviews.
-- Those require additional requirements and tables.
-- individual seat reservations, or individual customer reviews.