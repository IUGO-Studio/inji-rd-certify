#!/bin/bash

# Script para verificar la resolución de DID y diagnosticar problemas de verificación

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
DID="did:web:andresbu93.github.io:inji-farmer-poc:did-rd"
LOCAL_DID_ENDPOINT="http://localhost:8090/v1/certify/issuance/.well-known/did.json"
GITHUB_PAGES_BASE="https://andresbu93.github.io/inji-farmer-poc/did-rd"

echo "=========================================="
echo "Verificación de Resolución de DID"
echo "=========================================="
echo ""
echo "DID: $DID"
echo ""

# Función para convertir did:web a URL
did_to_url() {
    local did=$1
    # did:web:domain:path1:path2 -> https://domain/path1/path2/did.json
    local domain=$(echo $did | sed 's/did:web://' | cut -d: -f1)
    local path=$(echo $did | sed 's/did:web:[^:]*://' | sed 's/:/\/ /g')
    echo "https://$domain/$path/did.json"
}

GITHUB_DID_URL=$(did_to_url "$DID")
echo "URL esperada del GitHub Page: $GITHUB_DID_URL"
echo ""

# Verificar DID document desde GitHub Pages
echo "1. Verificando DID document desde GitHub Pages..."
if curl -s -f "$GITHUB_DID_URL" > /tmp/github_did.json 2>/dev/null; then
    echo -e "${GREEN}✓${NC} DID document obtenido desde GitHub Pages"
    GITHUB_DID_ID=$(cat /tmp/github_did.json | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "   ID del DID: $GITHUB_DID_ID"
else
    echo -e "${RED}✗${NC} No se pudo obtener el DID document desde GitHub Pages"
    echo "   URL: $GITHUB_DID_URL"
    exit 1
fi

echo ""

# Verificar DID document desde instancia local
echo "2. Verificando DID document desde instancia local..."
if curl -s -f "$LOCAL_DID_ENDPOINT" > /tmp/local_did.json 2>/dev/null; then
    echo -e "${GREEN}✓${NC} DID document obtenido desde instancia local"
    LOCAL_DID_ID=$(cat /tmp/local_did.json | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    echo "   ID del DID: $LOCAL_DID_ID"
else
    echo -e "${YELLOW}⚠${NC} No se pudo obtener el DID document desde instancia local"
    echo "   URL: $LOCAL_DID_ENDPOINT"
    echo "   (Esto es normal si la instancia no está corriendo)"
fi

echo ""

# Comparar los dos documentos
if [ -f /tmp/github_did.json ] && [ -f /tmp/local_did.json ]; then
    echo "3. Comparando DID documents..."
    if diff -q /tmp/github_did.json /tmp/local_did.json > /dev/null; then
        echo -e "${GREEN}✓${NC} Los DID documents son idénticos"
    else
        echo -e "${YELLOW}⚠${NC} Los DID documents son diferentes"
        echo ""
        echo "   Diferencias encontradas:"
        diff /tmp/github_did.json /tmp/local_did.json | head -20
        echo ""
        echo -e "${RED}PROBLEMA DETECTADO:${NC}"
        echo "   El verificador debe usar el DID document del GitHub Page"
        echo "   para verificar credenciales con issuer: $DID"
        echo ""
        echo "   Si el verificador está usando el DID document de localhost:8090,"
        echo "   las credenciales antiguas fallarán porque tienen claves diferentes."
    fi
fi

echo ""

# Verificar verification methods
if [ -f /tmp/github_did.json ]; then
    echo "4. Verification methods en el DID document del GitHub Page:"
    cat /tmp/github_did.json | grep -o '"verificationMethod":\[[^]]*\]' | head -1
    echo ""
fi

# Limpiar archivos temporales
rm -f /tmp/github_did.json /tmp/local_did.json

echo "=========================================="
echo "Recomendaciones:"
echo "=========================================="
echo "1. Asegúrate de que el verificador resuelva el DID desde el GitHub Page"
echo "2. No cambies las claves una vez publicado el did.json en GitHub Pages"
echo "3. Usa diferentes DIDs para diferentes instancias si necesitas cambiar claves"
echo "4. Verifica la resolución usando: https://dev.uniresolver.io/"
echo ""






