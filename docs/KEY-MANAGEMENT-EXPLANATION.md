# Explicación del Manejo de Claves y KID en Certify

## Pregunta del Usuario

¿Por qué el `kid` (Key ID) es el mismo en la nueva credencial cuando debería ser diferente si se generaron nuevas claves?

## Respuesta

### Cómo Funciona el Keymanager

El keymanager en Certify:

1. **Almacena las claves en una base de datos** (tabla `key_store`)
2. **Identifica las claves por `appId` y `refId`** (no por el contenido de la clave)
3. **Reutiliza claves existentes** cuando `force=false` en `generateMasterKey`

### Flujo de Generación de Claves

Cuando Certify se inicia, en `AppConfig.initKeys()`:

```java
KeyPairGenerateRequestDto ed25519Req = new KeyPairGenerateRequestDto();
ed25519Req.setApplicationId(Constants.CERTIFY_VC_SIGN_ED25519);
ed25519Req.setReferenceId(Constants.ED25519_REF_ID);
ed25519Req.setForce(false);  // ← Esto es importante
keymanagerService.generateECSignKey("certificate", ed25519Req);
```

Con `force=false`, el keymanager:
- **Si ya existe una clave** para ese `appId` y `refId` → **reutiliza la clave existente**
- **Si no existe** → **genera una nueva clave**

### Cómo se Determina el KID

El `kid` viene del keymanager y se obtiene así:

```java
// En DIDDocumentUtil.java línea 75
AllCertificatesDataResponseDto kidResponse = keymanagerService.getAllCertificates(appId, refId);

// El kid viene del certificado almacenado
String kid = certificateData.getKeyId();
```

El `kid` se genera basado en:
- El certificado almacenado en la base de datos
- Identificado por `appId` y `refId`
- **NO se regenera** si la clave se reutiliza

### ¿Por Qué el KID es el Mismo?

**Escenario 1: Misma Base de Datos**

Si estás usando la misma base de datos para ambas instancias de Certify:

1. Primera instancia: Genera clave → Almacena en BD con `kid = "DJ2K0c2JWMZrup731Y7n7AMhkBgAUlVoRnFGonhhNOI"`
2. Segunda instancia: Busca clave existente → Encuentra la misma clave → Reutiliza → **Mismo `kid`**

**Problema**: Si las claves son diferentes pero el `kid` es el mismo, significa que:
- El keymanager está generando nuevas claves
- Pero el `kid` se está generando de manera determinística (posiblemente basado en `appId` + `refId`)
- O hay un problema con cómo el keymanager genera el `kid`

**Escenario 2: Diferentes Bases de Datos**

Si estás usando diferentes bases de datos:

1. Primera instancia: Genera clave → Almacena en BD1 con `kid = "DJ2K0c2JWMZrup731Y7n7AMhkBgAUlVoRnFGonhhNOI"`
2. Segunda instancia: Genera nueva clave → Almacena en BD2 → **Debería tener un `kid` diferente**

Si el `kid` es el mismo en este caso, hay un problema con la generación del `kid`.

### Verificación

Para verificar qué está pasando:

1. **Verifica si estás usando la misma base de datos**:
   ```bash
   # Revisa la configuración de la base de datos
   grep -r "spring.datasource.url" docker-compose/docker-compose-injistack/config/
   ```

2. **Verifica las claves almacenadas**:
   ```sql
   -- Conecta a la base de datos y verifica
   SELECT id, app_id, ref_id, cert_thumbprint, cr_dtimes 
   FROM certify.key_store 
   WHERE app_id = 'CERTIFY_VC_SIGN_ED25519' 
   AND ref_id = 'ED25519_SIGN';
   ```

3. **Compara los certificados**:
   - Obtén el certificado de la primera instancia
   - Obtén el certificado de la segunda instancia
   - Compara si son iguales o diferentes

### Solución

Si necesitas generar nuevas claves con nuevos `kid`:

1. **Usa `force=true`** al generar las claves:
   ```java
   ed25519Req.setForce(true);  // Fuerza la generación de nuevas claves
   ```

2. **Usa diferentes `appId` o `refId`** para diferentes instancias

3. **Usa diferentes bases de datos** para diferentes instancias

### Conclusión

El `kid` es el mismo porque:
- El keymanager está reutilizando las mismas claves (misma base de datos)
- O el `kid` se genera de manera determinística basado en `appId` + `refId`

Si las claves son diferentes pero el `kid` es el mismo, esto es un problema que debe investigarse en el keymanager.






