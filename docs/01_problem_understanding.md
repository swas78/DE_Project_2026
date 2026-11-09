# Phase 1: Problem Understanding

Team T0140 | Section D
Swastik Mishra (Group Lead), Tanishkka, Abhijeet Saini, Kunal Agrawal

## Project overview

Dream11 is a fantasy cricket platform. For every real match (IPL and international T20s), users build fantasy teams of exactly 11 players from the two real teams within 100 credits, picking a captain (2× points) and vice-captain (1.5×). After the match, each player's real performance is converted into fantasy points. Users join contests (mega contests, small contests, head-to-heads, private leagues with invite codes) by paying an entry fee from their wallet; winners get prize money. The wallet records deposits, entry fees, winnings, refunds (for abandoned matches), bonuses and withdrawals. You have joined the Dream11 data team.

The current database was put together quickly by an earlier team. It has no documented schema (only data exports survive), and the product teams are complaining.

## Problems

| # | What the Business needs | Who is affected | Queries | Type |
|---|---|---|---|---|
| P1 | Match lock hone se pehle user lobby, player list aur contest list dekhta hai. Ye turant khulna chahiye, nahi to user app chhod dega. | User, contest/product team | R01, R02, R04, R08 | Customer-facing / real-time |
| P2 | Match chalu hone pe user baar baar apni teams, preview, leaderboard aur wallet history dekhta hai. Ye screens slow nahi honi chahiye. | User | R03, R05, R07, R09 | Customer-facing / real-time |
| P3 | Team save karna, contest join karna aur wallet se paisa katna kabhi atakna nahi chahiye. | User, contest engine | W01, W02, W03 | Customer-facing / real-time |
| P4 | Fair-play team ko jaldi pata chale ki kaunsi team ne rules toda (11 players nahi, 100 credits se zyada, ek side se 7 se zyada) aur kisne ek contest mein multiple teams daali. | Fair-play team | R06, R17 | Reporting / analytics |
| P5 | Finance audit mein "paid entry hai par wallet se paisa nahi kata" wale cases aane chahiye, par result hamesha khaali aa raha hai. Yahan sahi answer chahiye. | Finance & payouts | R13 | Reporting / analytics |
| P6 | 24 ghante se pending withdrawals, banned states ke users ka paid contest khelna, KYC/TDS check aur missed refunds jaldi nikalne chahiye. | Finance & payouts, compliance, support | R10, R11, R18, R25, W05 | Reporting / analytics |
| P7 | Match ke baad points engine ko saari teams ke points calculate karne hain, aur stats hub (player average, form, kitni teams mein pick hua) time out nahi hona chahiye. | Points engine, stats team | R12, R19, R24, W04 | Reporting / analytics |
| P8 | Fill rate, top winners, head-to-head, daily deposits jaisi reports slow hain aur data badhne pe aur slow hongi. Player search, support console aur login bhi isi mein aate hain. | Product team, finance, support | R14, R15, R16, R20, R21, R22, R23 | Reporting / analytics |

P1, P2, P3 user ke saamne live chalte hain, isliye inka target sabse tight hoga. P4 se P8 internal teams ke liye hain, inme thoda zyada time chal jayega.

## Assumptions

1. Match start hone ke baad nayi team nahi ban sakti aur purani team edit nahi hoti.
2. Wallet balance sirf SUCCESS transactions se banta hai. Deposit, winnings, bonus aur refund se paisa badhta hai, entry fee aur withdrawal se ghatta hai.
3. Match ke time zyada kaam padhne ka hota hai (lobby, leaderboard, wallet), likhne ka kam (team save, contest join).
4. Entry fee, refund aur withdrawal jaise paise ke kaam live aur exact hone chahiye. Reports mein thoda purana data chal sakta hai.
5. Data 20 guna badhega, isliye jo bhi solution banayenge wo bade data pe bhi chalna chahiye.
6. Data ko badalna ya delete karna nahi hai, sirf database ko tez karna hai.
