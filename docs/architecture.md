# Architecture pipeline temps reel — Uniclos (Bloc 3)

## 1. Contexte metier

Uniclos est une marque omnicanale (~30 M EUR CA, 10 boutiques, e-commerce + app). Besoins temps reel :

- **CA live** par canal (web, app, boutique)
- **Golden record client** enrichi a chaque achat
- **Catalogue produit** avec images (MinIO)
- **Conformite RGPD** (export / effacement)

Volume estime : ~300 k commandes/an, pics soldes ~20–50 evt/s. Architecture micro-batch (2 min) adaptee a une PME.

## 2. Flux de donnees

```
Sources simulees (Python)
    → Redpanda (uniclos.orders.web | uniclos.orders.pos)
    → Consumer Python (validation)
    → raw.streaming_orders | raw.failed_events
    → dbt (staging.stg_orders → dwh.fact_sales)
    → staging.quality_metrics + monitoring.pipeline_runs
```

## 3. Stack technique

| Couche | Technologie |
|--------|-------------|
| Ingestion | Redpanda (API Kafka), Python kafka-python |
| Stockage | PostgreSQL 16 (medallion raw/staging/dwh) |
| Objets | MinIO (images produit, donnees non structurees) |
| Transform | dbt-postgres |
| Orchestration | Airflow 2.9 LocalExecutor |
| Qualite | Validateurs Python + SQL metrics |
| Monitoring | Airflow UI, Grafana, Prometheus |
| Securite | Roles PG, vues anonymisees, audit RGPD |

## 4. Schemas PostgreSQL

### raw
- `streaming_orders` — landing zone evenements valides
- `failed_events` — dead-letter queue
- Tables reference Bloc 2 (customers, products, stores)

### staging
- `customers_golden`, `products_golden` — referentiels init
- `quality_metrics` — KPIs gouvernance
- Vues dbt `stg_orders`, `stg_customers`

### dwh
- Star schema : `fact_sales`, dimensions `dim_*`

### monitoring
- `pipeline_runs` — historique executions DAG

### audit
- `gdpr_requests` + fonctions export/suppression

## 5. Topics Redpanda

| Topic | Contenu |
|-------|---------|
| uniclos.orders.web | Commandes web/app (JSON structure) |
| uniclos.orders.pos | Ventes caisse boutique |
| uniclos.orders.dlq | Messages rejetes |

## 6. Regles Data Quality

| Regle | Seuil | Action |
|-------|-------|--------|
| Champs obligatoires | 100% | Rejet → DLQ |
| Email valide | regex | Rejet → DLQ |
| Montant = qty × prix | ±0.05 EUR | Rejet → DLQ |
| Taux null order_id | 0% | Alerte staging.quality_metrics |
| Doublons order_id | 0% | Alerte |
| Orphelins product_key | 0% | Alerte |

## 7. Securite et RGPD

- Moindre privilege : roles `uniclothes_analyst`, `uniclothes_dpo`, `uniclos_grafana`
- Secrets centralises dans `docker/.env` (non commite)
- Vue `dwh.dim_customer_anonymized` pour BI
- Fonctions `audit.export_customer_gdpr`, `audit.delete_customer_gdpr`
- Production : TLS transit, chiffrement repos, secrets manager

## 8. Evolutivite (Phase 2)

1. Deploiement cloud (MSK / Confluent, RDS, MWAA)
2. Debezium CDC depuis ERP/POS reels
3. Streamlit BI Bloc 2 branche sur `dwh` temps reel
4. Multi-pays ES/IT

## 9. Diagramme

Voir [architecture-globale.drawio](architecture-globale.drawio) ou le README (mermaid).
