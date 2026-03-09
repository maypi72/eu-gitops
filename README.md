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
└── infra/
		├── apps-root.yaml
		├── ingress-values.yaml
		├── values/
		│   └── argocd-values.yaml
		└── scripts/
				├── install_k3s.sh
				├── deploy_ingress.sh
				└── deploy_argocd.sh
```

## Workflows

- `infra-k3s.yml`: instala/prepara K3s (incluyendo prerequisitos del clúster para el lab).
- `infra-lab.yml`: orquesta el flujo principal en este orden:
	1. K3s
	2. Lab (despliegue de Ingress con Helm y comprobaciones)
	3. Argo CD
- `infra-argocd.yml`: despliegue reutilizable de Argo CD con Helm.

## Rutas Importantes

- Scripts:
	- `infra/scripts/install_k3s.sh`
	- `infra/scripts/deploy_ingress.sh`
	- `infra/scripts/deploy_argocd.sh`
- Values:
	- `infra/ingress-values.yaml`
	- `infra/values/argocd-values.yaml`

Los scripts resuelven sus values por defecto en estas rutas:

- `infra/scripts/deploy_ingress.sh` -> `../ingress-values.yaml`
- `infra/scripts/deploy_argocd.sh` -> `../values/argocd-values.yaml`

## Ejecucion Recomendada

Lanzar `Infra Lab (K3s -> Ingress -> Argo CD)` mediante `workflow_dispatch`.

Este workflow ya encadena todo en orden y deja preparado el punto central (`infra-lab`) para añadir futuros despliegues/steps antes de Argo CD.

## Variables de Entorno/Repo (Opcionales)

- `ENABLE_K3S_INFRA`
- `ENABLE_ARGOCD_INFRA`
- `KUBECONFIG_PATH`

Si no se define `KUBECONFIG_PATH`, se usa por defecto `/etc/rancher/k3s/k3s.yaml` en los pasos del lab.
