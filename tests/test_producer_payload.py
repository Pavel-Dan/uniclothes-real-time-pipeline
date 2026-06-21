"""Tests de construction des payloads producer."""

from producers.order_event_producer import build_pos_order, build_web_order


def test_web_order_payload_structure():
    order = build_web_order("abc12345", 0)
    assert order["order_id"].startswith("WEB-RT-abc12345")
    assert order["channel"] in {"web", "app"}
    assert order["product_ref"].startswith("UC-")
    assert order["quantity"] >= 1
    assert order["amount_eur"] > 0
    assert "order_timestamp" in order


def test_pos_order_payload_structure():
    order = build_pos_order("abc12345", 1)
    assert order["order_id"].startswith("POS-RT-abc12345")
    assert order["channel"] == "store"
    assert order["store_code"] is not None
    assert order["amount_eur"] == round(order["quantity"] * order["unit_price_eur"], 2)
