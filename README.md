# eu-gitops

Repositorio GitOps para laboratorio K3s con despliegue de infraestructura base en GitHub Actions.

## Estructura

```text
.
├── .github/workflows/
│   ├── infra-k3s.yml
│   ├── infra-lab.yml
│   └── infra-argocd.yml
├── apps/
│   └── listmonk/
│       ├── argo-rollouts.yaml
│       ├── listmonk-dev.yaml
│       └── listmonk-pro.yaml
└── infra/
	├── apps-root.yaml
	├── charts/
	│   └── listmonk/
	│       ├── Chart.yaml
	│       ├── values.yaml
	│       ├── values-dev.yaml
	│       ├── values-pro.yaml
	│       └── templates/
	├── ingress-values.yaml
	├── values/
	│   ├── argocd-values.yaml
	│   ├── cert-manager-values.yaml
	│   ├── sealed-secrets-values.yaml
	│   └── trivy-values.yaml
	└── scripts/
		├── install_k3s.sh
		├── deploy_ingress.sh
		├── install_cert_manager.sh
		├── install_sealed_secrets.sh
		├── install_trivy.sh
		└── deploy_argocd.sh
```

## Workflows

- `infra-k3s.yml`: instala/prepara K3s (incluyendo prerequisitos del clúster para el lab).
- `infra-lab.yml`: orquesta el flujo principal en este orden:
	1. K3s
	2. Ingress NGINX
	3. cert-manager
	4. Sealed Secrets
	5. Trivy Operator
	6. Argo CD
- `infra-argocd.yml`: despliegue reutilizable de Argo CD con Helm.

## Rutas Importantes

- Scripts:
	- `infra/scripts/install_k3s.sh`
	- `infra/scripts/deploy_ingress.sh`
	- `infra/scripts/install_cert_manager.sh`
	- `infra/scripts/install_sealed_secrets.sh`
	- `infra/scripts/install_trivy.sh`
	- `infra/scripts/deploy_argocd.sh`
- ArgoCD Apps:
	- `apps/listmonk/argo-rollouts.yaml`
	- `apps/listmonk/listmonk-dev.yaml`
	- `apps/listmonk/listmonk-pro.yaml`
- Helm Charts:
	- `infra/charts/listmonk`
- Values:
	- `infra/ingress-values.yaml`
	- `infra/values/argocd-values.yaml`
	- `infra/values/cert-manager-values.yaml`
	- `infra/values/sealed-secrets-values.yaml`
	- `infra/values/trivy-values.yaml`

Los scripts resuelven sus values por defecto en estas rutas:

- `infra/scripts/deploy_ingress.sh` -> `../ingress-values.yaml`
- `infra/scripts/install_cert_manager.sh` -> `../values/cert-manager-values.yaml`
- `infra/scripts/install_sealed_secrets.sh` -> `../values/sealed-secrets-values.yaml`
- `infra/scripts/install_trivy.sh` -> `../values/trivy-values.yaml`
- `infra/scripts/deploy_argocd.sh` -> `../values/argocd-values.yaml`

## Ejecucion Recomendada

Lanzar `Infra Lab (K3s -> Ingress -> Cert-Manager -> Sealed-Secrets -> Trivy -> Argo CD)` mediante `workflow_dispatch`.

Flujo actual: `K3s -> Ingress -> cert-manager -> Sealed Secrets -> Trivy -> Argo CD`.

Este workflow ya encadena todo en orden y deja preparado el punto central (`infra-lab`) para añadir futuros despliegues/steps antes de Argo CD.

## Variables de Entorno/Repo (Opcionales)

- `ENABLE_K3S_INFRA`
- `ENABLE_ARGOCD_INFRA`
- `KUBECONFIG_PATH`

Si no se define `KUBECONFIG_PATH`, se usa por defecto `/etc/rancher/k3s/k3s.yaml` en los pasos del lab.
