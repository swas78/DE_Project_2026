-- ============================================================
-- Dream11 schema (PostgreSQL 15+): sirf constraints, koi extra index nahi
-- ============================================================

-- ---------- PART A: file ke shuru mein (sirf ek baar) ----------
CREATE SCHEMA dream11;
SET search_path TO dream11;

-- 1) teams
CREATE TABLE teams (
    team_id    INT PRIMARY KEY,
    team_name  TEXT NOT NULL UNIQUE,
    short_name VARCHAR(5) NOT NULL UNIQUE
               CHECK (short_name ~ '^[A-Z]{2,5}$'),
    team_type  TEXT NOT NULL
               CHECK (team_type IN ('FRANCHISE', 'INTERNATIONAL'))
);

-- 2) players
CREATE TABLE players (
    player_id INT PRIMARY KEY,
    full_name TEXT NOT NULL,
    team_id   INT NOT NULL REFERENCES teams(team_id) ON DELETE RESTRICT,
    role      TEXT NOT NULL
              CHECK (role IN ('WK', 'BAT', 'AR', 'BOWL')),
    credits   NUMERIC(3,1) NOT NULL
              CHECK (credits BETWEEN 5 AND 12),   -- data mein 6.5 se 10.5
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- 3) matches
CREATE TABLE matches (
    match_id     INT PRIMARY KEY,
    tournament   TEXT NOT NULL,
    home_team_id INT NOT NULL REFERENCES teams(team_id) ON DELETE RESTRICT,
    away_team_id INT NOT NULL REFERENCES teams(team_id) ON DELETE RESTRICT,
    venue        TEXT NOT NULL,
    starts_at    TIMESTAMPTZ NOT NULL,
    status       TEXT NOT NULL
                 CHECK (status IN ('UPCOMING', 'LIVE', 'COMPLETED', 'ABANDONED')),
    CHECK (home_team_id <> away_team_id)
);

-- 4) users
CREATE TABLE users (
    user_id    INT PRIMARY KEY,
    username   TEXT NOT NULL UNIQUE
               CHECK (username ~ '^[A-Za-z0-9_]+$'),
    phone      VARCHAR(10) NOT NULL UNIQUE
               CHECK (phone ~ '^[0-9]{10}$'),
    email      TEXT UNIQUE
               CHECK (email LIKE '%@%'),   -- 19935 users ka email khaali hai, isliye NULL allowed
    state_code CHAR(2) NOT NULL
               CHECK (state_code ~ '^[A-Z]{2}$'),
    kyc_status TEXT NOT NULL
               CHECK (kyc_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    created_at TIMESTAMPTZ NOT NULL
);

-- ---------- PART B: player_match_stats, user_teams, user_team_players, contests, contest_entries ----------

-- 6) player_match_stats
CREATE TABLE player_match_stats (
    match_id       INT NOT NULL REFERENCES matches(match_id) ON DELETE RESTRICT,
    player_id      INT NOT NULL REFERENCES players(player_id) ON DELETE RESTRICT,
    runs           SMALLINT NOT NULL CHECK (runs >= 0),
    balls_faced    SMALLINT NOT NULL CHECK (balls_faced >= 0),
    fours          SMALLINT NOT NULL CHECK (fours >= 0),
    sixes          SMALLINT NOT NULL CHECK (sixes >= 0),
    wickets        SMALLINT NOT NULL CHECK (wickets BETWEEN 0 AND 10),
    catches        SMALLINT NOT NULL CHECK (catches >= 0),
    fantasy_points NUMERIC(6,1) NOT NULL,
    PRIMARY KEY (match_id, player_id)
);

-- 7) user_teams
CREATE TABLE user_teams (
    user_team_id    INT PRIMARY KEY,
    user_id         INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    match_id        INT NOT NULL REFERENCES matches(match_id) ON DELETE RESTRICT,
    team_label      VARCHAR(3) NOT NULL CHECK (team_label ~ '^T[0-9]{1,2}$'),
    captain_id      INT NOT NULL REFERENCES players(player_id) ON DELETE RESTRICT,
    vice_captain_id INT NOT NULL REFERENCES players(player_id) ON DELETE RESTRICT,
    total_points    NUMERIC(7,1),
    created_at      TIMESTAMPTZ NOT NULL,
    UNIQUE (user_id, match_id, team_label),
    CHECK (captain_id <> vice_captain_id)
);

-- 8) user_team_players
CREATE TABLE user_team_players (
    user_team_id INT NOT NULL REFERENCES user_teams(user_team_id) ON DELETE CASCADE,
    player_id    INT NOT NULL REFERENCES players(player_id) ON DELETE RESTRICT,
    PRIMARY KEY (user_team_id, player_id)
);

-- 9) contests
CREATE TABLE contests (
    contest_id    INT PRIMARY KEY,
    match_id      INT NOT NULL REFERENCES matches(match_id) ON DELETE RESTRICT,
    contest_name  TEXT NOT NULL,
    contest_type  TEXT NOT NULL
                  CHECK (contest_type IN ('MEGA', 'SMALL', 'HEAD_TO_HEAD', 'PRIVATE')),
    entry_fee     NUMERIC(8,2) NOT NULL CHECK (entry_fee >= 0),
    total_spots   INT NOT NULL CHECK (total_spots > 0),
    prize_pool    NUMERIC(12,2) NOT NULL CHECK (prize_pool >= 0),
    is_guaranteed BOOLEAN NOT NULL,
    invite_code   VARCHAR(20) UNIQUE,
    CHECK (contest_type <> 'HEAD_TO_HEAD' OR total_spots = 2),
    CHECK ((contest_type = 'PRIVATE') = (invite_code IS NOT NULL))
);

-- 10) contest_entries
CREATE TABLE contest_entries (
    entry_id     INT PRIMARY KEY,
    contest_id   INT NOT NULL REFERENCES contests(contest_id) ON DELETE RESTRICT,
    user_team_id INT NOT NULL REFERENCES user_teams(user_team_id) ON DELETE RESTRICT,
    joined_at    TIMESTAMPTZ NOT NULL,
    final_rank   INT CHECK (final_rank > 0),
    winnings     NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (winnings >= 0),
    UNIQUE (contest_id, user_team_id)   -- W02 ka ON CONFLICT isi pe chalta hai
);

-- ---------- PART C: sabse last mein (contest_entries ke baad) ----------
-- 5) wallet_transactions
CREATE TABLE wallet_transactions (
    txn_id             BIGINT PRIMARY KEY,
    user_id            INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    txn_type           TEXT NOT NULL
                       CHECK (txn_type IN ('DEPOSIT', 'ENTRY_FEE', 'WINNINGS',
                                           'REFUND', 'BONUS', 'WITHDRAWAL')),
    amount             NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    reference_entry_id INT REFERENCES contest_entries(entry_id) ON DELETE RESTRICT,
    status             TEXT NOT NULL
                       CHECK (status IN ('SUCCESS', 'PENDING', 'FAILED')),
    created_at         TIMESTAMPTZ NOT NULL
    -- Load ke baad dekho kaunsi txn_type ko reference_entry_id chahiye,
    -- phir yahan ek CHECK jodo (jaise ENTRY_FEE aur REFUND ke liye NOT NULL).
);