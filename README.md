# market-sentiment-sql

SQL analytics project built around market intelligence data — the same domain as [Viglore](https://viglore.com).

Tracks stock prices, VADER-style sentiment scores, news coverage, and tech city rankings across 22 companies and 25 cities over 60 trading days (~2,600 rows of time series data).

## Business Questions Answered

| # | Question |
|---|----------|
| 1 | Which companies have the strongest sentiment right now? |
| 2 | Which sectors is the market most bullish or bearish on? |
| 3 | Does sentiment actually predict next-day price movement? |
| 4 | Which companies show diverging signals (sentiment up, price down)? |
| 5 | Rolling 7-day sentiment trend for the most-covered companies |
| 6 | Month-over-month sentiment shifts by company |
| 7 | Which stocks are the most volatile? |
| 8 | Which news sources write most positively or negatively? |
| 9 | Sentiment quartile ranking across all tracked companies |
| 10 | Top tech cities ranked by composite score (jobs, salary, growth) |
| 11 | Best and worst single-day price moves in the dataset |
| 12 | Weekly performance summary with buy/sell signal classification |

## Schema

```
companies ──< stock_prices
companies ──< sentiment_scores
companies ──< news_articles
cities
```

## Files

| File | Description |
|------|-------------|
| `01_schema.sql` | Tables, foreign keys, indexes |
| `02_seed.sql` | 22 companies, 25 cities, 2600+ rows generated via recursive CTE |
| `03_analysis.sql` | 12 analysis queries — window functions, CTEs, LAG, NTILE, UNION |

## Stack

MySQL 8.0+

## Setup

```bash
mysql -u root -p < 01_schema.sql
mysql -u root -p < 02_seed.sql
mysql -u root -p < 03_analysis.sql
```

## Related

Built to complement [Viglore](https://viglore.com) — a live market intelligence platform that tracks sentiment, stock data, and city rankings in real time.
