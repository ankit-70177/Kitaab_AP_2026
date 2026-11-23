# CP4 – Query Timings and Execution Plans
## Kitaab – Library Discovery and Membership Selection Platform

### Environment

| Item | Value |
|---|---|
| PostgreSQL version | 16.16 (Homebrew) on aarch64-apple-darwin |
| Database | `kitaab_cp4_test` |
| Schema | `dbms/03_schema.sql` |
| Seed data | 5 users · 6 libraries · 11 facilities · 17 library–facility links · 6 selections |
| Method | `EXPLAIN (ANALYZE, BUFFERS)` — 3 runs per query; write queries run inside `BEGIN … ROLLBACK` |
| Timing column | Execution Time (ms) reported by PostgreSQL — planning time excluded |

Queries are taken directly from `dbms/04_queries.sql`. Every query was executed and returned
correct results against the seed data before timing was recorded. Full `EXPLAIN (ANALYZE, BUFFERS)`
output for all three runs of each query is stored in `dbms/plans/<query-id>.txt`.

---

### Timing table

| Query | Type  | What it does                              | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Top plan node |
|-------|-------|-------------------------------------------|-----------:|-----------:|-----------:|-------------:|---------------|
| R1    | READ  | Login by email                            |      0.040 |      0.042 |      0.043 |        0.042 | Seq Scan on users |
| R2    | READ  | Load user by primary key                  |      0.035 |      0.074 |      0.035 |        0.048 | Index Scan using users_pkey |
| R3    | READ  | Search city / area with price ceiling     |      0.044 |      0.099 |      0.084 |        0.076 | Sort → Seq Scan on libraries |
| R4    | READ  | Load library profile with owner           |      0.046 |      0.152 |      0.096 |        0.098 | Nested Loop Left Join |
| R5    | READ  | List facilities for a library             |      0.124 |      0.213 |      0.211 |        0.183 | Sort → Hash Join |
| R6    | READ  | Browse listings with aggregated facilities|      0.170 |      0.373 |      0.290 |        0.278 | Limit → Sort → GroupAggregate |
| R7    | READ  | Find libraries by facility name           |      0.208 |      0.225 |      0.175 |        0.203 | Sort → Nested Loop |
| R8    | READ  | Customer selection history                |      0.243 |      0.274 |      0.197 |        0.238 | Sort → Hash Join |
| R9    | READ  | Count active selections per library       |      0.249 |      0.253 |      0.276 |        0.259 | Sort → HashAggregate |
| R10   | READ  | Summarize price and rating by city        |      0.120 |      0.193 |      0.197 |        0.170 | Sort → HashAggregate |
| R11   | READ  | Libraries with at least one facility      |      0.144 |      0.179 |      0.099 |        0.141 | Sort → Nested Loop Semi Join |
| R12   | READ  | Libraries with no active selections       |      0.222 |      0.093 |      0.125 |        0.147 | Sort → Hash Right Anti Join |
| W1    | WRITE | Register user account                     |      0.304 |      0.234 |      0.227 |        0.255 | Insert on users |
| W2    | WRITE | Create library listing                    |      1.519 |      1.574 |      0.743 |        1.279 | Insert on libraries + FK trigger |
| W3    | WRITE | Attach facility to library (upsert)       |      0.168 |      0.161 |      0.136 |        0.155 | Insert on library_facilities (conflict → NOTHING) |
| W4    | WRITE | Record customer selection                 |      2.054 |      2.053 |      1.875 |        1.994 | Insert on library_selections + FK trigger |
| W5    | WRITE | Cancel a selection                        |      0.421 |      0.487 |      0.288 |        0.399 | Update → Index Scan using library_selections_pkey |
| W6    | WRITE | Update library price and capacity         |      0.477 |      0.444 |      0.233 |        0.385 | Update → Index Scan using libraries_pkey |
| W7    | WRITE | Remove one facility association           |      0.194 |      0.127 |      0.233 |        0.185 | Delete → Index Scan using library_facilities_pkey |
| W8    | WRITE | Delete customer selection                 |      0.239 |      0.130 |      0.116 |        0.162 | Delete → Index Scan using library_selections_pkey |

---

### Observations

#### READ queries

**R1 — Login by email: Seq Scan (expected at this scale)**  
The schema stores `email` as `VARCHAR` and the query applies `lower()` on both sides:
`WHERE lower(email) = lower('owner@example.com')`. PostgreSQL cannot use a standard B-tree
index on `email` for this predicate because the function is applied to the indexed column.
At five rows the sequential scan is negligible (0.042 ms), but at production scale an
expression index `CREATE INDEX ON users ((lower(email)))` would convert this to an Index Scan.

**R2 — Load user by PK: Index Scan (optimal)**  
`WHERE user_id = 2` hits the primary-key B-tree index directly (0.048 ms). Optimal.

**R3 — City/area/price search: Seq Scan + Sort**  
The `ILIKE` predicates prevent index usage on `city` and `area` even if individual column
indexes existed (leading `%` and case-insensitive matching). The composite index
`idx_libraries_city_area(city, area)` defined in `03_schema.sql` is not used because the
query uses `ILIKE` rather than `=`. Result: Seq Scan on libraries (6 rows, 0.076 ms).

**R4 — Library profile + owner: Nested Loop Left Join using both PKs**  
Both `library_id = 1` (libraries PK) and `user_id = l.owner_id` (users PK) trigger Index
Scans. Nested Loop with PK lookups is optimal for point queries (0.098 ms).

**R5 — Facilities for one library: Hash Join**  
Joins `library_facilities` and `facilities` through a Hash Join (0.183 ms). At small
scale this is fine; with many facilities a Nested Loop on the PK would also be efficient.

**R6 — Browse with aggregated facilities: GroupAggregate / Limit**  
Most complex READ: filters by city, left-joins two tables, aggregates facility names with
`string_agg`, sorts by rating, applies LIMIT. Planner uses a Limit → Sort → GroupAggregate
plan (0.278 ms). With a large library table, a partial index on `city` and pre-aggregation
via a materialized view would reduce cost.

**R7 — Libraries by facility: Nested Loop**  
Joins three tables to match a facility name. Planner chooses a Nested Loop after finding
the matching facility row via Seq Scan on facilities (11 rows). Average 0.203 ms.

**R8 — Customer selection history: Hash Join + Sort**  
Filters selections by `user_id = 2` (covered by `idx_library_selections_user`), joins
libraries via Hash Join, then sorts. Average 0.238 ms.

**R9 — Active selection count per library: HashAggregate**  
`GROUP BY library_id` with a filtered `count()`. HashAggregate on a small result (6 rows).
Average 0.259 ms.

**R10 — City summary: HashAggregate**  
Two cities, Seq Scan + HashAggregate. Average 0.170 ms.

**R11 — Libraries with ≥ 1 facility (EXISTS): Nested Loop Semi Join**  
PostgreSQL converts the EXISTS subquery into a Nested Loop Semi Join. Stops at the first
matching row per library. Average 0.141 ms.

**R12 — Libraries with no active selections (NOT EXISTS): Hash Right Anti Join**  
Planner rewrites NOT EXISTS as a Hash Right Anti Join. Efficient at small scale (0.147 ms).

#### WRITE queries

All write queries run inside `BEGIN … ROLLBACK` so the seed data is preserved.

**W1 — Insert user (0.255 ms)**  
Simple insert with unique-index check on `email`. Fast.

**W2 — Insert library (1.279 ms, highest variance)**  
Triggers a foreign-key constraint trigger (`libraries_owner_id_fkey`) that validates
`owner_id` via an index lookup on `users`. The trigger accounts for ~0.986 ms of the
run-1 cost. Run 3 was faster (0.743 ms) due to OS buffer caching.

**W3 — Upsert facility link (0.155 ms)**  
`ON CONFLICT DO NOTHING` path hit because library 1 already has facility 2 in the seed.
The conflict arbiter uses `library_facilities_pkey`. Cost is effectively just the PK check.

**W4 — Insert selection (1.994 ms, slowest)**  
Two foreign-key triggers fire: `library_selections_user_id_fkey` and
`library_selections_library_id_fkey`. Each does an index lookup; together they add ~1.9 ms.
This is expected behaviour for FK enforcement.

**W5 — Cancel selection (0.399 ms)**  
UPDATE filters by PK + user_id via Index Scan; the filter drops rows not owned by user 2.

**W6 — Update library price/capacity (0.385 ms)**  
UPDATE by PK + owner_id via Index Scan. Same pattern as W5.

**W7 — Delete facility association (0.185 ms)**  
DELETE by composite PK via Index Scan. Fast because FK is `ON DELETE RESTRICT` (no
cascade). The referenced row in `facilities` is not touched.

**W8 — Delete selection (0.162 ms)**  
DELETE by PK + user_id via Index Scan. `ON DELETE CASCADE` on `user_id` and `library_id`
would fire only if the parent row were deleted; here only the selection itself is deleted.

---

### Index effectiveness summary

| Index | Queries that use it | Verdict |
|---|---|---|
| `users_pkey` | R2, R4, W1 (conflict check), W5, W6 | ✅ Used |
| `libraries_pkey` | R4, W2 (FK check), W6 | ✅ Used |
| `library_facilities_pkey` (composite) | R5, W3, W7 | ✅ Used |
| `library_selections_pkey` | W5, W8 | ✅ Used |
| `idx_library_selections_user` | R8 | ✅ Used |
| `idx_library_selections_library` | R9 (via hash join) | ✅ Used |
| `idx_libraries_city_area` | R3, R6 | ❌ Not used — ILIKE predicates bypass B-tree |

**Notable gap:** `idx_libraries_city_area` is never used because R3 and R6 use
`ILIKE` / `= 'Sonipat'` (R6 uses strict equality and could use the index on a larger
table, but the planner chose Seq Scan at 6 rows as the cheaper option).

---

### Limitations

- The database contains representative seed data only (5–18 rows per table).
  At production scale (thousands of libraries and selections) the planner would choose
  different strategies — in particular Index Scans instead of Seq Scans for R1, R3, R6,
  R9, R10, and R12.
- Timings are from a local development machine (Apple Silicon). They measure execution
  speed in milliseconds but are not representative of production server throughput.
- Write query timing includes foreign-key trigger overhead, which is accurate and expected.
- The `lower(email)` pattern in R1 warrants an expression index in production.

---

### File inventory

| File | Description |
|---|---|
| `dbms/05_query_timings.md` | This document |
| `dbms/plans/R1.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R1 |
| `dbms/plans/R2.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R2 |
| `dbms/plans/R3.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R3 |
| `dbms/plans/R4.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R4 |
| `dbms/plans/R5.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R5 |
| `dbms/plans/R6.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R6 |
| `dbms/plans/R7.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R7 |
| `dbms/plans/R8.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R8 |
| `dbms/plans/R9.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R9 |
| `dbms/plans/R10.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R10 |
| `dbms/plans/R11.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R11 |
| `dbms/plans/R12.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for R12 |
| `dbms/plans/W1.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for W1 |
| `dbms/plans/W2.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for W2 |
| `dbms/plans/W3.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for W3 |
| `dbms/plans/W4.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for W4 |
| `dbms/plans/W5.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for W5 |
| `dbms/plans/W6.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for W6 |
| `dbms/plans/W7.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for W7 |
| `dbms/plans/W8.txt` | EXPLAIN (ANALYZE, BUFFERS) × 3 for W8 |
