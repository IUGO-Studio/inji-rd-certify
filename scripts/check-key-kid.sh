#!/bin/bash

# Script para verificar las claves y KIDs almacenados en la base de datos

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración de base de datos (ajusta según tu configuración)
DB_HOST="${DB_HOST:-database}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-inji_certify}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-postgres}"

APP_ID="CERTIFY_VC_SIGN_ED25519"
REF_ID="ED25519_SIGN"

echo "=========================================="
echo "Verificación de Claves y KIDs"
echo "=========================================="
echo ""
echo "App ID: $APP_ID"
echo "Ref ID: $REF_ID"
echo ""

# Función para ejecutar consultas SQL
run_sql() {
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -A -c "$1"
}

# Verificar claves almacenadas
echo "1. Verificando claves almacenadas en key_store..."
KEYS=$(run_sql "SELECT id, app_id, ref_id, cert_thumbprint, cr_dtimes FROM certify.key_store WHERE app_id = '$APP_ID' AND ref_id = '$REF_ID' ORDER BY cr_dtimes DESC;")

if [ -z "$KEYS" ]; then
    echo -e "${YELLOW}⚠${NC} No se encontraron claves para App ID: $APP_ID, Ref ID: $REF_ID"
else
    echo -e "${GREEN}✓${NC} Claves encontradas:"
    echo "$KEYS" | while IFS='|' read -r id app_id ref_id thumbprint cr_dtimes; do
        echo "   ID: $id"
        echo "   Thumbprint: $thumbprint"
        echo "   Creado: $cr_dtimes"
        echo ""
    done
fi

echo ""

# Verificar key_alias (que contiene los KIDs)
echo "2. Verificando KIDs en key_alias..."
ALIASES=$(run_sql "SELECT id, app_id, ref_id, cert_thumbprint, uni_ident, key_gen_dtimes FROM certify.key_alias WHERE app_id = '$APP_ID' AND ref_id = '$REF_ID' ORDER BY key_gen_dtimes DESC;")

if [ -z "$ALIASES" ]; then
    echo -e "${YELLOW}⚠${NC} No se encontraron aliases para App ID: $APP_ID, Ref ID: $REF_ID"
else
    echo -e "${GREEN}✓${NC} Aliases encontrados:"
    echo "$ALIASES" | while IFS='|' read -r id app_id ref_id thumbprint uni_ident key_gen_dtimes; do
        echo "   ID: $id"
        echo "   Thumbprint: $thumbprint"
        echo "   Uni Ident: $uni_ident"
        echo "   Generado: $key_gen_dtimes"
        echo ""
    done
fi

echo ""

# Verificar si hay múltiples claves con el mismo app_id y ref_id
echo "3. Verificando duplicados..."
DUPLICATES=$(run_sql "SELECT COUNT(*) FROM certify.key_store WHERE app_id = '$APP_ID' AND ref_id = '$REF_ID';")

if [ "$DUPLICATES" -gt 1 ]; then
    echo -e "${YELLOW}⚠${NC} Se encontraron $DUPLICATES claves para el mismo App ID y Ref ID"
    echo "   Esto puede causar problemas si se están reutilizando claves"
else
    echo -e "${GREEN}✓${NC} Se encontró 1 clave para App ID: $APP_ID, Ref ID: $REF_ID"
fi

echo ""

# Verificar certificados desde el endpoint de Certify
echo "4. Verificando certificados desde el endpoint de Certify..."
if curl -s -f "http://localhost:8090/v1/certify/system-info/certificate?applicationId=$APP_ID&referenceId=$REF_ID" > /tmp/certificate.json 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Certificado obtenido desde el endpoint"
    if command -v jq &> /dev/null; then
        KID=$(cat /tmp/certificate.json | jq -r '.keyId // .kid // empty')
        if [ -n "$KID" ]; then
            echo "   KID desde endpoint: $KID"
        fi
    fi
else
    echo -e "${YELLOW}⚠${NC} No se pudo obtener el certificado desde el endpoint"
    echo "   (Esto es normal si la instancia no está corriendo)"
fi

echo ""

# Comparar con el DID document
echo "5. Verificando KID en el DID document..."
if curl -s -f "http://localhost:8090/v1/certify/issuance/.well-known/did.json" > /tmp/did.json 2>/dev/null; then
    echo -e "${GREEN}✓${NC} DID document obtenido"
    if command -v jq &> /dev/null; then
        KIDS=$(cat /tmp/did.json | jq -r '.verificationMethod[]?.id // empty' | grep -o '[^#]*$')
        if [ -n "$KIDS" ]; then
            echo "   KIDs en verificationMethod:"
            echo "$KIDS" | while read -r kid; do
                echo "   - $kid"
            done
        fi
    fi
else
    echo -e "${YELLOW}⚠${NC} No se pudo obtener el DID document"
fi

echo ""

# Limpiar archivos temporales
rm -f /tmp/certificate.json /tmp/did.json

echo "=========================================="
echo "Recomendaciones:"
echo "=========================================="
echo "1. Si el KID es el mismo pero las claves son diferentes, verifica:"
echo "   - ¿Estás usando la misma base de datos?"
echo "   - ¿El keymanager está generando el KID de manera determinística?"
echo ""
echo "2. Si necesitas nuevas claves con nuevos KIDs:"
echo "   - Usa force=true al generar las claves"
echo "   - O usa diferentes appId/refId para diferentes instancias"
echo ""






