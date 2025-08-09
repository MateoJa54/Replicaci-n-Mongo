#!/bin/bash
set -e

# Si no existe la llave, la generamos con openssl (base64 756 bytes)
if [ ! -f /etc/mongo-keyfile ]; then
  echo ">>> Generando /etc/mongo-keyfile dentro del contenedor..."
  openssl rand -base64 756 > /etc/mongo-keyfile
  chmod 400 /etc/mongo-keyfile
  chown root:root /etc/mongo-keyfile || true
  echo ">>> Keyfile creado."
else
  echo ">>> /etc/mongo-keyfile ya existe, no se genera."
fi

# Ejecutar el entrypoint original de la imagen oficial de mongo
exec /usr/local/bin/docker-entrypoint.sh "$@"
