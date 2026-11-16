SET search_path TO dream11;

\copy teams FROM 'seed_data/teams.csv' WITH (FORMAT csv, HEADER true)
\copy players FROM 'seed_data/players.csv' WITH (FORMAT csv, HEADER true)
\copy matches FROM 'seed_data/matches.csv' WITH (FORMAT csv, HEADER true)
\copy users FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true)
\copy player_match_stats FROM 'seed_data/player_match_stats.csv' WITH (FORMAT csv, HEADER true)
\copy user_teams FROM 'seed_data/user_teams.csv' WITH (FORMAT csv, HEADER true)
\copy user_team_players FROM 'seed_data/user_team_players.csv' WITH (FORMAT csv, HEADER true)
\copy contests FROM 'seed_data/contests.csv' WITH (FORMAT csv, HEADER true)
\copy contest_entries FROM 'seed_data/contest_entries.csv' WITH (FORMAT csv, HEADER true)
\copy wallet_transactions FROM 'seed_data/wallet_transactions.csv' WITH (FORMAT csv, HEADER true)

ANALYZE;
