# CP1 – Database Normalization
## Kitaab – Library Discovery and Membership Selection Platform

### 1. Application context

The customer frontend currently displays study libraries with their name, area, monthly price, seat capacity, rating, opening hours, image path and facilities.

The registration form collects a name, email and password. The current frontend stores a demo profile in browser localStorage. A customer can select a library and change the demo selection status between active and cancelled.

Important implementation note: the inspected backend currently exposes only a health-check endpoint. The database design below is a proposed relational design for persistent application data; it is not a claim that database-backed authentication or memberships are already implemented.

### 2. Unnormalized form (UNF)

The original library sample data can be represented as one record containing a repeating/multivalued Facilities field.

| LibraryID | LibraryName | Area | City | MonthlyPrice | Seats | Rating | OpeningHours | ImagePath | Facilities |
|---|---|---|---|---:|---:|---:|---|---|---|
| 1 | The Reading Room | Model Town | Sonipat | 800 | 13 | 4.8 | 6:00 AM – 10:00 PM | /images/sonipat-study-space.webp | Air conditioned; High-speed Wi-Fi; Power backup |
| 2 | Gyandeep Study Library | Kundli | Sonipat | 650 | 18 | 4.7 | 5:30 AM – 11:00 PM | /images/study-community.webp | Quiet study zone; Personal lockers; CCTV |
| 3 | Scholars Corner | Murthal Road | Sonipat | 900 | 6 | 4.9 | Open 24 hours | /images/study-session.webp | 24-hour access; Ergonomic desks; Tea & coffee |
| 4 | The Study Nook | Sector 14 | Sonipat | 750 | 9 | 4.6 | 6:00 AM – 9:30 PM | /images/library-gathering.webp | Reserved seating; Wi-Fi; Filtered water |

Problem: Facilities contains multiple values in one field. This makes searching, updating and maintaining individual facilities difficult.

### 3. First Normal Form (1NF)

Rule: Every field must contain one atomic value, and repeating groups must be removed.

The library data is expanded so that each row contains one facility.

| LibraryID | LibraryName | MonthlyPrice | Facility |
|---|---|---:|---|
| 1 | The Reading Room | 800 | Air conditioned |
| 1 | The Reading Room | 800 | High-speed Wi-Fi |
| 1 | The Reading Room | 800 | Power backup |
| 2 | Gyandeep Study Library | 650 | Quiet study zone |
| 2 | Gyandeep Study Library | 650 | Personal lockers |
| 2 | Gyandeep Study Library | 650 | CCTV |

The same expansion is applied to all four sample libraries.

Candidate composite key: (LibraryID, Facility).

Functional dependency:
- LibraryID → LibraryName, Area, City, MonthlyPrice, Seats, Rating, OpeningHours, ImagePath
- (LibraryID, Facility) identifies one library-facility association.

The data now satisfies 1NF, but library details are repeated for every facility.

### 4. Second Normal Form (2NF)

Rule: The relation must be in 1NF and every non-key attribute must depend on the whole candidate key, not only part of a composite key.

In the 1NF relation, the composite key is (LibraryID, Facility). LibraryName, Area, MonthlyPrice and the other library attributes depend only on LibraryID. This is a partial dependency.

Decompose the relation into:

**LIBRARIES**

| LibraryID (PK) | LibraryName | Area | City | MonthlyPrice | Seats | Rating | OpeningHours | ImagePath |
|---|---|---|---|---:|---:|---:|---|---|
| 1 | The Reading Room | Model Town | Sonipat | 800 | 13 | 4.8 | 6:00 AM – 10:00 PM | /images/sonipat-study-space.webp |
| 2 | Gyandeep Study Library | Kundli | Sonipat | 650 | 18 | 4.7 | 5:30 AM – 11:00 PM | /images/study-community.webp |
| 3 | Scholars Corner | Murthal Road | Sonipat | 900 | 6 | 4.9 | Open 24 hours | /images/study-session.webp |
| 4 | The Study Nook | Sector 14 | Sonipat | 750 | 9 | 4.6 | 6:00 AM – 9:30 PM | /images/library-gathering.webp |

**LIBRARY_FACILITIES_2NF**

| LibraryID (PK, FK) | FacilityName (PK) |
|---|---|
| 1 | Air conditioned |
| 1 | High-speed Wi-Fi |
| 1 | Power backup |
| 2 | Quiet study zone |
| 2 | Personal lockers |
| 2 | CCTV |
| 3 | 24-hour access |
| 3 | Ergonomic desks |
| 3 | Tea & coffee |
| 4 | Reserved seating |
| 4 | Wi-Fi |
| 4 | Filtered water |

Now library attributes are stored once per library. The association table contains only the composite key attributes.

### 5. Third Normal Form (3NF)

Rule: The relation must be in 2NF and non-key attributes must not depend transitively on a candidate key.

To maintain facility names independently and avoid repeating their text in every association, introduce a FACILITIES lookup table.

Final relations:

1. **USERS** (UserID PK, FullName, Email UNIQUE, PasswordHash, Role, CreatedAt)
2. **LIBRARIES** (LibraryID PK, OwnerID FK nullable, LibraryName, Area, City, MonthlyPrice, SeatCapacity, Rating, OpeningHours, ImagePath, CreatedAt)
3. **FACILITIES** (FacilityID PK, FacilityName UNIQUE)
4. **LIBRARY_FACILITIES** (LibraryID PK/FK, FacilityID PK/FK)
5. **LIBRARY_SELECTIONS** (SelectionID PK, UserID FK, LibraryID FK, Status, SelectedAt, UpdatedAt)

Functional dependencies:
- UserID → FullName, Email, PasswordHash, Role, CreatedAt
- Email → UserID, FullName, PasswordHash, Role, CreatedAt (Email is also unique)
- LibraryID → OwnerID, LibraryName, Area, City, MonthlyPrice, SeatCapacity, Rating, OpeningHours, ImagePath, CreatedAt
- FacilityID → FacilityName
- (LibraryID, FacilityID) → no additional non-key attributes; the pair identifies an association.
- SelectionID → UserID, LibraryID, Status, SelectedAt, UpdatedAt

The library-facility many-to-many relationship is resolved through LIBRARY_FACILITIES. User selections are stored separately from library details.

### 6. Normalization summary

| Normal Form | Change | Benefit |
|---|---|---|
| UNF | Facilities stored as a list in one field | Original sample representation |
| 1NF | One facility per row | Atomic values; no repeating groups |
| 2NF | Separate library details from library-facility associations | Removes partial dependency |
| 3NF | Create a FACILITIES lookup table and connect it through a junction table | Avoids repeated facility descriptions and supports consistent updates |

### 7. Scope and assumptions

- The four library records and their displayed attributes are taken from the current customer frontend sample data.
- User account and library-selection tables are proposed to persist information currently stored only in browser localStorage.
- Passwords must be stored as secure password hashes, never as plain text.
- OwnerID is nullable because the inspected sample library records do not currently identify owners.
- The displayed rating is sample data. A future user-review feature may replace or supplement it with individual review records.
- SeatCapacity is the displayed total capacity; individual seat inventory and reservations are not currently implemented.
- Demo selection status is not proof of a paid subscription or completed payment.
- Static event formats and customer-update cards are presentation content, not scheduled event records.
