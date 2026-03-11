# Problema de Resolución de DID en Verificación de Credenciales

## Descripción del Problema

Cuando se verifica una credencial, el verificador debe resolver el DID del issuer para obtener el DID document y verificar la firma. Sin embargo, el verificador está obteniendo el DID document desde la instancia actual de certify (localhost:8090) en lugar de resolverlo desde el GitHub Page según la especificación `did:web`.

### Escenario

1. **Instancia anterior**: Se levantó una instancia de certify, se generó un `did.json` y se publicó en GitHub Pages
2. **Nueva instancia**: Se levantó una nueva instancia de certify (sin cambiar el GitHub Page), lo que generó un nuevo `did.json` con diferentes claves
3. **Resultado**: 
   - La credencial antigua (`old_credential`) falla al verificar
   - La credencial nueva (`new_credential`) verifica correctamente

### Comportamiento Esperado

- La credencial antigua debería verificar correctamente (porque el GitHub Page todavía tiene el `did.json` anterior con las claves antiguas)
- La credencial nueva debería fallar al verificar (porque el GitHub Page no tiene el `did.json` nuevo)

### Comportamiento Actual

- La credencial antigua falla al verificar
- La credencial nueva verifica correctamente

## Causa Raíz

El verificador está resolviendo el DID desde la instancia actual de certify (localhost:8090) en lugar de resolverlo desde el GitHub Page según la especificación `did:web`.

Según la especificación `did:web`, un DID como `did:web:andresbu93.github.io:inji-farmer-poc:did-rd` debe resolverse a:
```
https://andresbu93.github.io/inji-farmer-poc/did-rd/did.json
```

Sin embargo, el verificador parece estar obteniendo el DID document desde:
```
http://localhost:8090/v1/certify/issuance/.well-known/did.json
```

## Soluciones

### Solución 1: Verificar la Configuración del Verificador

Asegúrate de que el verificador esté configurado para resolver DIDs `did:web` correctamente según la especificación. El verificador debe:

1. Extraer el dominio del DID (`andresbu93.github.io`)
2. Construir la URL del DID document (`https://andresbu93.github.io/inji-farmer-poc/did-rd/did.json`)
3. Obtener el DID document desde esa URL

### Solución 2: Verificar el @context en el Template de la Credencial

Si el template de la credencial incluye la URL del `did.json` en el `@context`, asegúrate de que apunte al GitHub Page y no a localhost:

```json
{
    "@context": [
        "https://www.w3.org/2018/credentials/v1",
        "https://andresbu93.github.io/inji-farmer-poc/did-rd/did.json",
        "https://w3id.org/security/suites/ed25519-2020/v1"
    ],
    "issuer": "did:web:andresbu93.github.io:inji-farmer-poc:did-rd",
    ...
}
```

### Solución 3: Usar un Resolver de DID Público

Usa un resolver de DID público como [Uniresolver](https://dev.uniresolver.io/) para verificar que el DID se resuelve correctamente desde el GitHub Page.

### Solución 4: Verificar la Configuración del Verificador

Si estás usando un verificador específico (como Inji Verify), verifica que esté configurado para:
1. Resolver DIDs `did:web` según la especificación
2. No usar caché de DID documents que puedan estar desactualizados
3. No tener configuraciones que apunten a localhost:8090

## Recomendaciones

1. **Siempre publica el `did.json` en el GitHub Page** antes de emitir credenciales
2. **No cambies las claves** una vez que hayas publicado el `did.json` en el GitHub Page
3. **Usa diferentes DIDs** para diferentes instancias de certify si necesitas cambiar las claves
4. **Verifica la resolución del DID** usando un resolver público antes de emitir credenciales

## Verificación

Para verificar que el DID se resuelve correctamente:

```bash
# Verificar que el DID se resuelve desde el GitHub Page
curl https://andresbu93.github.io/inji-farmer-poc/did-rd/did.json

# Comparar con el DID document de la instancia actual
curl http://localhost:8090/v1/certify/issuance/.well-known/did.json
```

Si los dos documentos son diferentes, el verificador debe usar el primero (del GitHub Page) para verificar credenciales que tienen el issuer `did:web:andresbu93.github.io:inji-farmer-poc:did-rd`.






