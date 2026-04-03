# ESGI INFRA TERRAFORM

## À faire

1. Ouvrir un terminal dans ce dossier.
2. Vérifier tes identifiants AWS.
3. Lancer Terraform.

4. Lancer les commandes suivantes

```bash
terraform init
terraform apply
```

## Debug

Si erreur suivante :
```text
Error: Retrieving AWS account details: validating provider credentials: retrieving caller identity from STS: operation error STS: GetCallerIdentity, https response error StatusCode: 403, RequestID: 6de50a0a-3c9d-4cc4-b8d0-1ae6d31f6cf8, api error ExpiredToken: The security token included in the request is expired
```

Alors identifiants AWS expirés.

Lancer :

```bash
aws configure
```

Ensuite, retaper les informations AWS demandées :
- AWS Access Key ID
- AWS Secret Access Key
- Default region name

Puis relancer :

```bash
terraform init
terraform apply
```

## Vérification

Si la commande `terraform apply` se termine sans erreur, l'infrastructure est créée et l'output donne l'ip de l'instance.
