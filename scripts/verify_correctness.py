#!/usr/bin/env python3
"""
Verification script for Phase 4: Query Correctness and Dataset Integrity.
Runs EXCEPT queries between original baseline queries and rewritten queries
to verify that the returned datasets are 100% identical.
"""

import subprocess
import sys

REWRITES_TO_TEST = [
    ("R02", "Player pool selection percentage (match 207)", """
        SELECT p.player_id, p.full_name, t.short_name, p.role, p.credits,
               round(100.0 * count(utp.user_team_id) / NULLIF((SELECT count(*) FROM user_teams WHERE match_id = 207), 0), 1) AS selected_pct
        FROM matches m
        JOIN players p ON p.team_id IN (m.home_team_id, m.away_team_id) AND p.is_active
        JOIN teams t   ON t.team_id = p.team_id
        LEFT JOIN user_teams ut         ON ut.match_id = m.match_id
        LEFT JOIN user_team_players utp ON utp.user_team_id = ut.user_team_id AND utp.player_id = p.player_id
        WHERE m.match_id = 207
        GROUP BY p.player_id, p.full_name, t.short_name, p.role, p.credits
        ORDER BY selected_pct DESC;
    """, """
        WITH match_info AS (
            SELECT count(*) AS total_teams
            FROM user_teams
            WHERE match_id = 207
        )
        SELECT p.player_id, p.full_name, t.short_name, p.role, p.credits,
               round(100.0 * count(utp.user_team_id) / NULLIF((SELECT total_teams FROM match_info), 0), 1) AS selected_pct
        FROM matches m
        JOIN players p ON p.team_id IN (m.home_team_id, m.away_team_id) AND p.is_active
        JOIN teams t   ON t.team_id = p.team_id
        LEFT JOIN user_teams ut         ON ut.match_id = m.match_id
        LEFT JOIN user_team_players utp ON utp.user_team_id = ut.user_team_id AND utp.player_id = p.player_id
        WHERE m.match_id = 207
        GROUP BY p.player_id, p.full_name, t.short_name, p.role, p.credits
        ORDER BY selected_pct DESC;
    """),
    ("R06", "Fair play rule violations (match 183)", """
        SELECT ut.user_team_id, count(*) AS players, sum(p.credits) AS credits_used, max(side.cnt) AS max_from_one_team
        FROM user_teams ut
        JOIN user_team_players utp ON utp.user_team_id = ut.user_team_id
        JOIN players p             ON p.player_id = utp.player_id
        CROSS JOIN LATERAL (SELECT count(*) AS cnt FROM user_team_players x JOIN players px ON px.player_id = x.player_id
                            WHERE x.user_team_id = ut.user_team_id AND px.team_id = p.team_id) side
        WHERE ut.match_id = 183
        GROUP BY ut.user_team_id
        HAVING count(*) <> 11 OR sum(p.credits) > 100 OR max(side.cnt) > 7;
    """, """
        WITH team_sides AS (
            SELECT ut.user_team_id,
                   p.team_id,
                   count(*) AS side_cnt,
                   sum(p.credits) AS side_credits
            FROM user_teams ut
            JOIN user_team_players utp ON utp.user_team_id = ut.user_team_id
            JOIN players p ON p.player_id = utp.player_id
            WHERE ut.match_id = 183
            GROUP BY ut.user_team_id, p.team_id
        )
        SELECT user_team_id,
               sum(side_cnt) AS players,
               sum(side_credits) AS credits_used,
               max(side_cnt) AS max_from_one_team
        FROM team_sides
        GROUP BY user_team_id
        HAVING sum(side_cnt) <> 11 OR sum(side_credits) > 100 OR max(side_cnt) > 7;
    """),
    ("R14", "Product analytics fill rate (sargable year filter)", """
        SELECT c.contest_type, count(DISTINCT c.contest_id) AS contests,
               round(100.0 * count(ce.entry_id) / sum(DISTINCT c.total_spots), 1) AS rough_fill_pct
        FROM contests c
        JOIN matches m ON m.match_id = c.match_id AND m.status = 'COMPLETED'
        LEFT JOIN contest_entries ce ON ce.contest_id = c.contest_id
        WHERE EXTRACT(YEAR FROM m.starts_at) = 2026
        GROUP BY c.contest_type
        ORDER BY contests DESC;
    """, """
        SELECT c.contest_type, count(DISTINCT c.contest_id) AS contests,
               round(100.0 * count(ce.entry_id) / sum(DISTINCT c.total_spots), 1) AS rough_fill_pct
        FROM contests c
        JOIN matches m ON m.match_id = c.match_id AND m.status = 'COMPLETED'
        LEFT JOIN contest_entries ce ON ce.contest_id = c.contest_id
        WHERE m.starts_at >= '2026-01-01 00:00:00+05:30' AND m.starts_at < '2027-01-01 00:00:00+05:30'
        GROUP BY c.contest_type
        ORDER BY contests DESC;
    """),
    ("R19", "IPL player selection count (correlated subquery to pre-aggregation)", """
        SELECT p.player_id, p.full_name,
               (SELECT count(*) FROM user_team_players utp WHERE utp.player_id = p.player_id) AS times_picked
        FROM players p
        JOIN teams t ON t.team_id = p.team_id AND t.team_type = 'FRANCHISE'
        ORDER BY times_picked DESC;
    """, """
        SELECT p.player_id, p.full_name, coalesce(agg.times_picked, 0) AS times_picked
        FROM players p
        JOIN teams t ON t.team_id = p.team_id AND t.team_type = 'FRANCHISE'
        LEFT JOIN (
            SELECT player_id, count(*) AS times_picked
            FROM user_team_players
            GROUP BY player_id
        ) agg ON agg.player_id = p.player_id
        ORDER BY times_picked DESC;
    """),
    ("R20", "Daily successful deposits (sargable date range)", """
        SELECT day, deposits, sum(deposits) OVER (ORDER BY day) AS running_total
        FROM (
            SELECT created_at::date AS day, sum(amount) AS deposits
            FROM wallet_transactions
            WHERE txn_type = 'DEPOSIT' AND status = 'SUCCESS'
              AND created_at::date BETWEEN '2026-06-01' AND '2026-06-30'
            GROUP BY 1
        ) d
        ORDER BY day;
    """, """
        SELECT day, deposits, sum(deposits) OVER (ORDER BY day) AS running_total
        FROM (
            SELECT created_at::date AS day, sum(amount) AS deposits
            FROM wallet_transactions
            WHERE txn_type = 'DEPOSIT' AND status = 'SUCCESS'
              AND created_at >= '2026-06-01 00:00:00+05:30' AND created_at < '2026-07-01 00:00:00+05:30'
            GROUP BY 1
        ) d
        ORDER BY day;
    """)
]

def run_query(sql):
    cmd = ["psql", "-d", "dream11_db", "-X", "-A", "-t", "-c", f"SET search_path TO dream11; {sql}"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Error running query: {res.stderr}", file=sys.stderr)
        return None
    lines = [line.strip() for line in res.stdout.strip().splitlines() if line.strip() and line.strip() != "SET"]
    return lines[-1] if lines else "0"

def main():
    print("=" * 70)
    print(" Phase 4 Query Correctness Verification Harness (EXCEPT Testing)")
    print("=" * 70)
    all_passed = True
    for qid, desc, orig_sql, opt_sql in REWRITES_TO_TEST:
        orig_clean = orig_sql.strip().rstrip(';')
        opt_clean = opt_sql.strip().rstrip(';')

        # Check (Orig EXCEPT ALL Opt) UNION ALL (Opt EXCEPT ALL Orig)
        except_sql = f"""
            SELECT count(*) FROM (
                ({orig_clean})
                EXCEPT ALL
                ({opt_clean})
            ) diff1;
        """
        diff1 = run_query(except_sql)

        reverse_sql = f"""
            SELECT count(*) FROM (
                ({opt_clean})
                EXCEPT ALL
                ({orig_clean})
            ) diff2;
        """
        diff2 = run_query(reverse_sql)

        if diff1 == "0" and diff2 == "0":
            print(f"[{qid}] PASS: {desc} (Differences: 0)")
        else:
            print(f"[{qid}] FAIL: {desc} (Diff orig->opt: {diff1}, opt->orig: {diff2})")
            all_passed = False

    print("=" * 70)
    if all_passed:
        print("ALL REWRITTEN QUERIES PROVEN 100% IDENTICAL TO BASELINE!")
    else:
        print("ONE OR MORE QUERIES RETURNED DIFFERENT RESULTS.")
        sys.exit(1)

if __name__ == "__main__":
    main()
