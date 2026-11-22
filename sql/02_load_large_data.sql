-- =====================================================================
-- Phase 5: 20x Large Dataset Loader (sql/02_load_large_data.sql)
--
-- Author: Tanishkka (Enrollment No: 2501010473, GitHub: Tanishkka27)
-- Database: PostgreSQL 15+
-- Schema: dream11
--
-- Purpose:
--   Loads the 20x large dataset into the dream11 schema following
--   strict relational foreign-key dependency ordering:
--   1. Dimension / Parent tables: teams, players, matches, users
--   2. Match & Player facts: player_match_stats
--   3. Fantasy teams: user_teams, user_team_players
--   4. Contests & entries: contests, contest_entries
--   5. Financial ledger: wallet_transactions
-- =====================================================================

SET search_path TO dream11;

\echo 'Loading teams...'
\copy teams FROM 'large_data/teams.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading players...'
\copy players FROM 'large_data/players.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading matches...'
\copy matches FROM 'large_data/matches.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading users (~1M rows)...'
\copy users FROM 'large_data/users.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading player match stats...'
\copy player_match_stats FROM 'large_data/player_match_stats.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading user fantasy teams (~800k rows)...'
\copy user_teams FROM 'large_data/user_teams.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading user team players (~8.8M rows)...'
\copy user_team_players FROM 'large_data/user_team_players.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading contests...'
\copy contests FROM 'large_data/contests.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading contest entries (~855k rows)...'
\copy contest_entries FROM 'large_data/contest_entries.csv' WITH (FORMAT csv, HEADER true)

\echo 'Loading wallet transactions (~2.37M rows)...'
\copy wallet_transactions FROM 'large_data/wallet_transactions.csv' WITH (FORMAT csv, HEADER true)

\echo 'Running ANALYZE to update PostgreSQL query planner statistics...'
ANALYZE;
