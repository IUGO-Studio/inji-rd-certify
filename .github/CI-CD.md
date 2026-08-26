# CI/CD de este repo

Este repo tiene **dos capas de CI/CD** que no hay que confundir:

1. **Workflows heredados de MOSIP** — `push-trigger.yml`, `manual-docker-build.yml`,
   `chart-lint-publish.yml`, `codeql.yml`. Vienen del fork tal cual, corren en gran parte vía los reusable
   workflows de `mosip/kattu`, y no tienen ninguna relación con el cluster de este proyecto ni con lo que
   describe este documento.
2. **`deploy-service.yml`** — el pipeline propio de este fork. Es el único que le importa a alguien operando
   `inji-rd`, y es del que trata todo este documento.

## Qué dispara `deploy-service.yml`

Push a `main` que toque alguno de estos paths:

- `certify-service/**`
- `certify-core/**`
- `pom.xml`
- `.github/workflows/deploy-service.yml` (el propio workflow — un cambio ahí también se dispara a sí mismo)

## Qué hace, paso a paso

1. Checkout con `fetch-depth: 0` (necesita el historial completo para calcular la versión semántica).
2. Calcula una versión semántica a partir de los mensajes de commit (`paulhatch/semantic-version`).
3. Build con Maven (`mvn -B clean package -DskipTests`) — sin correr tests.
4. Autentica contra GCP con `google-github-actions/auth` usando el secret `GCP_SA_KEY` (una key de Service
   Account estática, **no** Workload Identity Federation como usa `inji-rd`).
5. Build y push de la imagen Docker a Artifact Registry, con 4 tags:
   - `us-central1-docker.pkg.dev/<GCP_PROJECT_ID>/<GAR_REPOSITORY>/inji-certify:latest`
   - `...:${{ github.sha }}`
   - `...:<version semántica>` (ej. `1.4.2`)
   - `...:<tag semántico>` (ej. `v1.4.2`)

   `GCP_PROJECT_ID` y `GAR_REPOSITORY` son **repository variables** (Settings → Secrets and variables →
   Actions → Variables), no secrets.
6. Crea un git tag con la versión semántica (solo si está en `main`; si el tag ya existe, lo ignora).
7. Se autentica contra el cluster `k8s-inji-dev` (`us-central1-a`) con las mismas credenciales del paso 4.
8. **`kubectl rollout restart deployment/inji-certify -n inji-certify`**, y espera a que termine
   (`kubectl rollout status ... --timeout=5m`).

## Por qué el paso 8 es un riesgo real

Ese último paso **no pasa por Helm ni por `inji-rd/inji-stack/deploy/`** — no vuelve a renderizar los values,
no reaplica el chart, simplemente reinicia el `Deployment` que ya está viviendo en el cluster con lo que sea
que el último `helm upgrade` haya dejado ahí (recoge la imagen `:latest` recién pusheada porque el
`imagePullPolicy` la vuelve a bajar en el restart).

Esto corre **sin ninguna coordinación** con quien esté operando el cluster desde `inji-rd`. Un push a `main`
en cualquier momento — incluso uno que solo toque un `.md` si por error quedara dentro del path filter, o
cualquier cambio real de código — reinicia el pod de `inji-certify` en `k8s-inji-dev`. Si estás en medio de
un deploy o de una sesión de debugging en vivo sobre ese namespace, este workflow te lo puede pisar sin que
se note por qué el pod se reinició.

**Si un pod se reinició sin que nadie haya tocado `inji-rd`**, revisá primero el historial de Actions de este
repo (pestaña Actions → `Deploy Certify Service`) antes de asumir que fue algo del lado de infra.

## Dónde encaja esto en el resto del stack

La imagen que este workflow pushea a `:latest` es la misma que consume
[`inji-rd/inji-stack/deploy/apps/certify.sh`](https://github.com/Nublit-by-Domus/inji-rd/blob/main/inji-stack/deploy/apps/certify.sh)
vía `IMAGE_REGISTRY` + `image.tag=latest` cuando alguien corre un `helm upgrade` completo desde ese repo. Los
dos caminos terminan escribiendo el mismo `Deployment`, por caminos completamente distintos y sin que uno
sepa del otro.
