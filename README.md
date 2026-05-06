# market-sentiment-sql

SQL analytics project built around market intelligence data — the same domain as [Viglore](https://viglore.com).

Tracks stock prices, VADER-style sentiment scores, news coverage, and tech city rankings across 22 companies and 25 cities over 60 trading days (~2,600 rows of time series data). Data is synthetic and generated via recursive CTEs for demonstration purposes.

---

## Business Questions Answered

| # | Question | Techniques Used |
|---|----------|----------------|
| 1 | Which companies have the strongest sentiment right now? | `GROUP BY`, `RANK()` window function |
| 2 | Which sectors is the market most bullish or bearish on? | Multi-table `JOIN`, `RANK()` |
| 3 | Does sentiment predict next-day price movement? | CTE, date-offset `JOIN`, `CASE` |
| 4 | Which companies show diverging signals (sentiment up, price down)? | Multi-CTE, conditional `WHERE` |
| 5 | Rolling 7-day sentiment trend for most-covered companies | `AVG() OVER (ROWS BETWEEN...)` |
| 6 | Month-over-month sentiment shifts | `LAG()`, `DATE_FORMAT`, `CASE` tiers |
| 7 | Which stocks are the most volatile? | `STDDEV()`, `RANK()` |
| 8 | Which news sources skew most positive or negative? | `GROUP BY`, `STDDEV()`, `RANK()` |
| 9 | Sentiment quartile ranking across all companies | `NTILE(4)`, `CASE` |
| 10 | Top tech cities by composite weighted score | Weighted `OVER()`, `RANK()` |
| 11 | Best and worst single-day price moves | `UNION ALL`, `ORDER BY` |
| 12 | Weekly performance with buy/sell signal classification | CTE, multi-condition `CASE` |

---

## Schema

**companies** — 22 publicly traded companies with sector, industry, market cap category, and base price used to drive data generation

**stock_prices** — daily OHLCV data per company: open, close, high, low, volume, and percent price change. Unique constraint on `(company_id, price_date)`.

**sentiment_scores** — daily VADER-style sentiment score (-1.0 to 1.0) per company, with source (`news`, `social`, `combined`) and article count. CHECK constraint enforces score range.

**news_articles** — individual news headlines per company with publication timestamp, outlet name, and sentiment score. Indexed on company + date and source for fast filtering.

**cities** — 25 US tech hub cities with rank, tech job count, average salary, startup count, and year-over-year growth rate.

```
companies ──< stock_prices
companies ──< sentiment_scores
companies ──< news_articles
cities
```

---

## Sample Output

**Query 1 — Top companies by sentiment (last 30 days)**
```
ticker  name                      sector      avg_sentiment  sentiment_rank
JPM     JPMorgan Chase & Co.      Finance     0.2717         1
PFE     Pfizer Inc.               Healthcare  0.2628         2
BAC     Bank of America Corp.     Finance     0.2498         3
XOM     Exxon Mobil Corporation   Energy      0.2409         4
GOOGL   Alphabet Inc.             Technology  0.2220         5
```

**Query 3 — Does sentiment predict next-day price?**
```
ticker  avg_sentiment  avg_next_day_change_pct  signal_strength
JPM     0.2717         0.052                    Predictive — Positive
XOM     0.2322         0.105                    Predictive — Positive
PFE     0.2453         -0.405                   No Clear Signal
AAPL    0.2178         0.008                    Predictive — Positive
```

**Query 4 — Divergence signal (sentiment up, price down)**
```
ticker  name          sector  sentiment_last_7d  sentiment_last_30d  price_change_7d
WMT     Walmart Inc.  Retail  0.2251             0.2190              -0.287
```

**Query 10 — Top tech cities by composite score**
```
name           state       tech_rank  composite_score  composite_rank
New York City  New York    3          72.45            1
San Francisco  California  1          71.83            2
Seattle        Washington  2          65.21            3
Austin         Texas       4          58.94            4
Miami          Florida     11         52.17            5
```

---

## Files

| File | Description |
|------|-------------|
| `01_schema.sql` | 5 tables with foreign keys, CHECK constraints, and indexes |
| `02_seed.sql` | 22 companies, 25 cities, 40 news headlines, 2600+ rows via recursive CTE |
| `03_analysis.sql` | 12 business queries |

---

## SQL Techniques Demonstrated

- Window functions: `RANK()`, `NTILE()`, `LAG()`, `AVG() OVER()` with rolling frame
- Common Table Expressions (CTEs), including multi-CTE chains
- Correlated subqueries
- `UNION ALL`
- `STDDEV()` for volatility analysis
- Date arithmetic with `DATE_SUB`, `DATE_ADD`, `DATE_FORMAT`, `DATEDIFF`
- Conditional aggregation with `CASE` inside `AVG()`
- Composite scoring with normalized window calculations
- Recursive CTE for time series generation

---

## Stack

MySQL 8.0+

---

## Related

Built to complement [Viglore](https://viglore.com) — a live market intelligence platform that tracks sentiment, stock data, and city rankings in real time.
