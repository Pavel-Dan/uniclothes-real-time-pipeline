"""Regles de controle qualite pour les evenements commandes Uniclos."""

from __future__ import annotations

import re
from typing import Any

EMAIL_PATTERN = re.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
PRODUCT_PATTERN = re.compile(r"^UC-[A-Z]{2}-\d{3}$")


def validate_order_event(payload: dict[str, Any]) -> tuple[bool, str | None]:
    """
    Valide le schema metier d un evenement commande.
    Retourne (True, None) si valide, sinon (False, raison).
    """
    required_fields = [
        "order_id", "customer_email", "channel", "product_ref",
        "quantity", "unit_price_eur", "amount_eur", "order_timestamp",
    ]
    for field in required_fields:
        if field not in payload or payload[field] in (None, ""):
            return False, f"Champ obligatoire manquant: {field}"

    if not EMAIL_PATTERN.match(str(payload["customer_email"])):
        return False, "Email client invalide"

    if not PRODUCT_PATTERN.match(str(payload["product_ref"])):
        return False, "Reference produit invalide"

    quantity = payload["quantity"]
    unit_price = float(payload["unit_price_eur"])
    amount = float(payload["amount_eur"])

    if quantity <= 0:
        return False, "Quantite doit etre positive"
    if unit_price <= 0 or amount <= 0:
        return False, "Montants doivent etre positifs"

    expected = round(quantity * unit_price, 2)
    if abs(expected - amount) > 0.05:
        return False, f"Incoherence montant: attendu {expected}, recu {amount}"

    channel = payload["channel"]
    if channel not in {"web", "app", "store"}:
        return False, f"Canal inconnu: {channel}"

    if channel == "store" and not payload.get("store_code"):
        return False, "store_code obligatoire pour le canal store"

    return True, None


def build_invalid_order_for_testing() -> dict:
    """Payload volontairement invalide pour tests DLQ."""
    return {
        "order_id": "BAD-001",
        "customer_email": "not-an-email",
        "channel": "web",
        "product_ref": "INVALID",
        "quantity": 0,
        "unit_price_eur": -10,
        "amount_eur": -10,
        "order_timestamp": "2026-06-20T10:00:00+00:00",
    }
