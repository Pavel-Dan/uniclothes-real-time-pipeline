-- Phase A : RBAC analyst + RGPD streaming (appliquer sur une base deja initialisee)
-- Usage: Get-Content sql/apply_phase_a.sql -Raw | docker compose exec -T postgres psql -U uniclothes -d uniclothes

-- Analyst : vue analytique uniquement (plus de PII directe)
REVOKE ALL ON dwh.fact_sales FROM uniclothes_analyst;
REVOKE ALL ON dwh.dim_customer FROM uniclothes_analyst;
REVOKE ALL ON dwh.dim_product FROM uniclothes_analyst;
REVOKE ALL ON dwh.dim_store FROM uniclothes_analyst;
REVOKE ALL ON dwh.dim_channel FROM uniclothes_analyst;
REVOKE ALL ON dwh.dim_date FROM uniclothes_analyst;
GRANT SELECT ON dwh.v_sales_analytics TO uniclothes_analyst;
GRANT SELECT ON dwh.dim_customer_anonymized TO uniclothes_analyst;

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
