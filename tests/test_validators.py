"""Tests des regles de validation DQ."""

from dq.validators import build_invalid_order_for_testing, validate_order_event


def test_valid_web_order():
    payload = {
        "order_id": "WEB-RT-test-0001",
        "customer_email": "test@email.com",
        "channel": "web",
        "store_code": None,
        "product_ref": "UC-TS-001",
        "quantity": 2,
        "unit_price_eur": 29.90,
        "amount_eur": 59.80,
        "order_timestamp": "2026-06-20T10:00:00+00:00",
    }
    valid, error = validate_order_event(payload)
    assert valid is True
    assert error is None


def test_valid_store_order():
    payload = {
        "order_id": "POS-RT-test-0001",
        "customer_email": "test@email.com",
        "channel": "store",
        "store_code": "PAR01",
        "product_ref": "UC-PA-001",
        "quantity": 1,
        "unit_price_eur": 79.90,
        "amount_eur": 79.90,
        "order_timestamp": "2026-06-20T10:00:00+00:00",
    }
    valid, error = validate_order_event(payload)
    assert valid is True


def test_invalid_order_rejected():
    valid, error = validate_order_event(build_invalid_order_for_testing())
    assert valid is False
    assert error is not None


def test_amount_mismatch_rejected():
    payload = {
        "order_id": "WEB-RT-bad-amount",
        "customer_email": "test@email.com",
        "channel": "web",
        "product_ref": "UC-TS-001",
        "quantity": 2,
        "unit_price_eur": 29.90,
        "amount_eur": 10.00,
        "order_timestamp": "2026-06-20T10:00:00+00:00",
    }
    valid, error = validate_order_event(payload)
    assert valid is False
    assert "Incoherence montant" in error
