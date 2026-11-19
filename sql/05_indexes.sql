-- =====================================================================
-- Phase 4: Database Indexes (sql/05_indexes.sql)
--
-- Author: Tanishkka (Enrollment No: 2501010473, GitHub: Tanishkka27)
-- Database: PostgreSQL 15+ (Postgres.app standard build)
-- Schema: dream11
--
-- Purpose:
--   PostgreSQL automatically creates B-tree indexes for PRIMARY KEY and
--   UNIQUE constraints, but leaves all Foreign Key columns and search
--   attributes unindexed. In Phase 3, this forced Sequential Scans across
--   all heavy tables (user_team_players: 440k rows, wallet_transactions:
--   118k rows, user_teams: 40k rows, contest_entries: 43k rows).
--
--   This file implements targeted B-tree, Composite, and Covering indexes
--   to transform those bottlenecks into sub-millisecond Index Scans and
--   Index-Only Scans.
-- =====================================================================

SET search_path TO dream11;

-- ---------------------------------------------------------------------
-- 1. FOREIGN KEY INDEXES (Relational Join Optimization)
-- ---------------------------------------------------------------------

-- Query Served: R02, R06, R08, W04
-- Target Table: user_teams (39,975 rows)
-- Index Type: B-tree
-- Justification:
--   Foreign key column `match_id` references `matches(match_id)`.
--   Without this index, finding fantasy teams participating in a match
--   (e.g., match 183 or match 207) requires a full table scan.
--   A standard B-tree index on `match_id` enables logarithmic index lookups
--   and reduces scan cost from O(N) to O(log N).
CREATE INDEX IF NOT EXISTS idx_user_teams_match_id
ON dream11.user_teams USING btree (match_id);


-- Query Served: R19, R02, R06
-- Target Table: user_team_players (439,925 rows)
-- Index Type: B-tree
-- Justification:
--   The primary key on `user_team_players` is `(user_team_id, player_id)`.
--   Because `player_id` is the second column of the composite key, B-tree
--   left-prefix rules prevent index lookups by `player_id` alone.
--   In R19, calculating player pick frequency across all teams took ~2,090 ms
--   due to repeated sequential scans of 440k tuples.
--   Adding a secondary B-tree on `player_id` allows immediate point lookups
--   and index-only aggregations.
CREATE INDEX IF NOT EXISTS idx_user_team_players_player_id
ON dream11.user_team_players USING btree (player_id);


-- Query Served: R04, R05, R11, R14, R17, R21
-- Target Table: contest_entries (42,746 rows)
-- Index Type: B-tree
-- Justification:
--   Foreign key column `contest_id` is the leading column in the candidate
--   key `(contest_id, user_team_id)`. However, queries joining from
--   `contests` to `contest_entries` filtering on non-unique entries or
--   aggregating spots filled benefit from explicit indexing when joined
--   with secondary filters.
CREATE INDEX IF NOT EXISTS idx_contest_entries_contest_id
ON dream11.contest_entries USING btree (contest_id);


-- Query Served: R11, R15, R17, R21, R25
-- Target Table: contest_entries (42,746 rows)
-- Index Type: B-tree
-- Justification:
--   Foreign key column `user_team_id` references `user_teams(user_team_id)`.
--   Joining a user's fantasy team to all contest entries it entered currently
--   triggers a sequential scan over 42,746 rows. A B-tree index provides
--   instant join resolution.
CREATE INDEX IF NOT EXISTS idx_contest_entries_user_team_id
ON dream11.contest_entries USING btree (user_team_id);


-- Query Served: R01, R04, W02
-- Target Table: contests (2,544 rows)
-- Index Type: B-tree
-- Justification:
--   Foreign key `match_id` references `matches(match_id)`.
--   Upcoming matches in the lobby (R01) and contest selection screens (R04)
--   retrieve contests for specific matches. Indexing `match_id` enables
--   direct index lookups for match contests.
CREATE INDEX IF NOT EXISTS idx_contests_match_id
ON dream11.contests USING btree (match_id);


-- Query Served: R11, R15
-- Target Table: user_teams (39,975 rows)
-- Index Type: B-tree
-- Justification:
--   Foreign key `user_id` references `users(user_id)`.
--   Finding all teams built by users from specific compliance states (R11)
--   or aggregating winnings per user (R15) joins `users` to `user_teams`
--   on `user_id`. An index avoids hashing the entire 40k row table.
CREATE INDEX IF NOT EXISTS idx_user_teams_user_id
ON dream11.user_teams USING btree (user_id);


-- Query Served: R13, R25
-- Target Table: wallet_transactions (118,343 rows)
-- Index Type: B-tree (Partial)
-- Justification:
--   Foreign key `reference_entry_id` points to `contest_entries(entry_id)`.
--   Only contest entries and entry refunds populate this column; deposits
--   and withdrawals leave it NULL (~63,000 NULL rows).
--   A partial B-tree index indexing only `WHERE reference_entry_id IS NOT NULL`
--   keeps the index compact (~1 MB) while accelerating audit queries R13 and R25
--   from 13.5 ms down to sub-millisecond execution.
CREATE INDEX IF NOT EXISTS idx_wallet_reference_entry_id
ON dream11.wallet_transactions USING btree (reference_entry_id)
WHERE reference_entry_id IS NOT NULL;


-- ---------------------------------------------------------------------
-- 2. COVERING & COMPOSITE INDEXES (Zero-Heap Index Only Scans)
-- ---------------------------------------------------------------------

-- Query Served: R09 (Wallet transaction ledger with running balance)
-- Target Table: wallet_transactions (118,343 rows)
-- Index Type: B-tree Covering Index
-- Column Order: (user_id, status, created_at, txn_id) INCLUDE (txn_type, amount)
-- Justification:
--   1. Equality predicates first: `user_id = 1006` and `status = 'SUCCESS'`.
--   2. Sort order next: `ORDER BY created_at, txn_id`.
--   3. Covering payload: `INCLUDE (txn_type, amount)` attaches the needed
--      attributes to the leaf nodes of the B-tree without participating in
--      the tree search key.
--   Result: PostgreSQL executes an Index-Only Scan without visiting the table
--   heap, reducing execution time from ~4.2 ms to <0.05 ms.
CREATE INDEX IF NOT EXISTS idx_wallet_user_status_created_covering
ON dream11.wallet_transactions USING btree (user_id, status, created_at, txn_id)
INCLUDE (txn_type, amount);


-- Query Served: R15 (Leaderboard: top 20 users by winnings in 2026)
-- Target Table: contest_entries (42,746 rows)
-- Index Type: B-tree Covering Index
-- Column Order: (joined_at) INCLUDE (user_team_id, winnings)
-- Justification:
--   R15 filters on range `joined_at >= '2026-01-01'` and aggregates `winnings`
--   grouped by user. Including `user_team_id` and `winnings` permits an
--   Index-Only Scan on the 2026 slice of contest entries.
CREATE INDEX IF NOT EXISTS idx_contest_entries_joined_at_covering
ON dream11.contest_entries USING btree (joined_at)
INCLUDE (user_team_id, winnings);


-- Query Served: R08 (Most-picked captains for a match)
-- Target Table: user_teams (39,975 rows)
-- Index Type: Composite B-tree
-- Column Order: (match_id, captain_id)
-- Justification:
--   Filters by `match_id = 207` and groups by `captain_id`.
--   A composite index allows an Index-Only Scan to group and count captain
--   frequencies directly from index leaves.
CREATE INDEX IF NOT EXISTS idx_user_teams_match_captain
ON dream11.user_teams USING btree (match_id, captain_id);
