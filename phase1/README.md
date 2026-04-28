# Phase 1

Ici le déploiement est automatisé via Terraform d'une instance Amazon EC2 Ubuntu de type t2.micro. Dans cette partie, l'instance héberge une application Express (Node.js) et une base de donnée MySql (port 3306).


![Terraform Phase 1](Terraform.drawio.png)



# EC2 

L'instance héberge à la fois le serveur web (Node.js) et la base de données (MySQL). Les deux communiquent localement sur le port 3306.

# Accès 

L'application est exposée sur Internet via le port 80 (HTTP), géré par un Security Group qui permet de sécurisé les flux entrants et sortant. Pour notre exemple on a laissé ouvert pour que cela soit plus simple (limitation du réseau de l'école).