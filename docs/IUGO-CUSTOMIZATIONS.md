# IUGO customizations on Inji Certify 0.14.0

This document is the client-facing inventory of what IUGO kept from the 0.12.2 fork, what was dropped, and how to restore official Inji behavior.

## Base

| Item | Value |
|---|---|
| Official source | [inji/inji-certify](https://github.com/inji/inji-certify) tag `v0.14.0` |
| Maven coordinates | `io.inji.certify:certify-parent:0.14.0` |
| Keymanager | 1.4.0 |
| CI/CD | IUGO GitHub Actions on `main`: semantic version, Artifact Registry, GKE rollout ([`.github/workflows/deploy-service.yml`](../.github/workflows/deploy-service.yml)) |
| 0.12.2 archive | Branch `develop` (not merged into `main`) |

Compatible official modules for 0.14.0: eSignet 1.6.2, keymanager 1.4.0, mimoto 0.20.0, inji-web 0.15.0. Those sibling upgrades are out of this certify repo.

## Why the flags exist

Production issuance talks to **CuentaDigital** (OAuth2 / OIDC). On 0.12.2 the token did not always satisfy Inji's default checks:

- `aud` sometimes arrived as an empty array
- `client_id` / `azp` was not always present
- `c_nonce` / proof nonce was not aligned with OpenID4VCI, so `getValidClientNonce` rejected the request

Those checks are still in official 0.14.0. They are gated here so CuentaDigital keeps working, and so they can be turned back on without another code change.

## Flags (keep)

Defaults are **false** in `@Value` so GKE works before `inji-rd-config` is updated. Set them to `true` when CuentaDigital emits the claims correctly.

| Property | Default | Official 0.14 when `true` | File |
|---|---|---|---|
| `mosip.certify.authn.validate-audience` | `false` | JWT `aud` must match `mosip.certify.authn.allowed-audiences` | `AccessTokenValidationFilter` |
| `mosip.certify.authn.require-client-id-claim` | `false` | JWT must include `client_id` | `AccessTokenValidationFilter` |
| `mosip.certify.issuance.validate-cnonce` | `false` | Validates cNonce and the proof JWT nonce | `VCIssuanceServiceImpl`, `CertifyIssuanceServiceImpl` |

Local example: [`certify-service/src/main/resources/application-local.properties`](../certify-service/src/main/resources/application-local.properties).

Production belongs in the config server (`inji-rd-config`), not in this repo.

### Restore official validation

```properties
mosip.certify.authn.validate-audience=true
mosip.certify.authn.require-client-id-claim=true
mosip.certify.issuance.validate-cnonce=true
```

Restart Certify after changing them.

## Re-evaluated and not ported

| 0.12.2 change | Reason |
|---|---|
| `getScopeCredentialMapping` used `scope.contains(...)` | 0.14 already splits the token `scope` claim on spaces and matches each token with `Objects.equals`. The 0.12 substring hack is obsolete. |
| `@Lazy` on `CredentialConfigMapper` | 0.14 `CredentialConfigurationServiceImpl` starts without it. Add only if a circular dependency shows up at boot. |
| RSA / `azp` decoder tweaks | 0.14 already accepts RS256, PS256 and ES256. Only the optional `client_id` claim remains (flag above). |

## Dropped on purpose (not logic)

Do **not** expect these on `main` / 0.14:

- `log.info` of the full Bearer JWT, certificate PEM, KID, or canonicalizer internals
- Redis `CacheErrorHandler` and extra Jedis dependency
- Keystores committed in git (`certify-service/data/CERTIFY_PKCS12/local.p12`, blob file `p12`)
- docker-compose farmer demo, `certify_init.sql` credential seed, dataprovider JARs in git
- Long 0.12 integrator notes (`CERTIFY-CONFIGURATION.md` lived only on `develop`)

## Still required outside this repo

Certify 0.14 will not fetch identity data by itself. Choose one:

1. Keep the IUGO REST data-provider plugin on the container `loader_path`, or
2. Move to the official MOSIP Identity plugin shipped with 0.14 (`digital-credential-plugin` v0.6.0)

CuentaDigital issuer, JWKS and audiences stay in **inji-rd-config**.

## Database (runtime, not this PR)

The cluster today runs the 0.12.2 develop image. Before deploying this `main`:

1. `db_upgrade_script/mosip_certify/sql/0.12.2_to_0.13.0_upgrade.sql`
2. `0.13.0_to_0.13.1_upgrade.sql` (placeholder)
3. `0.13.1_to_0.14.0_upgrade.sql`

Pushing `main` triggers GKE deploy. Rollback of git is easy until those SQL scripts run.

## Git layout

- `main` / `upgrade/inji-0.14.0`: official 0.14.0 + IUGO CI/CD + flags above
- `develop`: frozen 0.12.2 IUGO tree (reference / rollback of the previous runtime)
