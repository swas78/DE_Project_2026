# Phase 3: Baseline Timings

Team T0140 | Section D
Swastik Mishra (Group Lead), Tanishkka, Abhijeet Saini, Kunal Agrawal

## 1. Setup aur method

- Database: PostgreSQL 18.0 (Postgres.app), macOS (arm64), schema `dream11`
- Baseline sirf Phase 2 ke constraints ke saath chala (PRIMARY KEY aur UNIQUE ke automatic indexes). Koi extra index nahi bana tha.
- Command: `./benchmarks/run_benchmark.sh dream11_db baseline 3`
- Har query `EXPLAIN (ANALYZE, BUFFERS)` ke saath 3 baar chali, aur Average teeno Execution Time ka mean hai.
- Write queries (W01 se W05) `BEGIN; ... ROLLBACK;` ke andar chali, isliye data nahi badla.
- Raw plans: `benchmarks/results/baseline/R01.txt` se `W05.txt`, aur `summary.csv`.

Data size: teams 18, players 450, matches 212, users 50,000, player_match_stats 4,444, user_teams 39,975, user_team_players 439,925, contests 2,544, contest_entries 42,746, wallet_transactions 118,343.

## 2. Timing table

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Lobby: upcoming matches with the number of contests and total prize money on offer | READ | 0.308 | 0.285 | 0.251 | 0.281 |
| R02: Create team screen: player pool of match 207 with credits and % of teams that picked each player | READ | 41.874 | 29.403 | 28.376 | 33.218 |
| R03: "My teams": user 1006's teams for match 130 with captain and vice-captain names | READ | 0.063 | 0.046 | 0.050 | 0.053 |
| R04: Contest list for match 207: spots left, biggest prize first | READ | 0.210 | 0.231 | 0.244 | 0.228 |
| R05: Leaderboard: contest 2185 ranked by team points | READ | 0.650 | 0.422 | 0.411 | 0.494 |
| R06: Fair play: teams that break the rules (not exactly 11 players, over 100 credits, or more than 7 from one side) | READ | 45.182 | 44.795 | 44.383 | 44.787 |
| R07: Team preview: points of each player in user 1006's first team for match 130 (captain 2x, vice-captain 1.5x) | READ | 0.115 | 0.097 | 0.088 | 0.100 |
| R08: Match insights: most-picked captains for match 207 | READ | 1.305 | 1.104 | 1.116 | 1.175 |
| R09: Wallet: user 1006's transactions with a running balance | READ | 5.001 | 3.897 | 3.731 | 4.210 |
| R10: Payouts team: withdrawals pending for more than 24 hours (checked at 23:59 on 30 Jun 2026) | READ | 4.640 | 5.086 | 4.367 | 4.698 |
| R11: Compliance: users from states where paid fantasy contests are not allowed who joined paid contests in 2026 | READ | 12.592 | 12.745 | 12.263 | 12.533 |
| R12: Stats hub: top players by average fantasy points in IPL 2026 (at least 5 matches) | READ | 0.863 | 1.002 | 0.826 | 0.897 |
| R13: Finance audit: paid contest entries that have no entry-fee debit in the wallet | READ | 13.560 | 13.597 | 13.247 | 13.468 |
| R14: Product analytics: average fill rate per contest type for completed 2026 matches | READ | 10.140 | 9.666 | 9.540 | 9.782 |
| R15: Leaderboards: top 20 users by winnings in 2026 | READ | 19.785 | 20.297 | 20.871 | 20.318 |
| R16: Player search | READ | 0.211 | 0.199 | 0.193 | 0.201 |
| R17: Fair play: users with more than one team in the same contest | READ | 12.355 | 11.958 | 11.979 | 12.097 |
| R18: Tax compliance: users without verified KYC who have won more than ₹1,000 in total | READ | 8.830 | 9.000 | 9.017 | 8.949 |
| R19: Selection report: in how many teams was each IPL player picked (all time) | READ | 2091.662 | 2085.705 | 2092.807 | 2090.058 |
| R20: Finance: successful deposits per day and running total, June 2026 | READ | 5.268 | 4.523 | 4.522 | 4.771 |
| R21: Engagement: users' head-to-head win rate (at least 3 head-to-head contests) | READ | 5.288 | 5.125 | 5.491 | 5.301 |
| R22: Support console: all wallet transactions, newest first, page 2,001 (25 per page) | READ | 23.724 | 23.952 | 24.933 | 24.203 |
| R23: Login with mobile number | READ | 0.040 | 0.034 | 0.032 | 0.035 |
| R24: Player form: last 5 fantasy scores of every Chennai Super Kings player | READ | 0.464 | 0.455 | 1.152 | 0.690 |
| R25: Refund audit: paid entries in abandoned matches that were never refunded | READ | 9.294 | 9.018 | 8.775 | 9.029 |
| W01: Create team: user 1006 saves team T9 for match 207 | WRITE | 0.678 | 2.115 | 0.551 | 1.115 |
| W02: Join contest: user 1006's newest team for match 207 joins the mega contest of that match | WRITE | 0.550 | 0.334 | 0.336 | 0.407 |
| W03: Wallet: debit the entry fee for the most recent contest entry | WRITE | 0.517 | 0.803 | 0.450 | 0.590 |
| W04: Points engine: recompute total points of every team for match 183 | WRITE | 30.426 | 11.374 | 9.246 | 17.015 |
| W05: Payouts: approve all withdrawals pending for more than 24 hours | WRITE | 6.059 | 5.210 | 5.025 | 5.431 |
| **Total (sum of all 30)** | | 2351.654 | 2312.478 | 2314.273 | **2326.134** |

## 3. Scan type aur reason (har query ke liye)

| Query | Scan type (plan se) | Slow ya fast kyun |
|---|---|---|
| R01 | Seq Scan (matches, contests, teams) | Teeno tables chhote hain (212 matches, 2,544 contests), isliye seq scan bhi fast hai. |
| R02 | Seq Scan (user_teams, matches, players, teams) + Index Only Scan (user_team_players_pkey) | `user_teams.match_id` pe index nahi hai, to match 207 ki teams nikalne ke liye poori user_teams (39,975 rows) padhni padti hai, phir har team ke liye pick count ka lookup. |
| R03 | Index Scan (user_teams UNIQUE index, players_pkey) | `UNIQUE (user_id, match_id, team_label)` ka index seedha user aur match se rows nikal deta hai, sirf kuch rows aate hain. |
| R04 | Seq Scan (contests) + Index Scan (contest_entries UNIQUE index) | contests sirf 2,544 rows ki hai, aur entries ka count `UNIQUE (contest_id, user_team_id)` ke index se aata hai. |
| R05 | Index Only Scan (contest_entries UNIQUE index) + Index Scan (user_teams_pkey, users_pkey) | Ek contest ki entries UNIQUE index se milti hain, aur har entry ke liye primary key lookup hota hai. |
| R06 | Seq Scan (user_teams, players) + Index Only Scan (user_team_players_pkey) | `match_id` pe index nahi, to poori user_teams padhi jaati hai, aur LATERAL subquery har (team, player) row ke liye dobara ginti karti hai. |
| R07 | Index Scan (user_teams UNIQUE index, players_pkey, player_match_stats_pkey) + Index Only Scan (user_team_players_pkey) | Ek team ke sirf 11 players hain, aur har step ek index lookup hai. |
| R08 | Seq Scan (user_teams, players) | `match_id` pe index nahi, to user_teams seq scan hoti hai. Par sirf 39,975 rows hain, isliye 1 ms ke aas paas. |
| R09 | Seq Scan (wallet_transactions) | `wallet_transactions.user_id` pe index nahi, to ek user ke liye poori 118,343 rows padhni padti hain. |
| R10 | Seq Scan (wallet_transactions) | txn_type, status aur created_at pe koi index nahi, to poori table filter hoti hai jabki matching rows bahut kam hain. |
| R11 | Seq Scan (contest_entries, user_teams, users, contests) | Chaar tables ka join hai aur foreign key columns pe index nahi, to har table poori padhni padti hai. |
| R12 | Seq Scan (player_match_stats, matches, players, teams) | player_match_stats sirf 4,444 rows ki hai, isliye seq scan aur aggregate dono fast hain. |
| R13 | Seq Scan (contest_entries, wallet_transactions, contests) | `NOT IN (SELECT reference_entry_id ...)` poori wallet table ek baar padhta hai. Wallet mein 63,000 NULL reference hain, isliye `NOT IN` ka result khaali aana chahiye (ye wrong-result wali query hai). |
| R14 | Seq Scan (contests, matches) + Index Scan (contest_entries UNIQUE index) | `EXTRACT(YEAR FROM starts_at)` column pe function lagata hai, isliye index use nahi ho sakta, aur har contest ke liye entries ka lookup hota hai. |
| R15 | Seq Scan (contest_entries, user_teams, users) | `joined_at` pe index nahi, to saari 42,746 entries filter hoti hain, phir user_teams aur users se join. |
| R16 | Seq Scan (players, teams) | `ILIKE '%sharma%'` (shuruat mein wildcard) B-tree index se nahi chalta. Table sirf 450 rows ki hai, isliye fast hai. |
| R17 | Seq Scan (contest_entries, user_teams) | Saari entries ko contest aur user ke hisaab se group karna hai, isliye poori table padhni hi padti hai. |
| R18 | Seq Scan (wallet_transactions, users) | WINNINGS rows nikalne ke liye poori wallet table scan hoti hai (txn_type aur status pe index nahi), phir users se join. |
| R19 | Seq Scan (user_team_players, players, teams) | Sabse slow query. Correlated subquery har franchise player ke liye user_team_players (439,925 rows) dobara padhti hai, kyunki primary key `(user_team_id, player_id)` hai aur `player_id` pe alag index nahi. |
| R20 | Seq Scan (wallet_transactions) | `created_at::date` column pe cast hai, isliye index (agar hota) bhi use nahi hota. Poori wallet table padhi jaati hai. |
| R21 | Seq Scan (user_teams, contest_entries, contests) | Head-to-head contests ki entries nikalne ke liye foreign key index nahi, to teeno tables seq scan hoti hain. |
| R22 | Seq Scan (wallet_transactions) | `OFFSET 50000` ki wajah se pehle 50,025 rows sort karke skip karni padti hain, aur `created_at` pe index nahi. |
| R23 | Index Scan (users_phone_key) | `phone` UNIQUE hai, to PostgreSQL ne khud index banaya, seedha ek row mil jaati hai. |
| R24 | Seq Scan (player_match_stats, players, teams, matches) | Tables chhote hain (4,444 stats), isliye window function aur seq scan dono fast. |
| R25 | Seq Scan (wallet_transactions, contest_entries, user_teams, matches, contests) | `NOT EXISTS` ke liye wallet ko `reference_entry_id` pe dekhna hai, par us column pe index nahi, to seq scan. |
| W01 | Seq Scan (matches) | Sirf ek row insert hoti hai. 212 rows ki matches table se captain aur vice-captain nikalte hain. Run 2 ka 2.115 ms ek outlier hai. |
| W02 | Index Scan (user_teams_pkey) + Seq Scan (contests) | Ek entry insert hoti hai. contests chhoti table hai, aur max(user_team_id) primary key index se milta hai. |
| W03 | Index Only Scan (contest_entries_pkey) + Index Scan (contest_entries_pkey, contests_pkey, user_teams_pkey) | Saare lookups primary key se hain, aur sirf ek row insert hoti hai. |
| W04 | Seq Scan (user_teams) + Index Only Scan (user_team_players_pkey) + Bitmap Heap Scan (player_match_stats) | Match 183 ki saari teams ke total_points update hote hain. `match_id` pe index nahi, to user_teams seq scan hoti hai. Run 1 (30 ms) pehli baar ka cold cache hai. |
| W05 | Seq Scan (wallet_transactions) | Pending withdrawals dhoondhne ke liye poori wallet table padhi jaati hai, aur matching rows update hoti hain. |

## 4. Sabse slow aur sabse fast

**Sabse slow: R19 (2090.058 ms).** Baaki saari queries 45 ms se kam hain, aur ye akeli lagbhag 2 second leti hai. Correlated subquery har franchise player ke liye `user_team_players` ko dobara padhti hai. Primary key `(user_team_id, player_id)` hai, to `player_id` se dhoondhne ke liye index kaam nahi aata.

**Baaki slow queries:** R06 (44.787 ms), R02 (33.218 ms), R22 (24.203 ms), R15 (20.318 ms).

**Sabse fast:** R23 (0.035 ms), R03 (0.053 ms), R07 (0.100 ms). Teeno Phase 2 ke UNIQUE constraints ke automatic indexes use karti hain.

## 5. Baseline slow kyun hai

PostgreSQL sirf PRIMARY KEY aur UNIQUE ke liye index banata hai. Foreign key columns pe index nahi banta. Isliye in columns pe filter ya join karne wali queries poori table padhti hain:

- `wallet_transactions.user_id` aur `reference_entry_id`
- `user_teams.match_id`
- `user_team_players.player_id`
- `contest_entries.user_team_id`
- `contests.match_id`

Ye sab Phase 4 mein indexes aur query rewrites se theek honge.
