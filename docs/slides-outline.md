# Plan slides — Soutenance Uniclos (5 min)

> Chaque slide : **texte à lire** (phrases complètes) + **visuel recommandé** + **critères grille visés**.

---

## Slide 1 — Titre et contexte métier (30 s)

**Texte à afficher / lire**

Uniclos est une enseigne de mode omnicanale qui réalise environ trente millions d'euros de chiffre d'affaires annuel via dix boutiques, un site web et une application mobile. Aujourd'hui, les données de vente arrivent en flux dispersés et le directionnel a besoin d'un chiffre d'affaires quasi live par canal. Ce projet Bloc 3 propose un pipeline temps réel complet qui ingère, transforme, contrôle et monitorer ces flux dans un entrepôt PostgreSQL.

**Visuel recommandé**

- Photo ou logo fictif Uniclos + carte de France avec 10 points boutique.
- Encadré « besoin métier » : *CA live · gouvernance · conformité RGPD*.

**Grille visée**

- 1.1 (adéquation au projet fictif), 4.1 (clarté), 4.2 (structure).

---

## Slide 2 — Architecture globale (45 s)

**Texte à afficher / lire**

L'architecture repose sur une stack légère conteneurisée, adaptée à une PME : Redpanda pour le streaming, PostgreSQL en modèle medallion, dbt pour l'ELT, Airflow pour l'orchestration, et Grafana pour l'observabilité. Les données structurées transitent en JSON Kafka ; les données semi-structurées sont stockées dans la colonne payload ; les images produit sont hébergées sur MinIO. Cette conception traite le volume attendu — environ trois cent mille commandes par an — avec une latence inférieure à trois minutes grâce à un micro-batch toutes les deux minutes.

**Visuel recommandé**

- **Diagramme principal** (Draw.io `architecture-globale.drawio`) : flux Sources → Redpanda → Raw → dbt → DWH → Grafana.
- Légende couleur par couche : ingestion / stockage / transformation / monitoring.
- Icônes Docker en bas de slide : « déploiement reproductible ».

**Grille visée**

- 1.1, 1.3 (volume, variété, vélocité), 2.1, 2.2, 2.3 (types de données), 2.5 (sécurité mentionnée slide 7).

---

## Slide 3 — Flux de données détaillé (45 s)

**Texte à afficher / lire**

Un producteur Python simule des commandes web et caisse POS toutes les deux minutes. Un consommateur valide chaque événement puis l'écrit dans la table `raw.streaming_orders`. dbt matérialise les vues staging et alimente de façon incrémentale la table `dwh.fact_sales` en joignant les dimensions client, produit, magasin et canal. Les commandes traitées sont marquées `processed = true` après les contrôles qualité.

**Visuel recommandé**

- **Schéma séquentiel horizontal** (5 blocs numérotés) avec flèches et noms de tables.
- Mini-capture JSON d'un événement Kafka (order_id, channel, amount_eur).
- Badge latence : *« objectif < 3 min »*.

**Grille visée**

- 1.2 (flexibilité du flux), 2.2 (vitesse), critère « pipeline fonctionnel » (5 %).

---

## Slide 4 — Automatisation et orchestration (40 s)

**Texte à afficher / lire**

Le DAG Airflow `uniclos_realtime_pipeline` enchaîne neuf tâches : production d'événements, consommation Kafka, exécution dbt, tests dbt, contrôles qualité, branche d'alerte et journalisation. Le planificateur déclenche ce DAG toutes les deux minutes et chaque tâche dispose de trois tentatives en cas d'échec. Cette automatisation garantit un traitement régulier sans intervention manuelle.

**Visuel recommandé**

- **Capture Airflow Graph View** avec toutes les tâches au vert (run récent).
- Sous-graphique : schedule `*/2 * * * *` + icône retry ×3.
- Liste verticale des task_id (produce → log_pipeline_run).

**Grille visée**

- Critère « Automatisation » (15 %), 1.4 (fiabilité via retries), 5.3 (structure code / DAG).

---

## Slide 5 — Data Quality et gestion d'erreurs (40 s)

**Texte à afficher / lire**

La qualité est contrôlée à deux niveaux. À l'ingestion, un validateur Python rejette les emails invalides, les montants incohérents et les références produit incorrectes ; les messages rejetés alimentent la dead-letter queue `raw.failed_events` et le topic Kafka DLQ. Après transformation, des métriques SQL alimentent `staging.quality_metrics`, et dbt exécute des tests `not_null`, `unique` et `relationships` sur les modèles staging et fact.

**Visuel recommandé**

- **Tableau à deux colonnes** : Règle | Seuil | Action (rejet DLQ vs alerte).
- Capture terminal ou SQL : une ligne dans `raw.failed_events` (optionnel).
- Capture Airflow : tâche `dbt_test` verte.

**Grille visée**

- Critère « Contrôle qualité des données » (20 %), 2.4 (continuité via DLQ), 5.6 (gestion erreurs).

---

## Slide 6 — Monitoring et observabilité (35 s)

**Texte à afficher / lire**

Chaque exécution du pipeline écrit une ligne dans `monitoring.pipeline_runs` avec le nombre d'événements produits, consommés, échoués et le statut DQ. Le dashboard Grafana « Uniclos — Pipeline Temps Réel » visualise l'historique des runs, les derniers contrôles qualité et le nombre de commandes streaming en attente. L'interface Airflow complète cette observabilité en montrant l'état de chaque tâche et la durée des runs.

**Visuel recommandé**

- **Capture Grafana** plein écran : graphique events consommés + table DQ + pending/total.
- Bandeau latéral : capture Airflow Grid (colonne verte récente).
- Flèche annotée : *« events_produced > 0 »* pour prouver le fix monitoring.

**Grille visée**

- Critère « Monitoring et observabilité » (10 %), 1.4 (disponibilité des données).

---

## Slide 7 — RGPD et sécurité (35 s)

**Texte à afficher / lire**

Les secrets applicatifs sont centralisés dans le fichier `docker/.env`, qui n'est pas versionné. PostgreSQL applique le principe du moindre privilège : le rôle analyste accède uniquement à la vue `dwh.v_sales_analytics`, sans PII en clair. Le DPO peut exporter ou effacer un client via les fonctions `audit.export_customer_gdpr` et `audit.delete_customer_gdpr`, qui purgent aussi le flux streaming. En production, j'activerais le chiffrement TLS et un gestionnaire de secrets cloud.

**Visuel recommandé**

- **Matrice rôles × accès** (ETL / Analyst / DPO / Grafana) — tableau simple 4 lignes.
- Capture terminal `demo_rgpd.ps1` : comptages avant/après effacement.
- Icône cadenas + mention « `.env` gitignore » (sans afficher de mot de passe).

**Grille visée**

- 2.5, 3.1, 3.3, 3.5 (RGPD accès/effacement), 3.2 (ISO/ANSSI : mesures documentées).

---

## Slide 8 — Démo, livrables et roadmap (30 s)

**Texte à afficher / lire**

Le code source est disponible sur GitHub avec la structure imposée : dossiers dags, sql, python, tests et documentation. La vidéo de démonstration montre le pipeline de bout en bout, de l'ingestion Kafka jusqu'au dashboard Grafana. La roadmap prévoit un déploiement cloud, du CDC Debezium depuis les caisses réelles, et le branchement du BI Streamlit du Bloc 2 sur le DWH temps réel.

**Visuel recommandé**

- QR code ou URL GitHub + miniature player vidéo.
- Timeline horizontale « Phase 1 (actuel) → Phase 2 (cloud + CDC) ».
- Slide de clôture : *« Merci — questions ? »*.

**Grille visée**

- 4.6 (supports visuels), 4.7 (timing 5 min), livrables officiels du sujet.

---

## Synthèse timing oral (5 min)

| Slide | Durée | Thème grille principal |
|-------|-------|------------------------|
| 1 | 30 s | Contexte métier |
| 2 | 45 s | Architecture (20 %) |
| 3 | 45 s | Flux / volume / vélocité |
| 4 | 40 s | Automatisation (15 %) |
| 5 | 40 s | DQ (20 %) |
| 6 | 35 s | Monitoring (10 %) |
| 7 | 35 s | Sécurité / RGPD |
| 8 | 30 s | Livrables + clôture |

**Total ≈ 5 min 20 s** — ajuster le rythme sur slides 2 et 5 si besoin.

---

## Préparation Q&R (15 min) — réponses en une phrase

**Pourquoi Redpanda plutôt qu'un cluster Kafka ?**  
Redpanda suffit pour le volume PME, s'installe en un conteneur Docker et expose l'API Kafka sans opérations lourdes.

**Comment scale-t-on si le volume triple ?**  
On partitionne les topics, on passe à l'exécution Airflow distribuée et on réplique PostgreSQL en lecture.

**Que se passe-t-il si dbt échoue ?**  
Airflow retente trois fois, les commandes restent `processed = false`, et Grafana montre des pending orders élevés.

**Comment gérez-vous le RGPD sur le flux temps réel ?**  
Les PII sont masquées en BI, et la fonction d'effacement purge raw, staging, DWH et journalise l'audit.

**Et la sécurité en production ?**  
TLS sur Kafka et PostgreSQL, secrets dans un vault, RBAC Airflow, et aucun mot de passe dans le dépôt Git.
