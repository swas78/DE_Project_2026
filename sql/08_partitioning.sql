-- =====================================================================
-- Phase 5: Range Partitioning Architecture (sql/08_partitioning.sql)
--
-- Author: Abhijeet Saini (Enrollment No: 2501010013, GitHub: abhijeet-s24)
-- Database: PostgreSQL 15+
-- Schema: dream11
--
-- Purpose:
--   1. Implements declarative RANGE partitioning on `wallet_transactions`
--      partitioned by timestamp (`created_at`).
--   2. Solves the PostgreSQL partitioned table constraint rule:
--      A UNIQUE/PK constraint on a partitioned table must contain all
--      partition key columns -> Composite Primary Key (txn_id, created_at).
--   3. Provides quarterly range partitions for 2025 and 2026 + default partition.
--   4. Demonstrates compile-time and run-time Partition Pruning with EXPLAIN.
-- =====================================================================

SET search_path TO dream11, public;

-- ---------------------------------------------------------------------
-- 1. ARCHITECTURAL JUSTIFICATION & PRIMARY KEY CONSTRAINT RULE
-- ---------------------------------------------------------------------
-- Table Chosen: `wallet_transactions`
-- Partition Strategy: RANGE by `created_at`
-- Why:
--   1. Volume: The wallet ledger is the fastest-growing table in the database
--      (118k rows in seed, 2.37M in large data, and 50M-100M+ at 100x scale).
--   2. Query Access Patterns: 95% of financial queries (R09, R10, R18, R20, R22,
--      W03, W05) filter by time (e.g., June 2026 deposit summaries, withdrawals
--      pending in the last 24h, or recent user transactions).
--   3. Lifecycle Management: Old partitions (e.g., 2025 financial quarters) can
--      be detached and archived instantly (`ALTER TABLE DETACH PARTITION`)
--      without incurring massive DELETE lock contention, WAL amplification,
--      or table bloat.
--
-- PostgreSQL Constraint Rule for Partitioned Tables:
--   In PostgreSQL, unique and primary key constraints on a partitioned table
--   MUST include all partition key columns. Because PostgreSQL enforces
--   uniqueness locally within each partition's individual index rather than
--   via a global cross-partition index, it cannot guarantee that `txn_id`
--   is unique across multiple partitions unless `created_at` is part of the key.
--   Therefore, the primary key must be defined as `(txn_id, created_at)`.
-- ---------------------------------------------------------------------

-- Create partitioned master table
CREATE TABLE IF NOT EXISTS dream11.wallet_transactions_partitioned (
    txn_id              INT NOT NULL,
    user_id             INT NOT NULL REFERENCES dream11.users(user_id) ON DELETE RESTRICT,
    txn_type            TEXT NOT NULL
                        CHECK (txn_type IN ('DEPOSIT', 'ENTRY_FEE', 'WINNINGS', 'REFUND', 'BONUS', 'WITHDRAWAL')),
    amount              NUMERIC(10,2) NOT NULL
                        CHECK (amount > 0),
    reference_entry_id  INT REFERENCES dream11.contest_entries(entry_id) ON DELETE RESTRICT,
    status              TEXT NOT NULL
                        CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED')),
    created_at          TIMESTAMPTZ NOT NULL,
    -- Composite primary key required by PostgreSQL declarative partitioning
    PRIMARY KEY (txn_id, created_at)
) PARTITION BY RANGE (created_at);

-- ---------------------------------------------------------------------
-- 2. QUARTERLY RANGE PARTITIONS (2025 - 2026)
-- ---------------------------------------------------------------------

-- 2025 Quarters
CREATE TABLE IF NOT EXISTS dream11.wallet_txns_2025_q1 PARTITION OF dream11.wallet_transactions_partitioned
    FOR VALUES FROM ('2025-01-01 00:00:00+05:30') TO ('2025-04-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS dream11.wallet_txns_2025_q2 PARTITION OF dream11.wallet_transactions_partitioned
    FOR VALUES FROM ('2025-04-01 00:00:00+05:30') TO ('2025-07-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS dream11.wallet_txns_2025_q3 PARTITION OF dream11.wallet_transactions_partitioned
    FOR VALUES FROM ('2025-07-01 00:00:00+05:30') TO ('2025-10-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS dream11.wallet_txns_2025_q4 PARTITION OF dream11.wallet_transactions_partitioned
    FOR VALUES FROM ('2025-10-01 00:00:00+05:30') TO ('2026-01-01 00:00:00+05:30');

-- 2026 Quarters
CREATE TABLE IF NOT EXISTS dream11.wallet_txns_2026_q1 PARTITION OF dream11.wallet_transactions_partitioned
    FOR VALUES FROM ('2026-01-01 00:00:00+05:30') TO ('2026-04-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS dream11.wallet_txns_2026_q2 PARTITION OF dream11.wallet_transactions_partitioned
    FOR VALUES FROM ('2026-04-01 00:00:00+05:30') TO ('2026-07-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS dream11.wallet_txns_2026_q3 PARTITION OF dream11.wallet_transactions_partitioned
    FOR VALUES FROM ('2026-07-01 00:00:00+05:30') TO ('2026-10-01 00:00:00+05:30');

CREATE TABLE IF NOT EXISTS dream11.wallet_txns_2026_q4 PARTITION OF dream11.wallet_transactions_partitioned
    FOR VALUES FROM ('2026-10-01 00:00:00+05:30') TO ('2027-01-01 00:00:00+05:30');

-- Default partition for boundary / future transactions
CREATE TABLE IF NOT EXISTS dream11.wallet_txns_default PARTITION OF dream11.wallet_transactions_partitioned
    DEFAULT;

-- ---------------------------------------------------------------------
-- 3. SECONDARY INDEXES ON PARTITIONED HIERARCHY
-- ---------------------------------------------------------------------
-- Indexes created on the parent partitioned table are automatically
-- propagated to all child partitions.

-- 1. Covering index for user running balance lookups (R09)
CREATE INDEX IF NOT EXISTS idx_part_wallet_user_status_created
ON dream11.wallet_transactions_partitioned USING btree (user_id, status, created_at, txn_id)
INCLUDE (txn_type, amount);

-- 2. Partial index for fast pending withdrawal processing (R10, W05)
CREATE INDEX IF NOT EXISTS idx_part_wallet_pending_withdrawals
ON dream11.wallet_transactions_partitioned USING btree (created_at)
WHERE txn_type = 'WITHDRAWAL' AND status = 'PENDING';

-- 3. Foreign key lookup for contest audit (R13, R25)
CREATE INDEX IF NOT EXISTS idx_part_wallet_reference_entry_id
ON dream11.wallet_transactions_partitioned USING btree (reference_entry_id)
WHERE reference_entry_id IS NOT NULL;

-- 4. Reverse chronological ordering for audit console (R22)
CREATE INDEX IF NOT EXISTS idx_part_wallet_created_at_desc
ON dream11.wallet_transactions_partitioned USING btree (created_at DESC, txn_id DESC);

-- ---------------------------------------------------------------------
-- 4. DATA MIGRATION QUERY
-- ---------------------------------------------------------------------
-- Populate partitioned table from the existing flat table
-- INSERT INTO dream11.wallet_transactions_partitioned
-- SELECT * FROM dream11.wallet_transactions;

-- ---------------------------------------------------------------------
-- 5. PARTITION PRUNING DEMONSTRATION & VERIFICATION
-- ---------------------------------------------------------------------
-- When querying a specific time window (e.g. June 2026 for R20):
-- PostgreSQL query planner inspects the range bounds and completely
-- prunes all 8 other partitions, reading ONLY `wallet_txns_2026_q2`.

-- Query to verify compile-time partition pruning:
-- EXPLAIN (ANALYZE, BUFFERS)
-- SELECT day, deposits, sum(deposits) OVER (ORDER BY day) AS running_total
-- FROM (
--     SELECT created_at::date AS day, sum(amount) AS deposits
--     FROM dream11.wallet_transactions_partitioned
--     WHERE txn_type = 'DEPOSIT' AND status = 'SUCCESS'
--       AND created_at >= '2026-06-01 00:00:00+05:30' AND created_at < '2026-07-01 00:00:00+05:30'
--     GROUP BY 1
-- ) d
-- ORDER BY day;
