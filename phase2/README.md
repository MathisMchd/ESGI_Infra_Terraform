# Compte rendu - Phase 2

## Objectif
Séparer les composants web et base de données, déployer une base gérée Amazon RDS MySQL, utiliser AWS Secrets Manager pour les identifiants et migrer les données existantes.

## Architecture mise en place
- VPC avec sous-réseaux publics et privés.
- Machine virtuelle EC2 Ubuntu pour l'application web dans un sous-réseau public.
- Base de données Amazon RDS MySQL dans un sous-réseau privé unique.
- Security groups : accès HTTP public pour le serveur web, accès MySQL limité au VPC et à l'application.
- AWS Cloud9 utilisé pour exécuter les commandes AWS CLI et migrer la base de données.
- AWS Secrets Manager pour stocker le secret DB (`user`, `password`, `host`, `db`) et éviter les identifiants codés en dur.
- IAM Instance Profile attaché à l'EC2 pour autoriser la lecture du secret depuis Secrets Manager.

## Schéma d'architecture

![alt text](<Diagramme - Phase 2.png>)


## Étapes réalisées
1. Création / mise à jour du réseau virtuel avec les sous-réseaux nécessaires.
2. Création d’une instance RDS MySQL gérée.
3. Déploiement d’un environnement AWS Cloud9 pour la gestion CLI.
4. Création d’un secret dans Secrets Manager avec le script AWS CLI adapté.
5. Déploiement d’une nouvelle instance EC2 pour héberger l’application web.
6. Configuration de l’application pour récupérer les identifiants depuis Secrets Manager.
7. Migration des données de l’ancienne base MySQL sur EC2 vers la nouvelle RDS via Cloud9.

## Résultats
- L’application web est accessible depuis Internet et fonctionne normalement.
- Les opérations CRUD (consultation, ajout, suppression, modification) sont fonctionnelles.
- La base RDS n’est pas exposée au public, seule l’EC2 dans le VPC y accède.
- Les identifiants DB ne sont plus codés en dur dans l’application.
- La migration a permis de conserver les données existantes depuis l’ancienne instance EC2 de la phase 1.

## Observations et points importants
Nous avons utilisé l’instance IAM `LabInstanceProfile` pour accorder à l’EC2 l’accès à Secrets Manager.
La principale difficulté a été de bien configurer les security groups sans se tromper et les sous-réseaux pour que l’EC2 puisse accéder à RDS sans exposer MySQL publiquement.
Nous avons également eu des difficultés pour "configurer l'application web" avec les secrets mais avec un peu de recherche et de lecture du code fourni, tout était bon.
Il a également fallu exécuter des commandes intermédiaires comme ```aws ec2 describe-instances``` pour récupérer des éléments comme l'ip de l'instance ec2 ou d'autres choses nécessaires.