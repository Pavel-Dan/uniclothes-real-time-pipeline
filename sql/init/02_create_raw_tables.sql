-- UNICLOTHES: Raw layer tables (simulated sources)

-- CRM UNICLUB source
CREATE TABLE IF NOT EXISTS raw.customers_crm (
    source_id       VARCHAR(50) PRIMARY KEY,
    email           VARCHAR(255),
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    phone           VARCHAR(30),
    consent_marketing BOOLEAN,
    consent_date    DATE,
    last_activity   DATE,
    source_system   VARCHAR(20) DEFAULT 'crm',
    loaded_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- E-commerce source
CREATE TABLE IF NOT EXISTS raw.customers_web (
    source_id       VARCHAR(50) PRIMARY KEY,
    email           VARCHAR(255),
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    phone           VARCHAR(30),
    consent_marketing BOOLEAN,
    consent_date    DATE,
    last_activity   DATE,
    source_system   VARCHAR(20) DEFAULT 'web',
    loaded_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- POS (boutiques) source
CREATE TABLE IF NOT EXISTS raw.customers_pos (
    source_id       VARCHAR(50) PRIMARY KEY,
    email           VARCHAR(255),
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    phone           VARCHAR(30),
    consent_marketing BOOLEAN,
    consent_date    DATE,
    last_activity   DATE,
    store_code      VARCHAR(10),
    source_system   VARCHAR(20) DEFAULT 'pos',
    loaded_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ERP products (reference master)
CREATE TABLE IF NOT EXISTS raw.products_erp (
    product_ref     VARCHAR(30) PRIMARY KEY,
    product_name    VARCHAR(200),
    category        VARCHAR(50),
    price_eur       NUMERIC(10,2),
    stock_qty       INTEGER,
    source_system   VARCHAR(20) DEFAULT 'erp',
    loaded_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Web catalog (may have inconsistent refs)
CREATE TABLE IF NOT EXISTS raw.products_web (
    web_sku         VARCHAR(30) PRIMARY KEY,
    product_ref     VARCHAR(30),
    product_name    VARCHAR(200),
    category        VARCHAR(50),
    price_eur       NUMERIC(10,2),
    source_system   VARCHAR(20) DEFAULT 'web',
    loaded_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Stores reference
CREATE TABLE IF NOT EXISTS raw.stores (
    store_code      VARCHAR(10) PRIMARY KEY,
    store_name      VARCHAR(100),
    city            VARCHAR(50),
    region          VARCHAR(50),
    opened_date     DATE
);

-- Orders from e-commerce / app
CREATE TABLE IF NOT EXISTS raw.orders_web (
    order_id        VARCHAR(50) PRIMARY KEY,
    customer_email  VARCHAR(255),
    channel         VARCHAR(10),
    order_date      TIMESTAMP,
    product_ref     VARCHAR(30),
    quantity        INTEGER,
    unit_price_eur  NUMERIC(10,2),
    amount_eur      NUMERIC(10,2)
);

-- Orders from POS
CREATE TABLE IF NOT EXISTS raw.orders_pos (
    order_id        VARCHAR(50) PRIMARY KEY,
    customer_email  VARCHAR(255),
    store_code      VARCHAR(10),
    order_date      TIMESTAMP,
    product_ref     VARCHAR(30),
    quantity        INTEGER,
    unit_price_eur  NUMERIC(10,2),
    amount_eur      NUMERIC(10,2)
);

-- Audit log for RGPD operations
CREATE TABLE IF NOT EXISTS audit.gdpr_requests (
    request_id      SERIAL PRIMARY KEY,
    request_type    VARCHAR(30),
    customer_email  VARCHAR(255),
    requested_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at    TIMESTAMP,
    status          VARCHAR(20) DEFAULT 'pending',
    notes           TEXT
);
