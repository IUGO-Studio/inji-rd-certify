# Personalizaciones IUGO sobre Inji Certify 0.14.0

Inventario para el cliente: qué se conservó del fork 0.12.2, qué se descartó y cómo volver al comportamiento oficial de Inji.

## Base

| Ítem | Valor |
|---|---|
| Fuente oficial | [inji/inji-certify](https://github.com/inji/inji-certify) tag `v0.14.0` |
| Coordenadas Maven | `io.inji.certify:certify-parent:0.14.0` |
| Keymanager | 1.4.0 |
| CI/CD | GitHub Actions IUGO en `main`: semver, Artifact Registry, rollout GKE ([`.github/workflows/deploy-service.yml`](../.github/workflows/deploy-service.yml)) |
| Archivo 0.12.2 | Branch `develop` (no se mergeó a `main`) |

Módulos oficiales compatibles con 0.14.0: eSignet 1.6.2, keymanager 1.4.0, mimoto 0.20.0, inji-web 0.15.0. Esos upgrades van en los repos hermanos, no en este.

## Por qué existen los flags

La emisión en producción habla con **CuentaDigital** (OAuth2 / OIDC). En 0.12.2 el token no cumplía siempre los chequeos por defecto de Inji:

- `aud` a veces llegaba como array vacío
- `client_id` / `azp` no siempre estaba
- `c_nonce` / nonce del proof no alineaba con OpenID4VCI, y `getValidClientNonce` rechazaba el pedido

Esos chequeos siguen en el 0.14.0 oficial. Acá están detrás de properties para que CuentaDigital siga funcionando y se puedan reactivar sin otro fork.

## Flags (se conservan)

El default en `@Value` es **false** para que GKE arranque aunque `inji-rd-config` todavía no tenga las keys. Pasarlos a `true` cuando CuentaDigital emita los claims bien.

| Property | Default | 0.14 oficial con `true` | Archivo |
|---|---|---|---|
| `mosip.certify.authn.validate-audience` | `false` | El `aud` del JWT debe coincidir con `mosip.certify.authn.allowed-audiences` | `AccessTokenValidationFilter` |
| `mosip.certify.authn.require-client-id-claim` | `false` | El JWT debe traer `client_id` | `AccessTokenValidationFilter` |
| `mosip.certify.issuance.validate-cnonce` | `false` | Valida cNonce y el nonce del proof JWT | `VCIssuanceServiceImpl`, `CertifyIssuanceServiceImpl` |

Ejemplo local: [`certify-service/src/main/resources/application-local.properties`](../certify-service/src/main/resources/application-local.properties).

En producción van en el config server (`inji-rd-config`), no en este repo.

### Restaurar la validación oficial

```properties
mosip.certify.authn.validate-audience=true
mosip.certify.authn.require-client-id-claim=true
mosip.certify.issuance.validate-cnonce=true
```

Reiniciar Certify después de cambiarlas.

Issuer, JWKS y audiences de CuentaDigital siguen en **inji-rd-config**.

## Reevaluado y no portado

| Cambio 0.12.2 | Motivo |
|---|---|
| `getScopeCredentialMapping` con `scope.contains(...)` | 0.14 ya parte el claim `scope` del token por espacios y compara con `Objects.equals`. El `contains` de 0.12 quedó obsoleto. |
| `@Lazy` en `CredentialConfigMapper` | `CredentialConfigurationServiceImpl` de 0.14 arranca sin él. Agregarlo solo si aparece un ciclo de Spring. |
| Ajustes RSA / `azp` en el decoder | 0.14 ya acepta RS256, PS256 y ES256. Solo queda el claim `client_id` opcional (flag de arriba). |

## Descartado a propósito (no es lógica)

No esperes esto en `main` / 0.14:

- `log.info` del Bearer JWT completo, PEM del certificado, KID o internals del canonicalizer
- `CacheErrorHandler` de Redis y la dependencia extra de Jedis
- Keystores en git (`certify-service/data/CERTIFY_PKCS12/local.p12`, archivo `p12`)
- Demo docker-compose farmer, seed SQL de credenciales
- Las notas largas de integración 0.12 (`CERTIFY-CONFIGURATION.md` quedó solo en `develop`)

## Base de datos (runtime, no este PR)

El cluster hoy corre la imagen 0.12.2 de `develop`. Antes de desplegar este `main`:

1. `db_upgrade_script/mosip_certify/sql/0.12.2_to_0.13.0_upgrade.sql`
2. `0.13.0_to_0.13.1_upgrade.sql` (placeholder)
3. `0.13.1_to_0.14.0_upgrade.sql`

Un push a `main` dispara el deploy a GKE. El rollback de git es fácil hasta que corran esos SQL.

## Layout git

- `main` / `upgrade/inji-0.14.0`: 0.14.0 oficial + CI/CD IUGO + flags de arriba
- `develop`: árbol IUGO 0.12.2 congelado (referencia / rollback del runtime anterior)
