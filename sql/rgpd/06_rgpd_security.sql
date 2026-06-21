-- UNICLOTHES: RGPD - Security roles and anonymized views

-- ============================================================
-- Roles (principle of least privilege)
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'uniclothes_analyst') THEN
        CREATE ROLE uniclothes_analyst LOGIN;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'uniclothes_dpo') THEN
        CREATE ROLE uniclothes_dpo LOGIN;
    END IF;
END
$$;

GRANT USAGE ON SCHEMA dwh TO uniclothes_analyst, uniclothes_dpo;
GRANT USAGE ON SCHEMA staging TO uniclothes_analyst, uniclothes_dpo;
GRANT USAGE ON SCHEMA audit TO uniclothes_dpo;

-- Analyst: access anonymized views only (no direct PII)
REVOKE ALL ON dwh.dim_customer FROM uniclothes_analyst;

-- DPO: read-only on audit and staging metrics
GRANT SELECT ON staging.quality_metrics TO uniclothes_dpo;
GRANT SELECT ON audit.gdpr_requests TO uniclothes_dpo;

-- ============================================================
-- Anonymized customer view (for BI / analysts)
-- ============================================================
CREATE OR REPLACE VIEW dwh.dim_customer_anonymized AS
SELECT
    customer_key,
    golden_id,
    -- Mask email: show only domain
    CASE WHEN email IS NOT NULL
         THEN '***@' || SPLIT_PART(email, '@', 2)
         ELSE NULL END AS email_masked,
    LEFT(first_name, 1) || '***' AS first_name_masked,
    LEFT(last_name, 1) || '***' AS last_name_masked,
    consent_marketing,
    consent_date,
    last_activity,
    is_active_12m,
    email_valid
FROM dwh.dim_customer;

GRANT SELECT ON dwh.dim_customer_anonymized TO uniclothes_analyst;

-- Sales view without PII join needed for analysts
CREATE OR REPLACE VIEW dwh.v_sales_analytics AS
SELECT
    fs.order_id,
    dd.full_date,
    dd.month_name,
    dd.year_num,
    dca.email_masked,
    dca.is_active_12m,
    dca.consent_marketing,
    dp.product_ref,
    dp.product_name,
    dp.category,
    ds.store_name,
    dch.channel_name,
    fs.quantity,
    fs.amount_eur
FROM dwh.fact_sales fs
JOIN dwh.dim_date dd ON fs.date_key = dd.date_key
JOIN dwh.dim_customer_anonymized dca ON fs.customer_key = dca.customer_key
JOIN dwh.dim_product dp ON fs.product_key = dp.product_key
JOIN dwh.dim_store ds ON fs.store_key = ds.store_key
JOIN dwh.dim_channel dch ON fs.channel_key = dch.channel_key;

GRANT SELECT ON dwh.v_sales_analytics TO uniclothes_analyst;

-- ============================================================
-- GDPR: Right to erasure function
-- ============================================================
CREATE OR REPLACE FUNCTION audit.delete_customer_gdpr(p_email VARCHAR)
RETURNS TABLE(deleted_staging INT, deleted_dwh INT, audit_id INT) AS $$
DECLARE
    v_audit_id INT;
    v_staging INT;
    v_dwh INT;
    v_raw INT;
    v_facts INT;
    v_normalized VARCHAR;
BEGIN
    v_normalized := LOWER(TRIM(p_email));

    INSERT INTO audit.gdpr_requests (request_type, customer_email, status, notes)
    VALUES ('erasure', p_email, 'processing', 'Demande droit a l effacement')
    RETURNING request_id INTO v_audit_id;

    DELETE FROM dwh.fact_sales fs
    USING dwh.dim_customer dc
    WHERE fs.customer_key = dc.customer_key
      AND LOWER(TRIM(dc.email)) = v_normalized;
    GET DIAGNOSTICS v_facts = ROW_COUNT;

    DELETE FROM raw.streaming_orders
    WHERE LOWER(TRIM(customer_email)) = v_normalized;
    GET DIAGNOSTICS v_raw = ROW_COUNT;

    DELETE FROM staging.customers_golden WHERE email_normalized = v_normalized;
    GET DIAGNOSTICS v_staging = ROW_COUNT;

    DELETE FROM dwh.dim_customer WHERE LOWER(TRIM(email)) = v_normalized;
    GET DIAGNOSTICS v_dwh = ROW_COUNT;

    UPDATE audit.gdpr_requests
    SET processed_at = CURRENT_TIMESTAMP,
        status = 'completed',
        notes = format(
            'Supprime staging=%s, dwh=%s, raw=%s, fact_sales=%s',
            v_staging, v_dwh, v_raw, v_facts
        )
    WHERE request_id = v_audit_id;

    RETURN QUERY SELECT v_staging, v_dwh, v_audit_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION audit.delete_customer_gdpr(VARCHAR) TO uniclothes_dpo;

-- ============================================================
-- GDPR: Right of access function
-- ============================================================
CREATE OR REPLACE FUNCTION audit.export_customer_gdpr(p_email VARCHAR)
RETURNS TABLE(
    source_system VARCHAR,
    email VARCHAR,
    first_name VARCHAR,
    last_name VARCHAR,
    consent_marketing BOOLEAN,
    last_activity DATE
) AS $$
BEGIN
    INSERT INTO audit.gdpr_requests (request_type, customer_email, status)
    VALUES ('access', p_email, 'completed');

    RETURN QUERY
    SELECT cu.source_system::VARCHAR, cu.email, cu.first_name, cu.last_name,
           cu.consent_marketing, cu.last_activity
    FROM staging.customers_unified cu
    WHERE LOWER(TRIM(cu.email)) = LOWER(TRIM(p_email));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION audit.export_customer_gdpr(VARCHAR) TO uniclothes_dpo;
