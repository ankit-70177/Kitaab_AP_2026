# Kitaab · AP Database Project

This repository contains the database coursework for the Kitaab library discovery and membership-selection platform. Kitaab helps customers find and compare study libraries and helps owners publish library listings. It is a study-space discovery platform, not a book-catalogue or book-lending system.

## Database scope

The current coursework model is defined in dbms/03_schema.sql and includes users, libraries, facilities, library-facility links, and library selections. The SQL file is a proposed relational schema for the coursework; it is not a claim that these tables have already been deployed to the application database.

This model does not yet include owner application review, membership plans or payments, seat reservations, customer subscriptions, reviews, or administrator audit records. Add those relations only when their requirements and schema are part of the coursework scope.

## Checkpoint files

| File | Purpose |
|---|---|
| dbms/01_normalization.md | Normalization from the sample library data through 3NF |
| dbms/02_er_diagram.png | Entity relationships and cardinalities |
| dbms/diagrams/er_diagram.mmd | Editable Mermaid source for the diagram |
| dbms/03_schema.sql | PostgreSQL tables, keys, checks, and indexes |
| dbms/04_queries.sql | 12 READ and 8 WRITE examples based on the schema |

The query file labels every query and explains its purpose. Its sample values are for coursework demonstration; replace them with safely bound parameters in application code. Queries concerning entities absent from 03_schema.sql are not included.

## Verify the schema and queries

Use PostgreSQL. Create a clean database, apply the schema, and load representative sample rows that satisfy its foreign keys and constraints. Run the READ examples and execute the WRITE examples inside a transaction that you roll back so the sample data remains unchanged.

The schema and query set were executed against PostgreSQL 18.6 with sample users, libraries, facilities, and selections. All 20 queries completed; the test WRITE statements were rolled back.

## Repository layout

~~~text
Kitaab_AP_2026/
├── README.md
├── .gitignore
└── dbms/
    ├── 01_normalization.md
    ├── 02_er_diagram.png
    ├── 03_schema.sql
    ├── 04_queries.sql
    └── diagrams/
        └── er_diagram.mmd
~~~
