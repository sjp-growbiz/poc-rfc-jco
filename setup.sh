#!/usr/bin/env bash
# Extrae el jar y la librería nativa de JCo desde el paquete de SAP.
# Ninguno de los dos se versiona: son software licenciado.
set -euo pipefail

ZIP="${1:-../sapjco31P_14-70004517.zip}"
[ -f "$ZIP" ] || { echo "No encuentro el paquete: $ZIP"; echo "Uso: ./setup.sh /ruta/sapjco31P_XX-XXXXXXXX.zip"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
echo "Extrayendo $ZIP"
unzip -q "$ZIP" -d "$TMP"

TGZ=$(find "$TMP" -name "sapjco3-*.tgz" | head -1)
[ -n "$TGZ" ] || { echo "El paquete no contiene el tgz esperado"; exit 1; }
echo "Paquete: $(basename "$TGZ")"

case "$(basename "$TGZ")" in
  *linuxx86_64*) ;;
  *) echo "AVISO: el paquete no es linuxx86_64. Verifica que coincida con la arquitectura del servidor." ;;
esac

tar xzf "$TGZ" -C "$TMP"
JAR=$(find "$TMP" -name sapjco3.jar | head -1)
SO=$(find "$TMP" -name libsapjco3.so | head -1)
[ -n "$JAR" ] && [ -n "$SO" ] || { echo "Falta sapjco3.jar o libsapjco3.so dentro del paquete"; exit 1; }

unzip -p "$JAR" META-INF/MANIFEST.MF > "$TMP/mf"
VER=$(tr -d '\r' < "$TMP/mf" | awk -F': ' '/Specification-Version/{print $2}' | head -1)
echo "Versión: $VER"

mkdir -p libs native
cp "$JAR" libs/sapjco3.jar
cp "$SO"  native/libsapjco3.so
file native/libsapjco3.so | sed 's/^/  /'

# Mantener el pom alineado con la versión que se acaba de instalar.
if grep -q "<sapjco.version>" pom.xml; then
  sed -i.bak "s|<sapjco.version>.*</sapjco.version>|<sapjco.version>${VER}</sapjco.version>|" pom.xml && rm -f pom.xml.bak
  echo "pom.xml actualizado a ${VER}"
fi

echo
echo "Listo. Siguiente paso: cp .env.example .env y completar los datos de Basis."
