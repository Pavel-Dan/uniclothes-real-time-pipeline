# Script vidéo démo — Uniclos pipeline (4 min 30 — 5 min)

> **Préparation écran** : résolution 1920×1080, bureau épuré, 4 fenêtres prêtes (Terminal, Airflow, Grafana, DBeaver/psql).  
> **Avant enregistrement** : stack démarrée, au moins un run DAG entièrement vert, Grafana avec events > 0.

---

## Séquence 0 — Intro (0:00 – 0:25)

**À l'écran**

- Slide titre ou README GitHub avec le nom du repo « Bloc3 Real time data pipeline ».

**À dire (mot à mot)**

« Bonjour. Je présente le pipeline de données temps réel que j'ai conçu pour Uniclos, une marque de mode omnicanale. Ce pipeline ingère des commandes web et boutique en continu, les transforme dans un entrepôt PostgreSQL, contrôle leur qualité, et les monitorer via Airflow et Grafana. Je vais vous montrer le système en fonctionnement, de l'événement Kafka jusqu'au tableau de bord. »

**Grille visée** : pipeline fonctionnel, clarté présentation.

---

## Séquence 1 — Stack Docker opérationnelle (0:25 – 1:00)

**À l'écran**

1. Terminal PowerShell, dossier `docker`.
2. Taper : `docker compose ps`
3. Montrer la colonne STATUS : postgres, redpanda, airflow-webserver, airflow-scheduler, grafana = **Up** ou **healthy**.

**À dire**

« Je commence par vérifier que toute la stack Docker est opérationnelle. PostgreSQL stocke les données en couches raw, staging et DWH. Redpanda joue le rôle de broker Kafka pour le streaming. Airflow orchestre le pipeline toutes les deux minutes, et Grafana affiche les indicateurs de suivi. Comme vous le voyez, tous les services sont démarrés et prêts à traiter des événements. »

**Grille visée** : architecture 2.1, fiabilité 1.4, déploiement reproductible.

---

## Séquence 2 — Orchestration Airflow (1:00 – 1:50)

**À l'écran**

1. Navigateur : http://localhost:8080
2. Ouvrir le DAG **`uniclos_realtime_pipeline`**
3. Vue **Graph** : montrer les 9 tâches.
4. Cliquer **Trigger DAG** (si besoin d'un run frais).
5. Vue **Grid** : colonne récente entièrement **verte** (produce → consume → dbt_run → dbt_test → run_dq_checks → log_pipeline_run).
6. Zoom sur une tâche `dbt_test` → onglet **Log** → montrer « PASS=… ERROR=0 ».

**À dire**

« Le cœur de l'automatisation est ce DAG Airflow, planifié toutes les deux minutes. La première tâche simule des commandes web et POS. La deuxième les consomme depuis Redpanda vers PostgreSQL. Ensuite dbt exécute les modèles staging et alimente la table de faits, puis dbt test vérifie les contraintes not null, unique et relationships. Les contrôles qualité mettent à jour les métriques, et la dernière tâche journalise le run pour Grafana. Ici, le run se termine en succès : les neuf étapes sont vertes, ce qui prouve que le pipeline est fonctionnel de bout en bout. »

**Grille visée** : Automatisation 15 %, qualité code (tests dbt), pipeline fonctionnel 5 %.

---

## Séquence 3 — Ingestion streaming Kafka (1:50 – 2:20)

**À l'écran**

1. Terminal :
   ```powershell
   cd docker
   docker compose exec redpanda rpk topic consume uniclos.orders.web -n 2
   ```
2. Laisser apparaître le JSON : `order_id`, `customer_email`, `channel`, `product_ref`, `amount_eur`, `order_timestamp`.

**À dire**

« Voici un événement tel qu'il transite sur le topic Kafka. Les données sont structurées en JSON : on retrouve l'identifiant de commande, le canal web ou app, la référence produit et le montant. Avant d'être écrit en base, chaque message passe par un validateur Python qui rejette les formats incorrects et envoie les erreurs vers une dead-letter queue. Cela garantit que seules des données conformes entrent dans la zone raw. »

**Grille visée** : 2.3 variété des données (JSON structuré), DQ à l'ingestion, 5.6 gestion erreurs.

---

## Séquence 4 — Raw → DWH en SQL (2:20 – 3:10)

**À l'écran**

1. Client SQL (psql ou DBeaver) connecté à `localhost:5433`, base `uniclothes`.
2. Exécuter une requête à la fois, laisser le résultat visible :

```sql
-- Landing zone
SELECT COUNT(*) AS total_raw FROM raw.streaming_orders;

SELECT order_id, channel, amount_eur, processed
FROM raw.streaming_orders
ORDER BY consumed_at DESC
LIMIT 5;

-- Entrepôt
SELECT COUNT(*) AS total_fact FROM dwh.fact_sales;

SELECT fs.order_id, dp.product_ref, dp.category, fs.amount_eur, dch.channel_name
FROM dwh.fact_sales fs
JOIN dwh.dim_product dp ON fs.product_key = dp.product_key
JOIN dwh.dim_channel dch ON fs.channel_key = dch.channel_key
ORDER BY fs.order_timestamp DESC
LIMIT 5;
```

**À dire**

« Dans PostgreSQL, la zone raw reçoit les événements validés : ici nous avons des centaines de lignes dans streaming_orders. La colonne processed indique si la commande a déjà été transformée. Après passage de dbt, les ventes sont enrichies dans le star schema : la table fact_sales joint les dimensions produit et canal. On voit bien le parcours ELT complet, de la landing zone jusqu'au data warehouse analytique. »

**Grille visée** : ETL/ELT, architecture 20 %, volume 2.1, pipeline fonctionnel.

---

## Séquence 5 — Data Quality (3:10 – 3:40)

**À l'écran**

1. Même client SQL :

```sql
SELECT metric_name, metric_value, target_value, status, measured_at
FROM staging.quality_metrics
ORDER BY measured_at DESC
LIMIT 6;
```

2. Optionnel : `SELECT COUNT(*) FROM raw.failed_events;`

**À dire**

« Les contrôles qualité post-chargement alimentent cette table quality_metrics. Chaque métrique compare une valeur mesurée à un seuil : taux de null, doublons, orphelins produit, ou volume d'événements en échec sur vingt-quatre heures. Quand un seuil est dépassé, le statut passe en alerte et Airflow oriente le run vers la branche d'alerte. Les messages invalides dès l'ingestion, eux, sont isolés dans failed_events pour ne pas polluer le DWH. »

**Grille visée** : Contrôle qualité 20 %, gouvernance, correction d'erreurs.

---

## Séquence 6 — Monitoring Grafana (3:40 – 4:10)

**À l'écran**

1. Navigateur : http://localhost:3002
2. Dashboard **Uniclos — Pipeline Temps Réel**
3. Montrer successivement :
   - Graphique **Événements consommés par run** (courbe non nulle)
   - Table **Historique runs pipeline** (`events_produced`, `events_consumed`, `dq_status = OK`)
   - Table **Derniers contrôles qualité**
   - Stat **pending vs total** commandes streaming

**À dire**

« Grafana agrège l'historique des exécutions stocké dans monitoring.pipeline_runs. Ce graphique montre le nombre d'événements consommés à chaque run : on confirme que l'ingestion est active. Le tableau liste les productions, consommations et le statut DQ. En bas à droite, le compteur pending indique combien de commandes raw attendent encore leur transformation. Cette observabilité permet de détecter rapidement un blocage dbt ou une anomalie qualité. »

**Grille visée** : Monitoring 10 %, surveillance des flux.

---

## Séquence 7 — RGPD et sécurité (4:10 – 4:40) *(recommandé, 30 s)*

**À l'écran**

1. Terminal (sans afficher le fichier `.env`) :
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\demo_rgpd.ps1
   ```
   Ou montrer uniquement la fin : comptages **avant** (1 client, N commandes) → **après** (0).

2. Option slide matrice rôles (analyst → vue anonymisée seulement).

**À dire**

« Côté conformité, les secrets sont centralisés dans un fichier env non versionné. Le rôle analyste n'accède qu'à une vue anonymisée des ventes. Le DPO peut exercer le droit d'accès et le droit à l'effacement : cette démo supprime le client de test dans staging, le DWH, et aussi le flux streaming, tout en traçant la demande dans audit.gdpr_requests. En production, j'ajouterais le chiffrement TLS et un secrets manager cloud. »

**Grille visée** : 3.1, 3.3, 3.5, 2.5 sécurité.

---

## Séquence 8 — Conclusion (4:40 – 5:00)

**À l'écran**

- Retour README GitHub ou slide « Livrables » : repo, docs, tests pytest, diagramme Draw.io.

**À dire (mot à mot)**

« En résumé, ce projet livre un pipeline temps réel complet pour Uniclos : ingestion Kafka, validation et dead-letter queue, transformation dbt incrémentale, tests automatisés, orchestration Airflow, monitoring Grafana, et procédures RGPD. Le code, les tests et la documentation sont disponibles sur GitHub. Merci de votre attention. »

**Grille visée** : livrables, synthèse globale.

---

## Checklist avant enregistrement

- [ ] `docker compose ps` → services Up
- [ ] Dernier run Airflow : 9 tâches vertes incluant `dbt_test`
- [ ] Grafana : `events_consumed` > 0 sur le dernier run
- [ ] `dwh.fact_sales` > 0 en SQL
- [ ] `scripts/render_config.ps1` exécuté (Grafana datasource OK)
- [ ] Micro coupé ou pièce silencieuse, pas de notification Windows
- [ ] Curseur agrandi, zoom navigateur 110 % si texte petit

---

## Mapping vidéo → critères d'évaluation (synthèse)

| Séquence | Durée | Critères grille couverts |
|----------|-------|--------------------------|
| Intro | 25 s | Présentation, contexte 1.1 |
| Docker ps | 35 s | Architecture, fiabilité 1.4 |
| Airflow | 50 s | Automatisation 15 %, tests, fonctionnel 5 % |
| Kafka JSON | 30 s | Variété données 2.3, DQ ingestion |
| SQL raw→DWH | 50 s | ETL/ELT, architecture 20 % |
| quality_metrics | 30 s | DQ 20 % |
| Grafana | 30 s | Monitoring 10 % |
| RGPD | 30 s | 3.1, 3.3, 3.5, sécurité 2.5 |
| Conclusion | 20 s | Livrables, clôture |

**Durée totale cible : 4 min 40 – 5 min**
