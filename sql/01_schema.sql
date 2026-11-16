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