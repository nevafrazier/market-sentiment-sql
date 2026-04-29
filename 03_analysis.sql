USE market_sentiment;


-- top 10 companies by avg sentiment last 30 days
SELECT
    c.ticker,
    c.name,
    c.sector,
    ROUND(AVG(s.score), 4)       AS avg_sentiment,
    SUM(s.article_count)         AS total_articles,
    RANK() OVER (ORDER BY AVG(s.score) DESC) AS sentiment_rank
FROM sentiment_scores s
JOIN companies c ON s.company_id = c.id
WHERE s.score_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
  AND s.source = 'combined'
GROUP BY c.id, c.ticker, c.name, c.sector
ORDER BY avg_sentiment DESC
LIMIT 10;


-- which sectors is the market most bullish/bearish on
SELECT
    c.sector,
    ROUND(AVG(s.score), 4)                   AS avg_sentiment,
    COUNT(DISTINCT c.id)                     AS companies_tracked,
    SUM(s.article_count)                     AS total_coverage,
    RANK() OVER (ORDER BY AVG(s.score) DESC) AS sector_rank
FROM sentiment_scores s
JOIN companies c ON s.company_id = c.id
WHERE s.score_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY c.sector
ORDER BY avg_sentiment DESC;


-- does sentiment actually predict next-day price movement?
WITH sentiment_today AS (
    SELECT company_id, score_date, score
    FROM sentiment_scores
    WHERE source = 'combined'
),
price_tomorrow AS (
    SELECT company_id, price_date, price_change_pct
    FROM stock_prices
)
SELECT
    c.ticker,
    ROUND(AVG(st.score), 4)            AS avg_sentiment,
    ROUND(AVG(pt.price_change_pct), 3) AS avg_next_day_change_pct,
    COUNT(*)                           AS data_points,
    CASE
        WHEN AVG(st.score) > 0.1  AND AVG(pt.price_change_pct) > 0 THEN 'Predictive — Positive'
        WHEN AVG(st.score) < -0.1 AND AVG(pt.price_change_pct) < 0 THEN 'Predictive — Negative'
        ELSE 'No Clear Signal'
    END AS signal_strength
FROM sentiment_today st
JOIN price_tomorrow pt
    ON  st.company_id = pt.company_id
    AND pt.price_date = DATE_ADD(st.score_date, INTERVAL 1 DAY)
JOIN companies c ON st.company_id = c.id
GROUP BY c.id, c.ticker
ORDER BY avg_sentiment DESC;


-- divergence signal: sentiment improving but price still falling
WITH recent_sentiment AS (
    SELECT
        company_id,
        ROUND(AVG(CASE WHEN score_date >= DATE_SUB(CURDATE(), INTERVAL 7  DAY) THEN score END), 4) AS sentiment_last_7d,
        ROUND(AVG(CASE WHEN score_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN score END), 4) AS sentiment_last_30d
    FROM sentiment_scores
    WHERE source = 'combined'
    GROUP BY company_id
),
recent_price AS (
    SELECT
        company_id,
        ROUND(AVG(CASE WHEN price_date >= DATE_SUB(CURDATE(), INTERVAL 7  DAY) THEN price_change_pct END), 3) AS price_change_7d,
        ROUND(AVG(CASE WHEN price_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN price_change_pct END), 3) AS price_change_30d
    FROM stock_prices
    GROUP BY company_id
)
SELECT
    c.ticker,
    c.name,
    c.sector,
    rs.sentiment_last_7d,
    rs.sentiment_last_30d,
    rp.price_change_7d,
    rp.price_change_30d
FROM recent_sentiment rs
JOIN recent_price rp ON rs.company_id = rp.company_id
JOIN companies    c  ON rs.company_id = c.id
WHERE rs.sentiment_last_7d > rs.sentiment_last_30d  -- sentiment improving
  AND rp.price_change_7d   < 0                       -- but price still dropping
ORDER BY rs.sentiment_last_7d DESC;


-- rolling 7-day sentiment for the 5 most covered companies
WITH top_companies AS (
    SELECT company_id
    FROM sentiment_scores
    GROUP BY company_id
    ORDER BY SUM(article_count) DESC
    LIMIT 5
)
SELECT
    c.ticker,
    s.score_date,
    ROUND(s.score, 4) AS daily_score,
    ROUND(
        AVG(s.score) OVER (
            PARTITION BY s.company_id
            ORDER BY s.score_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 4
    ) AS rolling_7d_avg
FROM sentiment_scores s
JOIN companies    c  ON s.company_id = c.id
JOIN top_companies tc ON s.company_id = tc.company_id
WHERE s.source = 'combined'
  AND s.score_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
ORDER BY c.ticker, s.score_date;


-- month over month sentiment shift per company
WITH monthly_sentiment AS (
    SELECT
        c.ticker,
        c.sector,
        DATE_FORMAT(s.score_date, '%Y-%m') AS month,
        ROUND(AVG(s.score), 4)             AS avg_score
    FROM sentiment_scores s
    JOIN companies c ON s.company_id = c.id
    WHERE s.source = 'combined'
    GROUP BY c.id, c.ticker, c.sector, DATE_FORMAT(s.score_date, '%Y-%m')
)
SELECT
    ticker,
    sector,
    month,
    avg_score,
    LAG(avg_score) OVER (PARTITION BY ticker ORDER BY month) AS prev_month_score,
    ROUND(avg_score - LAG(avg_score) OVER (PARTITION BY ticker ORDER BY month), 4) AS mom_change,
    CASE
        WHEN avg_score - LAG(avg_score) OVER (PARTITION BY ticker ORDER BY month) >  0.05 THEN 'Strong Improvement'
        WHEN avg_score - LAG(avg_score) OVER (PARTITION BY ticker ORDER BY month) >  0    THEN 'Slight Improvement'
        WHEN avg_score - LAG(avg_score) OVER (PARTITION BY ticker ORDER BY month) < -0.05 THEN 'Strong Decline'
        WHEN avg_score - LAG(avg_score) OVER (PARTITION BY ticker ORDER BY month) <  0    THEN 'Slight Decline'
        ELSE 'Flat'
    END AS trend
FROM monthly_sentiment
ORDER BY ticker, month;


-- most volatile stocks by price std deviation
SELECT
    c.ticker,
    c.name,
    c.sector,
    ROUND(STDDEV(sp.price_change_pct), 4)              AS price_volatility,
    ROUND(AVG(sp.price_change_pct), 3)                 AS avg_daily_change,
    ROUND(MAX(sp.price_change_pct), 3)                 AS best_day,
    ROUND(MIN(sp.price_change_pct), 3)                 AS worst_day,
    RANK() OVER (ORDER BY STDDEV(sp.price_change_pct) DESC) AS volatility_rank
FROM stock_prices sp
JOIN companies c ON sp.company_id = c.id
GROUP BY c.id, c.ticker, c.name, c.sector
ORDER BY price_volatility DESC;


-- sentiment bias by news source
SELECT
    source,
    COUNT(*)                          AS articles,
    ROUND(AVG(sentiment_score), 4)    AS avg_sentiment,
    ROUND(MIN(sentiment_score), 4)    AS most_negative,
    ROUND(MAX(sentiment_score), 4)    AS most_positive,
    ROUND(STDDEV(sentiment_score), 4) AS sentiment_variance,
    RANK() OVER (ORDER BY AVG(sentiment_score) DESC) AS positivity_rank
FROM news_articles
GROUP BY source
ORDER BY avg_sentiment DESC;


-- sentiment quartile ranking across all companies
WITH avg_scores AS (
    SELECT
        c.ticker,
        c.name,
        c.sector,
        ROUND(AVG(s.score), 4) AS avg_sentiment
    FROM sentiment_scores s
    JOIN companies c ON s.company_id = c.id
    WHERE s.score_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
      AND s.source = 'combined'
    GROUP BY c.id, c.ticker, c.name, c.sector
)
SELECT
    ticker,
    name,
    sector,
    avg_sentiment,
    NTILE(4) OVER (ORDER BY avg_sentiment DESC) AS quartile,
    CASE NTILE(4) OVER (ORDER BY avg_sentiment DESC)
        WHEN 1 THEN 'Top Tier'
        WHEN 2 THEN 'Above Average'
        WHEN 3 THEN 'Below Average'
        WHEN 4 THEN 'Bottom Tier'
    END AS tier
FROM avg_scores
ORDER BY avg_sentiment DESC;


-- top tech cities, composite score weighted 40% jobs / 30% salary / 30% growth
SELECT
    name,
    state,
    tech_rank,
    tech_jobs,
    avg_salary,
    yoy_growth_pct,
    ROUND(
        (tech_jobs    / MAX(tech_jobs)    OVER () * 0.40 +
         avg_salary   / MAX(avg_salary)   OVER () * 0.30 +
         yoy_growth_pct / MAX(yoy_growth_pct) OVER () * 0.30) * 100, 2
    ) AS composite_score,
    RANK() OVER (
        ORDER BY (
            tech_jobs    / MAX(tech_jobs)    OVER () * 0.40 +
            avg_salary   / MAX(avg_salary)   OVER () * 0.30 +
            yoy_growth_pct / MAX(yoy_growth_pct) OVER () * 0.30
        ) DESC
    ) AS composite_rank
FROM cities
ORDER BY composite_rank;


-- best and worst single-day moves
(
    SELECT 'best' AS type, c.ticker, c.name, sp.price_date, sp.price_change_pct
    FROM stock_prices sp
    JOIN companies c ON sp.company_id = c.id
    ORDER BY sp.price_change_pct DESC
    LIMIT 5
)
UNION ALL
(
    SELECT 'worst' AS type, c.ticker, c.name, sp.price_date, sp.price_change_pct
    FROM stock_prices sp
    JOIN companies c ON sp.company_id = c.id
    ORDER BY sp.price_change_pct ASC
    LIMIT 5
)
ORDER BY type, price_change_pct DESC;


-- weekly performance summary with signal classification
WITH weekly AS (
    SELECT
        c.ticker,
        c.sector,
        ROUND(AVG(sp.price_change_pct), 3) AS avg_price_change,
        ROUND(AVG(s.score), 4)             AS avg_sentiment,
        SUM(s.article_count)               AS total_articles
    FROM stock_prices sp
    JOIN sentiment_scores s
        ON  sp.company_id = s.company_id
        AND sp.price_date  = s.score_date
        AND s.source       = 'combined'
    JOIN companies c ON sp.company_id = c.id
    WHERE sp.price_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
    GROUP BY c.id, c.ticker, c.sector
)
SELECT
    ticker,
    sector,
    avg_price_change,
    avg_sentiment,
    total_articles,
    CASE
        WHEN avg_price_change > 1  AND avg_sentiment > 0.2  THEN 'Strong Buy Signal'
        WHEN avg_price_change > 0  AND avg_sentiment > 0    THEN 'Mild Bullish'
        WHEN avg_price_change < -1 AND avg_sentiment < -0.2 THEN 'Strong Sell Signal'
        WHEN avg_price_change < 0  AND avg_sentiment < 0    THEN 'Mild Bearish'
        ELSE 'Mixed Signal'
    END AS weekly_signal
FROM weekly
ORDER BY avg_price_change DESC;
