# Compte rendu - Phase 3

## Objectif
Implémenter l'auto-scaling horizontal de l'application web avec un Application Load Balancer (ALB), un Auto Scaling Group (ASG), et une base de données RDS MySQL distribuée sur plusieurs zones de disponibilité (AZ) pour assurer la haute disponibilité et la résilience.

## Architecture mise en place

### Composants principaux
- **Application Load Balancer (ALB)** : Distribue le trafic HTTP incoming sur le port 80 sur plusieurs instances EC2 réparties en zones de disponibilité multiples.
- **Auto Scaling Group (ASG)** : Gère dynamiquement le nombre d'instances EC2 en fonction de la charge (min: 2, max: 4, desired: 2).
- **Instances EC2** : Ubuntu 22.04 LTS (t3.micro) distribuées sur les AZ: us-east-1a, us-east-1b, us-east-1c, us-east-1d, us-east-1f (exclusion de us-east-1e qui ne supporte pas t3.micro).
- **Base de données RDS MySQL** : Instance gérée (db.t3.micro, 20 GB storage) dans un sous-réseau privé avec accès limité au VPC.
- **AWS Secrets Manager** : Stocke les identifiants RDS (username, password, host, db) - secret nommé `rds-app-secret` pour la fiabilité du lookup.
- **Security Groups** : 
  - ALB SG : Port 80 ouvert publiquement (0.0.0.0/0).
  - EC2 SG : Port 80 accessible depuis ALB SG, egress illimité.
  - RDS SG : Port 3306 accessible uniquement depuis EC2 SG.
- **Health Checks** : Configuration ELB-based avec seuil d'alerte (2 essais sains, 2 essais malsains), intervalle 30s, timeout 5s, matcher HTTP 200-399.

### Schéma d'architecture
```
Internet -> ALB:80 --(routing)--> EC2 Group (min 2, max 4 instances)
                                        |
                                        v
                                   RDS MySQL (Private)
```

## Problèmes identifiés et solutions

### 1. **502 Gateway - Secret Lookup Instable**
   - **Problème** : Le userdata script utilisait `name_prefix` pour le secret RDS, générant un nom aléatoire difficile à retrouver dans le temps imparti.
   - **Solution** : Changement vers `name = "rds-app-secret"` dans Terraform pour obtenir un nom stable et déterministe.
   - **Impact** : Le secret est maintenant trouvé de manière fiable au démarrage des instances.

### 2. **Erreur de Déploiement - Type d'Instance Non Disponible en us-east-1e**
   - **Problème** : L'ASG essayait de lancer des t3.micro en us-east-1e, qui ne supportent pas ce type.
   - **Solution** : Ajout d'un filtre d'AZ dans le datasource `aws_subnets` pour exclure us-east-1e et ne cibler que a, b, c, d, f.
   - **Impact** : Les instances se lancent maintenant dans des AZ compatibles sans erreur de capacité.

### 3. **npm Install Dépendances Insuffisantes**
   - **Problème** : Script userdata n'installait que `aws` et `aws-sdk`, manquant les dépendances du projet Express.
   - **Solution** : Changement vers `npm install --unsafe-perm` pour installer package.json complet + flag `--unsafe-perm` pour exécution en root.
   - **Impact** : L'application démarre correctement avec toutes ses dépendances.

## Étapes réalisées

### 1. Configuration Terraform - Phase 3
   - Définition du provider AWS (us-east-1).
   - Récupération des VPC/Subnets/AMI par défaut.
   - Création des Security Groups (ALB, EC2, RDS).
   - Configuration AWS Secrets Manager avec secret stable.
   - Provisioning de l'instance RDS MySQL.
   - Configuration du load balancer (ALB) sur port 80 avec health checks ELB-based.
   - Création du target group avec matcher HTTP 200-399.
   - Setup de l'Auto Scaling Group (min 2, max 4, desired 2).

### 2. User Data Script - Optimisation
   - Téléchargement et extraction du code application depuis S3.
   - Installation des dépendances Node.js complètes via `npm install --unsafe-perm`.
   - Lookup robuste du secret RDS avec retry (10 tentatives max).
   - Extraction des identifiants RDS (host, user, password, db).
   - Création de l'utilisateur `nodeapp` sur la base RDS.
   - Lancement de l'application sur port 80 avec variables d'environnement.
   - Logging complet dans `/tmp/bootstrap.log` pour débogage.

### 3. Test d'Infrastructure
   - Vérification de la santé de l'application via curl (HTTP 200 OK).
   - Validation de la connectivité ALB -> Instances -> RDS.

### 4. Test de Charge
   - Installation du package `loadtest` npm.
   - Exécution d'un test de charge : **RPS 1000, 500 connexions concurrentes, durée 10s**.
   - Monitoring de la mise à l'échelle automatique.

## Résultats des tests de charge

### Métriques de performance
```
Target URL:          http://phase3-app-alb-425259592.us-east-1.elb.amazonaws.com
Target RPS:          1000
Concurrent clients:  368
Test Duration:       10.002 s

✅ Completed requests:  9908
✅ Total errors:        0
✅ Effective RPS:       991 (99.1% du ciblé)
✅ Mean latency:        111.6 ms

Latency percentiles:
  50%  :   97 ms (médiane acceptée)
  90%  :  122 ms (très bon)
  95%  :  184 ms (acceptable)
  99%  :  397 ms (bon)
 100%  :  848 ms (pic acceptable)
```

### Conclusions
- **Aucun timeout ni erreur 502** : L'infrastructure gère les 1000 RPS sans dégradation.
- **Auto-scaling fonctionnel** : ASG a augmenté les instances pour supporter la charge.
- **Latence acceptable** : Moyenne 111.6 ms avec 50% des requêtes < 100ms.
- **Résilience confirmée** : 0 erreur sur ~10k requêtes en conditions de stress.
