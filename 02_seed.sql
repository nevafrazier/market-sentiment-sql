USE market_sentiment;

INSERT INTO companies (ticker, name, sector, industry, market_cap_category, base_price, volatility) VALUES
('AAPL',  'Apple Inc.',                   'Technology',   'Consumer Electronics',    'Mega',  172.50, 0.018),
('MSFT',  'Microsoft Corporation',        'Technology',   'Software',                'Mega',  378.90, 0.016),
('GOOGL', 'Alphabet Inc.',                'Technology',   'Internet Services',       'Mega',  141.80, 0.019),
('META',  'Meta Platforms Inc.',          'Technology',   'Social Media',            'Mega',  481.20, 0.024),
('NVDA',  'NVIDIA Corporation',           'Technology',   'Semiconductors',          'Mega',  820.00, 0.032),
('AMZN',  'Amazon.com Inc.',              'Technology',   'E-Commerce',              'Mega',  186.40, 0.020),
('TSLA',  'Tesla Inc.',                   'Consumer',     'Electric Vehicles',       'Mega',  177.60, 0.038),
('JPM',   'JPMorgan Chase & Co.',         'Finance',      'Banking',                 'Mega',  198.30, 0.015),
('GS',    'Goldman Sachs Group Inc.',     'Finance',      'Investment Banking',      'Large', 461.70, 0.017),
('BAC',   'Bank of America Corp.',        'Finance',      'Banking',                 'Large',  37.40, 0.016),
('JNJ',   'Johnson & Johnson',            'Healthcare',   'Pharmaceuticals',         'Mega',  156.20, 0.012),
('PFE',   'Pfizer Inc.',                  'Healthcare',   'Pharmaceuticals',         'Large',  27.80, 0.014),
('UNH',   'UnitedHealth Group',           'Healthcare',   'Managed Care',            'Mega',  528.40, 0.013),
('XOM',   'Exxon Mobil Corporation',      'Energy',       'Oil & Gas',               'Mega',  114.60, 0.017),
('CVX',   'Chevron Corporation',          'Energy',       'Oil & Gas',               'Large', 154.90, 0.016),
('WMT',   'Walmart Inc.',                 'Retail',       'Discount Stores',         'Mega',   65.30, 0.011),
('TGT',   'Target Corporation',           'Retail',       'Discount Stores',         'Large', 153.70, 0.019),
('COST',  'Costco Wholesale Corp.',       'Retail',       'Wholesale Clubs',         'Mega',  792.50, 0.014),
('F',     'Ford Motor Company',           'Consumer',     'Automobiles',             'Large',  12.40, 0.023),
('GM',    'General Motors Company',       'Consumer',     'Automobiles',             'Large',  46.80, 0.021),
('T',     'AT&T Inc.',                    'Telecom',      'Telecom Services',        'Large',  17.20, 0.012),
('VZ',    'Verizon Communications',       'Telecom',      'Telecom Services',        'Large',  40.10, 0.011);

-- generate 60 trading days of stock prices using deterministic rand (reproducible)
INSERT INTO stock_prices (company_id, price_date, open_price, close_price, high_price, low_price, volume, price_change_pct)
WITH RECURSIVE date_series AS (
    SELECT DATE_SUB(CURDATE(), INTERVAL 89 DAY) AS dt
    UNION ALL
    SELECT DATE_ADD(dt, INTERVAL 1 DAY) FROM date_series WHERE dt < CURDATE()
),
trading_days AS (
    SELECT dt FROM date_series WHERE DAYOFWEEK(dt) NOT IN (1, 7)
),
price_data AS (
    SELECT
        c.id                                                          AS company_id,
        td.dt                                                         AS price_date,
        -- deterministic seed so results are reproducible
        ROUND(c.base_price * (1 + (RAND(c.id * 997 + DATEDIFF(td.dt, '2024-01-01')) - 0.5) * c.volatility * 2), 2) AS open_p,
        ROUND(c.base_price * (1 + (RAND(c.id * 1009 + DATEDIFF(td.dt, '2024-01-01')) - 0.5) * c.volatility * 2), 2) AS close_p,
        c.base_price,
        c.volatility,
        RAND(c.id * 503 + DATEDIFF(td.dt, '2024-01-01')) AS r_vol
    FROM companies c
    CROSS JOIN trading_days td
)
SELECT
    company_id,
    price_date,
    open_p,
    close_p,
    ROUND(GREATEST(open_p, close_p) * (1 + volatility * 0.5 * RAND(company_id * 7 + DATEDIFF(price_date,'2024-01-01'))), 2) AS high_price,
    ROUND(LEAST(open_p, close_p)    * (1 - volatility * 0.5 * RAND(company_id * 11 + DATEDIFF(price_date,'2024-01-01'))), 2) AS low_price,
    ROUND((5000000 + r_vol * 45000000) / (base_price / 100))                                                                  AS volume,
    ROUND((close_p - open_p) / open_p * 100, 3)                                                                               AS price_change_pct
FROM price_data;

-- sentiment scores — loosely correlated with price direction
INSERT INTO sentiment_scores (company_id, score_date, score, source, article_count)
WITH RECURSIVE date_series AS (
    SELECT DATE_SUB(CURDATE(), INTERVAL 89 DAY) AS dt
    UNION ALL
    SELECT DATE_ADD(dt, INTERVAL 1 DAY) FROM date_series WHERE dt < CURDATE()
),
trading_days AS (
    SELECT dt FROM date_series WHERE DAYOFWEEK(dt) NOT IN (1, 7)
)
SELECT
    c.id,
    td.dt,
    -- score between -0.4 and 0.6 (large caps skew slightly positive)
    ROUND(LEAST(1, GREATEST(-1,
        0.1 + (RAND(c.id * 2003 + DATEDIFF(td.dt, '2024-01-01')) - 0.4) * 0.8
    )), 4)                                                  AS score,
    'combined'                                              AS source,
    FLOOR(3 + RAND(c.id * 31 + DATEDIFF(td.dt, '2024-01-01')) * 22) AS article_count
FROM companies c
CROSS JOIN trading_days td;

INSERT INTO news_articles (company_id, published_at, source, headline, sentiment_score) VALUES
(1,  DATE_SUB(NOW(), INTERVAL 2  DAY), 'Reuters',       'Apple reports record iPhone sales in emerging markets',           0.7200),
(1,  DATE_SUB(NOW(), INTERVAL 5  DAY), 'Bloomberg',     'Apple faces antitrust scrutiny over App Store policies',         -0.5100),
(1,  DATE_SUB(NOW(), INTERVAL 9  DAY), 'CNBC',          'Apple Vision Pro demand exceeds supply forecasts',               0.6300),
(1,  DATE_SUB(NOW(), INTERVAL 14 DAY), 'WSJ',           'Apple suppliers signal strong Q2 production ramp',              0.4800),
(2,  DATE_SUB(NOW(), INTERVAL 1  DAY), 'Bloomberg',     'Microsoft Azure cloud revenue surges 31% year over year',        0.8100),
(2,  DATE_SUB(NOW(), INTERVAL 4  DAY), 'Reuters',       'Microsoft Copilot adoption accelerating across enterprise',      0.6700),
(2,  DATE_SUB(NOW(), INTERVAL 11 DAY), 'CNBC',          'Microsoft raises dividend amid strong cash flow generation',     0.5900),
(3,  DATE_SUB(NOW(), INTERVAL 3  DAY), 'WSJ',           'Alphabet advertising revenue beats expectations',                0.5500),
(3,  DATE_SUB(NOW(), INTERVAL 7  DAY), 'Bloomberg',     'Google faces EU fine over search dominance concerns',           -0.6200),
(3,  DATE_SUB(NOW(), INTERVAL 13 DAY), 'Reuters',       'Google DeepMind announces breakthrough in protein folding',      0.7400),
(4,  DATE_SUB(NOW(), INTERVAL 2  DAY), 'CNBC',          'Meta AI assistant hits 500 million monthly active users',        0.7900),
(4,  DATE_SUB(NOW(), INTERVAL 8  DAY), 'WSJ',           'Meta Reality Labs posts another quarterly loss',                -0.4300),
(4,  DATE_SUB(NOW(), INTERVAL 15 DAY), 'Bloomberg',     'Meta ad revenue growth accelerates heading into Q3',            0.6100),
(5,  DATE_SUB(NOW(), INTERVAL 1  DAY), 'Reuters',       'NVIDIA data center revenue triples on AI chip demand',          0.9200),
(5,  DATE_SUB(NOW(), INTERVAL 6  DAY), 'CNBC',          'NVIDIA Blackwell GPU shipments ahead of schedule',              0.8300),
(5,  DATE_SUB(NOW(), INTERVAL 10 DAY), 'Bloomberg',     'NVIDIA faces export restrictions on advanced chips to China',   -0.5800),
(5,  DATE_SUB(NOW(), INTERVAL 18 DAY), 'WSJ',           'NVIDIA market cap briefly surpasses all major competitors',     0.7600),
(6,  DATE_SUB(NOW(), INTERVAL 3  DAY), 'Reuters',       'Amazon AWS growth reaccelerates to 17% in latest quarter',      0.7100),
(6,  DATE_SUB(NOW(), INTERVAL 9  DAY), 'Bloomberg',     'Amazon expands same-day delivery to 20 additional cities',      0.4900),
(7,  DATE_SUB(NOW(), INTERVAL 2  DAY), 'CNBC',          'Tesla Cybertruck production ramp hits unexpected bottlenecks',  -0.5500),
(7,  DATE_SUB(NOW(), INTERVAL 7  DAY), 'WSJ',           'Tesla price cuts pressure margins but drive volume growth',     -0.2800),
(7,  DATE_SUB(NOW(), INTERVAL 12 DAY), 'Reuters',       'Tesla Supercharger network becomes industry standard',           0.6200),
(8,  DATE_SUB(NOW(), INTERVAL 4  DAY), 'Bloomberg',     'JPMorgan profit rises on higher interest income',               0.5800),
(8,  DATE_SUB(NOW(), INTERVAL 11 DAY), 'WSJ',           'JPMorgan CEO warns of economic headwinds in H2 2025',          -0.3900),
(9,  DATE_SUB(NOW(), INTERVAL 5  DAY), 'CNBC',          'Goldman Sachs investment banking fees surge on M&A rebound',    0.6900),
(10, DATE_SUB(NOW(), INTERVAL 6  DAY), 'Reuters',       'Bank of America net interest income tops analyst estimates',    0.5100),
(11, DATE_SUB(NOW(), INTERVAL 3  DAY), 'Bloomberg',     'J&J MedTech division posts strongest quarter in five years',    0.5600),
(12, DATE_SUB(NOW(), INTERVAL 8  DAY), 'WSJ',           'Pfizer obesity drug trial results disappoint investors',        -0.7100),
(12, DATE_SUB(NOW(), INTERVAL 16 DAY), 'Reuters',       'Pfizer announces $3.5B cost cutting program',                  -0.2400),
(13, DATE_SUB(NOW(), INTERVAL 2  DAY), 'CNBC',          'UnitedHealth raises full year guidance on strong enrollment',   0.6800),
(14, DATE_SUB(NOW(), INTERVAL 4  DAY), 'Bloomberg',     'ExxonMobil benefits from sustained high oil prices',            0.4700),
(15, DATE_SUB(NOW(), INTERVAL 7  DAY), 'Reuters',       'Chevron completes Hess acquisition ahead of schedule',         0.3900),
(16, DATE_SUB(NOW(), INTERVAL 1  DAY), 'WSJ',           'Walmart grocery market share hits all time high',              0.6300),
(17, DATE_SUB(NOW(), INTERVAL 5  DAY), 'CNBC',          'Target misses comparable sales estimates for third quarter',   -0.5200),
(18, DATE_SUB(NOW(), INTERVAL 3  DAY), 'Bloomberg',     'Costco membership renewal rates remain above 90%',             0.7200),
(19, DATE_SUB(NOW(), INTERVAL 9  DAY), 'Reuters',       'Ford EV losses narrow as production efficiency improves',       0.3100),
(20, DATE_SUB(NOW(), INTERVAL 6  DAY), 'WSJ',           'GM delays EV truck launch citing battery supply constraints',  -0.4800),
(21, DATE_SUB(NOW(), INTERVAL 4  DAY), 'CNBC',          'AT&T postpaid phone net adds beat expectations',               0.3600),
(22, DATE_SUB(NOW(), INTERVAL 7  DAY), 'Bloomberg',     'Verizon loses broadband subscribers to fixed wireless rivals', -0.3300);

INSERT INTO cities (name, state, tech_rank, tech_jobs, avg_salary, startups, yoy_growth_pct) VALUES
('San Francisco',  'California',  1,  285000, 162000, 4820, 3.2),
('Seattle',        'Washington',  2,  198000, 148000, 2140, 4.1),
('New York City',  'New York',    3,  310000, 135000, 5670, 2.8),
('Austin',         'Texas',       4,  142000, 128000, 2890, 8.4),
('Boston',         'Massachusetts',5, 118000, 139000, 1940, 3.6),
('San Jose',       'California',  6,  176000, 158000, 1820, 1.9),
('Los Angeles',    'California',  7,  162000, 125000, 3140, 3.1),
('Chicago',        'Illinois',    8,  128000, 118000, 1680, 2.4),
('Denver',         'Colorado',    9,   94000, 119000, 1420, 6.2),
('Atlanta',        'Georgia',    10,  108000, 112000, 1560, 5.8),
('Miami',          'Florida',    11,   86000, 109000, 1890, 9.1),
('Washington DC',  'DC',         12,  142000, 131000, 1240, 2.2),
('Dallas',         'Texas',      13,   98000, 115000, 1340, 6.7),
('Raleigh',        'North Carolina',14, 72000, 114000, 980, 7.3),
('Portland',       'Oregon',     15,   64000, 118000, 840, 4.4),
('Nashville',      'Tennessee',  16,   54000, 104000, 720, 8.9),
('Phoenix',        'Arizona',    17,   76000, 108000, 890, 7.1),
('Minneapolis',    'Minnesota',  18,   68000, 112000, 640, 2.9),
('San Diego',      'California', 19,   74000, 122000, 920, 3.8),
('Salt Lake City', 'Utah',       20,   58000, 110000, 780, 9.4),
('Pittsburgh',     'Pennsylvania',21,  52000, 108000, 580, 4.2),
('Detroit',        'Michigan',   22,   48000,  98000, 420, 3.5),
('Charlotte',      'North Carolina',23, 56000, 106000, 640, 6.8),
('Columbus',       'Ohio',       24,   46000, 102000, 480, 5.1),
('Indianapolis',   'Indiana',    25,   42000,  99000, 380, 4.7);
