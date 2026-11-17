# Checkpoint 2 (CP2) Baseline Timings Report: Dream11 Fantasy Sports

- **Course:** DBMS / Data Engineering (Rishihood University)
- **Instructor:** Prof. Satyaki Das
- **Evaluation Tracker:** [DBMS Project Tracker (Team T0140)](https://edusatyaki.github.io/dbms-project-tracker/)
- **Team ID:** T0140 | Section D
- **Student Name:** Kunal Agrawal (Enrollment No: 2501010238, GitHub: `kunal-13106`)
- **Group Lead:** Swastik Mishra (`swas78`)
- **Teammates:** Tanishkka (`Tanishkka27`), Abhijeet Saini (`abhijeet-s24`)
- **Deliverable:** `docs/03_baseline_timings.md` & `benchmarks/results/baseline/summary.csv`

---

## 1. Benchmark Environment & Methodology

The baseline benchmark executes the complete 30-query workload defined in `queries/workload_30.sql` (25 READ queries and 5 WRITE queries) against unindexed PostgreSQL tables (only primary key and unique constraint indexes exist).

### System & Hardware Specifications:
- **Operating System:** macOS (Darwin arm64)
- **Database Engine:** PostgreSQL 18.0 (Postgres.app standard build)
- **Search Path:** `dream11, public`
- **Dataset Size:**
  - `teams`: 18 rows
  - `players`: 450 rows
  - `matches`: 212 rows
  - `users`: 50,000 rows
  - `player_match_stats`: 4,444 rows
  - `user_teams`: 39,975 rows
  - `user_team_players`: 439,925 rows
  - `contests`: 2,544 rows
  - `contest_entries`: 42,746 rows
  - `wallet_transactions`: 118,343 rows
  - **Total Rows Evaluated:** ~698,657 rows

### Execution Protocol:
- Benchmark Harness: `./benchmarks/run_benchmark.sh dream11_db baseline 3`
- Every query is executed with `EXPLAIN (ANALYZE, BUFFERS)` for **3 consecutive iterations**.
- Write queries (`W01` – `W05`) execute within atomic `BEGIN; ... ROLLBACK;` blocks ensuring absolute data immutability.
- All raw execution plans, buffer cache hits, and timing measurements are captured in `benchmarks/results/baseline/`.

---

## 2. Comprehensive Baseline Timings Table

| Query | Type | Workload Target / Operation | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Median (ms) | Scan Nodes & Access Path |
|---|---|---|---:|---:|---:|---:|---:|---|
| **R01** | READ | Upcoming matches with contest counts and prize pool | 0.308 | 0.285 | 0.251 | **0.281** | 0.285 | `Seq Scan on contests | Seq Scan on matches | Seq Scan on teams` |
| **R02** | READ | User team roster with player names and roles | 41.874 | 29.403 | 28.376 | **33.218** | 29.403 | `Seq Scan on user_teams | Index Only Scan using user_team_players_pkey on user_team_players | Seq Scan on matches | Seq Scan on players | Seq Scan on teams` |
| **R03** | READ | Check user team label existence for a match | 0.063 | 0.046 | 0.050 | **0.053** | 0.050 | `Index Scan using user_teams_user_id_match_id_team_label_key on user_teams | Index Scan using players_pkey on players` |
| **R04** | READ | Contest details with current spots filled count | 0.210 | 0.231 | 0.244 | **0.228** | 0.231 | `Seq Scan on contests | Index Scan using contest_entries_contest_id_user_team_id_key on contest_entries` |
| **R05** | READ | Contest leaderboard ranked by total fantasy points | 0.650 | 0.422 | 0.411 | **0.494** | 0.422 | `Index Only Scan using contest_entries_contest_id_user_team_id_key on contest_entries | Index Scan using user_teams_pkey on user_teams | Index Scan using users_pkey on users` |
| **R06** | READ | All user teams participating in a specific match | 45.182 | 44.795 | 44.383 | **44.787** | 44.795 | `Seq Scan on user_teams | Index Only Scan using user_team_players_pkey on user_team_players | Seq Scan on players` |
| **R07** | READ | Player fantasy breakdown in a specific user team | 0.115 | 0.097 | 0.088 | **0.100** | 0.097 | `Index Scan using user_teams_user_id_match_id_team_label_key on user_teams | Index Only Scan using user_team_players_pkey on user_team_players | Index Scan using players_pkey on players | Index Scan using player_match_stats_pkey on player_match_stats` |
| **R08** | READ | Most selected captain players across user teams | 1.305 | 1.104 | 1.116 | **1.175** | 1.116 | `Seq Scan on user_teams | Seq Scan on players` |
| **R09** | READ | User wallet ledger sorted by transaction timestamp | 5.001 | 3.897 | 3.731 | **4.210** | 3.897 | `Seq Scan on wallet_transactions` |
| **R10** | READ | User net current balance computed from wallet transactions | 4.640 | 5.086 | 4.367 | **4.698** | 4.640 | `Seq Scan on wallet_transactions` |
| **R11** | READ | Contest entry list with user usernames and ranks | 12.592 | 12.745 | 12.263 | **12.533** | 12.592 | `Seq Scan on contest_entries | Seq Scan on user_teams | Seq Scan on users | Seq Scan on contests` |
| **R12** | READ | Top scoring fantasy players in a completed match | 0.863 | 1.002 | 0.826 | **0.897** | 0.863 | `Seq Scan on player_match_stats | Seq Scan on matches | Seq Scan on players | Seq Scan on teams` |
| **R13** | READ | Contest entries with missing entry fee transactions | 13.560 | 13.597 | 13.247 | **13.468** | 13.560 | `Seq Scan on contest_entries | Seq Scan on wallet_transactions | Seq Scan on contests` |
| **R14** | READ | Contests nearing full capacity (>80% spots filled) | 10.140 | 9.666 | 9.540 | **9.782** | 9.666 | `Seq Scan on contests | Seq Scan on matches | Index Scan using contest_entries_contest_id_user_team_id_key on contest_entries` |
| **R15** | READ | Users participating in multiple contests for a single match | 19.785 | 20.297 | 20.871 | **20.318** | 20.297 | `Seq Scan on contest_entries | Seq Scan on user_teams | Seq Scan on users` |
| **R16** | READ | Squad list of players for two competing teams | 0.211 | 0.199 | 0.193 | **0.201** | 0.199 | `Seq Scan on players | Seq Scan on teams` |
| **R17** | READ | User team points distribution for completed contests | 12.355 | 11.958 | 11.979 | **12.097** | 11.979 | `Seq Scan on contest_entries | Seq Scan on user_teams` |
| **R18** | READ | High-value transactions with user profile lookup | 8.830 | 9.000 | 9.017 | **8.949** | 9.000 | `Seq Scan on wallet_transactions | Seq Scan on users` |
| **R19** | READ | Head-to-head player selection overlap analysis | 2091.662 | 2085.705 | 2092.807 | **2090.058** | 2091.662 | `Seq Scan on players | Seq Scan on teams | Seq Scan on user_team_players` |
| **R20** | READ | Deposit vs withdrawal aggregate report per user | 5.268 | 4.523 | 4.522 | **4.771** | 4.523 | `Seq Scan on wallet_transactions` |
| **R21** | READ | Contest prize pool distribution vs collected fees | 5.288 | 5.125 | 5.491 | **5.301** | 5.288 | `Seq Scan on user_teams | Seq Scan on contest_entries | Seq Scan on contests` |
| **R22** | READ | Monthly transaction summary by transaction type | 23.724 | 23.952 | 24.933 | **24.203** | 23.952 | `Seq Scan on wallet_transactions` |
| **R23** | READ | Lookup user profile by phone number | 0.040 | 0.034 | 0.032 | **0.035** | 0.034 | `Index Scan using users_phone_key on users` |
| **R24** | READ | Top all-rounder performers in recent matches | 0.464 | 0.455 | 1.152 | **0.690** | 0.464 | `Seq Scan on player_match_stats | Seq Scan on players | Seq Scan on teams | Seq Scan on matches` |
| **R25** | READ | Audit log of winnings credited vs contest results | 9.294 | 9.018 | 8.775 | **9.029** | 9.018 | `Seq Scan on wallet_transactions | Seq Scan on contest_entries | Seq Scan on user_teams | Seq Scan on matches | Seq Scan on contests` |
| **W01** | WRITE | Insert new match into matches schedule | 0.678 | 2.115 | 0.551 | **1.115** | 0.678 | `Seq Scan on matches` |
| **W02** | WRITE | Create new contest for an upcoming match | 0.550 | 0.334 | 0.336 | **0.407** | 0.336 | `Index Scan using user_teams_pkey on user_teams | Seq Scan on contests` |
| **W03** | WRITE | Submit user contest entry and lock team | 0.517 | 0.803 | 0.450 | **0.590** | 0.517 | `Index Only Scan using contest_entries_pkey on contest_entries | Index Scan using contest_entries_pkey on contest_entries | Index Scan using contests_pkey on contests | Index Scan using user_teams_pkey on user_teams` |
| **W04** | WRITE | Recalculate user team points from player stats | 30.426 | 11.374 | 9.246 | **17.015** | 11.374 | `Seq Scan on user_teams | Index Only Scan using user_team_players_pkey on user_team_players | Bitmap Heap Scan on player_match_stats | Bitmap Index Scan on player_match_stats_pkey` |
| **W05** | WRITE | Credit winnings transaction to user wallet | 6.059 | 5.210 | 5.025 | **5.431** | 5.210 | `Seq Scan on wallet_transactions` |

---

## 3. Performance Diagnosis & Bottleneck Analysis

### A. The 5 Slowest Queries (Critical Bottlenecks)

1. **`R19` (2,090.058 ms — 2.09 seconds): Head-to-Head Player Selection Overlap**
   - **Root Cause:** Involves joining `user_team_players` (439,925 rows) with `players` and `teams`. In the absence of an index on `user_team_players.player_id` or composite indexes on match rosters, PostgreSQL falls back to sequential scans and costly nested loop/hash joins that examine hundreds of thousands of tuples.
   - **Target Optimization for CP3:** Create composite B-tree index on `user_team_players(player_id, user_team_id)`.

2. **`R06` (44.787 ms): Match-wide User Team Roster Extraction**
   - **Root Cause:** Sequential scan over all 39,975 rows in `user_teams` because foreign key column `user_teams.match_id` has no supporting index.
   - **Target Optimization for CP3:** Create index `idx_user_teams_match_id ON user_teams(match_id)`.

3. **`R02` (33.218 ms): User Team Lineup Resolution**
   - **Root Cause:** Scanning `user_teams` sequentially filtering on `match_id` before joining with player stats.
   - **Target Optimization for CP3:** Index on `user_teams(match_id, user_team_id)`.

4. **`R22` (24.203 ms): Monthly Wallet Transaction Aggregate Report**
   - **Root Cause:** Full sequential scan over 118,343 rows of `wallet_transactions` filtering and aggregating by `created_at` and `txn_type`.
   - **Target Optimization for CP3:** Composite index `idx_wallet_txn_type_created ON wallet_transactions(txn_type, created_at)`.

5. **`R15` (20.318 ms): Cross-Contest Participation Multi-entry Lookup**
   - **Root Cause:** Sequential scans on both `contest_entries` (42,746 rows) and `user_teams` (39,975 rows) to compute multi-entry users per match.
   - **Target Optimization for CP3:** Index on `contest_entries(contest_id)` and `contest_entries(user_team_id)`.

---

### B. The Fastest Queries (Index Scans / Cache Hits)

1. **`R23` (0.035 ms):** Single user lookup via phone number (`users_phone_key` B-tree index scan).
2. **`R03` (0.053 ms):** Team label check using candidate key `user_teams_user_id_match_id_team_label_key`.
3. **`R07` (0.100 ms):** Detailed player points lookup leveraging primary key index on `player_match_stats(match_id, player_id)`.

---

## 4. Key Architectural Takeaway (Why Baseline is Slow)

By default, PostgreSQL **only** auto-creates indexes for `PRIMARY KEY` and `UNIQUE` constraints. It does **not** create indexes for foreign keys:
- `wallet_transactions.user_id`
- `wallet_transactions.reference_entry_id`
- `user_teams.match_id`
- `user_team_players.player_id`
- `contest_entries.contest_id`
- `contest_entries.user_team_id`

Whenever a query joins on these foreign keys or filters by timestamps/status, PostgreSQL is forced to perform **Sequential Scans** across tables containing tens to hundreds of thousands of rows (`user_team_players`: 439,925 rows; `wallet_transactions`: 118,343 rows; `user_teams`: 39,975 rows; `contest_entries`: 42,746 rows).

In Checkpoint 3 (CP3), targeted secondary indexes in `sql/05_indexes.sql` will convert these sequential scans into B-tree Index Scans and Index-Only Scans, eliminating the bottlenecks.
