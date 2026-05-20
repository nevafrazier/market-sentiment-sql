# market-sentiment-sql

SQL analytics project built around market intelligence data — same domain as [Viglore](https://viglore.com).

Tracks stock prices, VADER-style sentiment scores, and news coverage across 22 companies and 25 cities over 60 trading days (~2,600 rows). Data is synthetic, generated via recursive CTEs.

---

## Business Questions Answered

| # | Question | Techniques |
|---|----------|-----------|
| 1 | Which companies have the strongest sentiment right now? | `GROUP BY`, `RANK()` |
| 2 | Which sectors is the market most bullish or bearish on? | multi-table `JOIN`, `RANK()` |
| 3 | Does sentiment predict next-day price movement? | CTE, date-offset `JOIN`, `CASE` |
| 4 | Which companies show diverging signals (sentiment up, price down)? | multi-CTE, conditional `WHERE` |
| 5 | Rolling 7-day sentiment trend for most-covered companies | `AVG() OVER (ROWS BETWEEN...)` |
| 6 | Month-over-month sentiment shifts | `LAG()`, `DATE_FORMAT` |
| 7 | Which stocks are the most volatile? | `STDDEV()`, `RANK()` |
| 8 | Which news sources skew most positive or negative? | `GROUP BY`, `STDDEV()` |
| 9 | Sentiment quartile ranking across all companies | `NTILE(4)`, `CASE` |
| 10 | Top tech cities by composite weighted score | weighted `OVER()`, `RANK()` |
| 11 | Best and worst single-day price moves | `UNION ALL` |
| 12 | Weekly performance with buy/sell signal classification | CTE, multi-condition `CASE` |

---

## Schema

**companies** — 22 publicly traded companies with sector, industry, market cap category, and base price used to drive data generation

**stock_prices** — daily OHLCV per company with percent price change. Unique constraint on `(company_id, price_date)`.

**sentiment_scores** — daily VADER-style score (-1.0 to 1.0) per company, source, and article count. CHECK constraint enforces score range.

**news_articles** — individual headlines with publication timestamp, outlet, and sentiment score.

**cities** — 25 US tech hubs with rank, job count, avg salary, startups, and YoY growth.

```
companies ──< stock_prices
companies ──< sentiment_scores
companies ──< news_articles
cities
```

---

## Sample Output

**Query 1 — top companies by sentiment (last 30 days)**
```
ticker  name                      sector      avg_sentiment  sentiment_rank
JPM     JPMorgan Chase & Co.      Finance     0.2717         1
PFE     Pfizer Inc.               Healthcare  0.2628         2
BAC     Bank of America Corp.     Finance     0.2498         3
XOM     Exxon Mobil Corporation   Energy      0.2409         4
GOOGL   Alphabet Inc.             Technology  0.2220         5
```

**Query 3 — does sentiment predict next-day price?**
```
ticker  avg_sentiment  avg_next_day_change_pct  signal_strength
JPM     0.2717         0.052                    Predictive — Positive
XOM     0.2322         0.105                    Predictive — Positive
PFE     0.2453         -0.405                   No Clear Signal
AAPL    0.2178         0.008                    Predictive — Positive
```

**Query 4 — divergence signal (sentiment up, price down)**
```
ticker  name          sector  sentiment_last_7d  sentiment_last_30d  price_change_7d
WMT     Walmart Inc.  Retail  0.2251             0.2190              -0.287
```

---

## Key Findings

- Finance ranked #1 in sentiment (avg 0.2260) across the 60-day window, ahead of Healthcare (0.1932) and well above Technology (0.1586) — despite Tech having twice as many companies tracked.
- 16 out of 22 companies showed sentiment that was predictive of next-day price direction. PFE and WMT were the main exceptions — both had strong sentiment scores but negative price follow-through, which lines up with their high volatility rankings.
- GM was the most volatile stock in the dataset (std dev 1.3536). PFE and WMT followed at 1.0349 and 0.9383 — the same names that broke the sentiment-prediction pattern, which makes sense.
- WMT was the only divergence signal — sentiment ticking up week over week while price was still falling. Price tends to lag sentiment, so this would be worth watching.

---

## Query Performance

Query 3 is the most expensive — it joins `sentiment_scores` to `stock_prices` on a date offset across 1,430 rows each. `EXPLAIN` output:

```
-> Sort: avg_sentiment DESC
    -> Aggregate using temporary table
        -> Nested loop inner join  (cost=728 rows=1430)
            -> Nested loop inner join  (cost=228 rows=1430)
                -> Covering index scan on companies using uq_companies_ticker  (cost=2.45 rows=22)
                -> Index lookup on sentiment_scores using uq_sentiment_date
                   (company_id = c.id), with index condition: source = 'combined'  (cost=4.05 rows=65)
            -> Single-row index lookup on stock_prices using uq_stock_date
               (company_id = c.id, price_date = score_date + interval 1 day)  (cost=0.25 rows=1)
```

The date-offset join resolves to a single-row index lookup on `uq_stock_date (company_id, price_date)` — no full table scan. Would stay fast at scale as long as that composite index is in place.

---

## Files

| File | Description |
|------|-------------|
| `01_schema.sql` | 5 tables with foreign keys, CHECK constraints, and indexes |
| `02_seed.sql` | 22 companies, 25 cities, 40 news headlines, 2600+ rows via recursive CTE |
| `03_analysis.sql` | 12 analysis queries |

## Stack

MySQL 8.0+

## Related

Built to complement [Viglore](https://viglore.com) — a live market intelligence platform that tracks sentiment, stock data, and city rankings in real time.
