CREATE DATABASE IF NOT EXISTS market_sentiment
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE market_sentiment;

CREATE TABLE companies (
    id                  INT UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    ticker              VARCHAR(10)   NOT NULL,
    name                VARCHAR(100)  NOT NULL,
    sector              VARCHAR(60)   NOT NULL,
    industry            VARCHAR(80)   NOT NULL,
    market_cap_category ENUM('Mega','Large','Mid','Small') NOT NULL DEFAULT 'Large',
    base_price          DECIMAL(10,2) NOT NULL,
    volatility          DECIMAL(4,3)  NOT NULL DEFAULT 0.020,
    CONSTRAINT uq_companies_ticker UNIQUE (ticker)
);

CREATE TABLE stock_prices (
    id               INT UNSIGNED    AUTO_INCREMENT PRIMARY KEY,
    company_id       INT UNSIGNED    NOT NULL,
    price_date       DATE            NOT NULL,
    open_price       DECIMAL(10,2)   NOT NULL,
    close_price      DECIMAL(10,2)   NOT NULL,
    high_price       DECIMAL(10,2)   NOT NULL,
    low_price        DECIMAL(10,2)   NOT NULL,
    volume           BIGINT UNSIGNED NOT NULL,
    price_change_pct DECIMAL(6,3)    NOT NULL,
    CONSTRAINT uq_stock_date UNIQUE (company_id, price_date),
    CONSTRAINT fk_sp_company FOREIGN KEY (company_id)
        REFERENCES companies(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX idx_sp_date         ON stock_prices (price_date);
CREATE INDEX idx_sp_company_date ON stock_prices (company_id, price_date);

-- VADER-style scores: -1.0 (very negative) to 1.0 (very positive)
CREATE TABLE sentiment_scores (
    id            INT UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    company_id    INT UNSIGNED  NOT NULL,
    score_date    DATE          NOT NULL,
    score         DECIMAL(5,4)  NOT NULL,
    source        ENUM('news','social','combined') NOT NULL DEFAULT 'combined',
    article_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    CONSTRAINT uq_sentiment_date UNIQUE (company_id, score_date, source),
    CONSTRAINT chk_sentiment_range CHECK (score BETWEEN -1 AND 1),
    CONSTRAINT fk_ss_company FOREIGN KEY (company_id)
        REFERENCES companies(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX idx_ss_date         ON sentiment_scores (score_date);
CREATE INDEX idx_ss_company_date ON sentiment_scores (company_id, score_date);
CREATE INDEX idx_ss_source       ON sentiment_scores (source);

CREATE TABLE news_articles (
    id              INT UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    company_id      INT UNSIGNED  NOT NULL,
    published_at    DATETIME      NOT NULL,
    source          VARCHAR(80)   NOT NULL,
    headline        VARCHAR(255)  NOT NULL,
    sentiment_score DECIMAL(5,4)  NOT NULL,
    CONSTRAINT chk_article_sentiment CHECK (sentiment_score BETWEEN -1 AND 1),
    CONSTRAINT fk_na_company FOREIGN KEY (company_id)
        REFERENCES companies(id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX idx_na_company   ON news_articles (company_id, published_at);
CREATE INDEX idx_na_published ON news_articles (published_at);
CREATE INDEX idx_na_source    ON news_articles (source);

-- tech hub city rankings (mirrors what Viglore tracks)
CREATE TABLE cities (
    id             INT UNSIGNED   AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(80)    NOT NULL,
    state          VARCHAR(50)    NOT NULL,
    tech_rank      SMALLINT UNSIGNED NOT NULL,
    tech_jobs      INT UNSIGNED   NOT NULL,
    avg_salary     INT UNSIGNED   NOT NULL,
    startups       SMALLINT UNSIGNED NOT NULL,
    yoy_growth_pct DECIMAL(5,2)   NOT NULL
);

CREATE INDEX idx_cities_rank ON cities (tech_rank);
