Proyecto: Replicación MongoDB + ETL (Olist) — Instrucciones para reproducir el entorno
Este README explica exactamente cómo clonar el repo, levantar los 3 contenedores MongoDB (replica set), importar los CSV limpios que están en data/, y comprobar/mostrar replicación y failover — en Windows (PowerShell). También incluye opciones para producción (keyfile + auth). Sigue los pasos tal cual para que a tus compañeros les funcione igual que a ti.

Estructura del repositorio (esperada)
pgsql
Copiar
Editar
Contenedores/
├─ data/                                 # CSVs limpios (no subir datos privados)
│   ├─ olist_customers_dataset.csv
│   ├─ olist_geolocation_dataset.csv
│   ├─ olist_order_items_dataset.csv
│   ├─ olist_order_payments_dataset.csv
│   ├─ olist_order_reviews_dataset.csv
│   ├─ olist_orders_dataset.csv
│   ├─ olist_products_dataset.csv
│   ├─ olist_sellers_dataset.csv
│   └─ product_category_name_translation.csv
├─ docker-compose.yml
├─ Dockerfile                             # opcional (si usas generación de keyfile)
├─ docker-entrypoint-genkey.sh            # opcional
├─ init-replica.js
├─ import_all.ps1                         # script simple para importar
├─ import_all_fix.ps1                     # script que detecta ';' y convierte
├─ import_all_log/                        # (opcional) logs de import
└─ README.md                              # este archivo
Requisitos / recomendaciones
Sistema: Windows 10/11 (se recomienda WSL2).

Docker Desktop instalado y configurado en Linux containers.

Verificar: docker info --format '{{.OSType}}' → debe devolver linux.

PowerShell (usar la terminal en la carpeta Contenedores).

(Opcional) mongosh y mongoimport si prefieres ejecutarlos desde el host. No es necesario si usas docker exec.

Recomendado: WSL2 para evitar problemas de permisos con keyfile.

No subir archivos sensibles (keyfile) al repo público.

Variables y contraseñas (valores por defecto usados en los ejemplos)
Cambia estas contraseñas si subes a un repositorio compartido. Las usamos sólo para pruebas locales.

ini
Copiar
Editar
ADMIN_USER=admin
ADMIN_PASS=AdminPass123!

ETL_USER=etl_writer
ETL_PASS=WriterPass123!

READ_USER=readonly_user
READ_PASS=ReadOnly123!
Modo rápido (temporal) — arranca sin autenticación (útil para pruebas locales y entrega rápida)
Este es el modo que usaste y el más sencillo para que todos repliquen exactamente tu entorno. Es inseguro (no usar en producción), pero funciona sin problemas en Windows.

Clonar repo y situarse en la carpeta:

powershell
Copiar
Editar
git clone <URL-del-repo>
cd Contenedores
Asegúrate de que docker-compose.yml NO contiene --keyFile ni --auth en command (o usa la versión que te entregaron para prueba sin auth). Ejemplo mínimo de command:

yaml
Copiar
Editar
command: ["--replSet", "rs0", "--bind_ip_all"]
Levantar contenedores:

powershell
Copiar
Editar
docker-compose up -d
docker ps
Inicializar replica set:

powershell
Copiar
Editar
docker exec -i mongo1 mongosh < init-replica.js
docker exec -it mongo1 mongosh --eval "rs.status()"
Salida esperada: mongo1 como PRIMARY, otros SECONDARY.

Importar CSVs (si quieres reimportar todo):

Para importar todo con la conversión automática (detecta ; y crea .fixed.csv), ejecutar:

powershell
Copiar
Editar
.\import_all_fix.ps1
Si ya importaste manualmente, verifica conteos:

powershell
Copiar
Editar
docker exec -it mongo1 mongosh --eval "const db=db.getSiblingDB('olist_ecommerce'); db.getCollectionNames().forEach(c=>print(c+':', db[c].countDocuments()));"
Verificar replicación y prueba de escritura:

powershell
Copiar
Editar
# Insert de prueba
docker exec -it mongo1 mongosh --eval "db.getSiblingDB('olist_ecommerce').test.insertOne({ok:true,ts:new Date()})"
# Ver en secundaria (habilitar lectura en secondary)
docker exec -it mongo2 mongosh --eval "rs.secondaryOk(); print(db.getSiblingDB('olist_ecommerce').test.countDocuments())"
Demo failover:

powershell
Copiar
Editar
docker stop mongo1
# Esperar 10-30s
docker exec -it mongo2 mongosh --eval "rs.status().members.forEach(m=>print(m.name,m.stateStr))"
# Reiniciar
docker start mongo1
# (Opcional) Forzar stepDown en el primary actual:
docker exec -it mongo2 mongosh --eval "rs.stepDown(60)"
Modo seguro (recomendado para entrega final) — keyfile + auth
Si prefieren activar autenticación y mantener la replicación segura, sigan estos pasos después de haber validado en modo rápido.

Opción A — generar keyfile en runtime dentro del contenedor (recomendado en Windows)
Incluye estos archivos en repo: Dockerfile y docker-entrypoint-genkey.sh. El entrypoint crea /etc/mongo-keyfile con permisos POSIX correctos dentro del contenedor.

Dockerfile (ejemplo):

dockerfile
Copiar
Editar
FROM mongo:6.0
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*
COPY docker-entrypoint-genkey.sh /usr/local/bin/docker-entrypoint-genkey.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-genkey.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-genkey.sh"]
CMD ["mongod"]
docker-entrypoint-genkey.sh (ejemplo):

bash
Copiar
Editar
#!/bin/bash
set -e
if [ ! -f /etc/mongo-keyfile ]; then
  openssl rand -base64 756 > /etc/mongo-keyfile
  chmod 400 /etc/mongo-keyfile
  chown root:root /etc/mongo-keyfile || true
fi
exec /usr/local/bin/docker-entrypoint.sh "$@"
Luego, en docker-compose.yml usar build: . (y en command incluir --keyFile /etc/mongo-keyfile --auth cuando actives auth).

Opción B — generar keyfile en el host (menos recomendable en Windows)
Crear mongo-keyfile en WSL2 con openssl rand -base64 756 > mongo-keyfile && chmod 400 mongo-keyfile y montarlo. Evitar en Windows puro: causa errores de permisos.

Crear usuarios y activar --auth (después de generar keyfile)
Con mongosh en mongo1 (sin auth aún) crear usuarios:

js
Copiar
Editar
use admin
db.createUser({user:"admin", pwd:"AdminPass123!", roles:[{role:"root",db:"admin"}]})
db.createUser({user:"etl_writer", pwd:"WriterPass123!", roles:[{role:"readWrite", db:"olist_ecommerce"},{role:"dbAdmin",db:"olist_ecommerce"}]})
db.createUser({user:"readonly_user", pwd:"ReadOnly123!", roles:[{role:"read", db:"olist_ecommerce"}]})
Editar docker-compose.yml para añadir --keyFile /etc/mongo-keyfile y --auth en command en cada servicio, luego:

powershell
Copiar
Editar
docker-compose down
docker-compose up -d
Verificar conexión autenticada:

powershell
Copiar
Editar
docker exec -it mongo1 mongosh -u admin -p AdminPass123! --authenticationDatabase admin --eval "db.runCommand({connectionStatus:1})"
Importar datos con usuario etl_writer:

powershell
Copiar
Editar
# ejemplo con mongoimport dentro del contenedor
docker exec -it mongo1 bash -c "mongoimport --username etl_writer --password WriterPass123! --authenticationDatabase admin --db olist_ecommerce --collection orders --type csv --file /data/olist_orders_dataset.csv --headerline --writeConcern majority"
Scripts incluidos (qué hacen y cómo usarlos)
import_all_fix.ps1 — recorre data/*.csv, detecta ; y lo convierte a comas, copia al contenedor y ejecuta mongoimport --writeConcern majority --drop. Ejecutar en PowerShell:

powershell
Copiar
Editar
.\import_all_fix.ps1
import_all.ps1 — import simple sin conversión.

powershell
Copiar
Editar
.\import_all.ps1
init-replica.js — script para rs.initiate() con prioridades (mongo1 prioridad mayor).

Comandos de verificación rápida (copiar/pegar)
Conteos por colección (primary):

powershell
Copiar
Editar
docker exec -it mongo1 mongosh --eval "const db=db.getSiblingDB('olist_ecommerce'); db.getCollectionNames().forEach(c=>print(c+':', db[c].countDocuments()));"
Estado del replica set:

powershell
Copiar
Editar
docker exec -it mongo1 mongosh --eval "rs.status().members.forEach(m=>print(m.name, m.stateStr))"
Lag (optime):

powershell
Copiar
Editar
docker exec -it mongo1 mongosh --eval "
const s = rs.status();
const prim = s.members.find(m=>m.stateStr=='PRIMARY').optimeDate;
s.members.forEach(m => print(m.name, m.stateStr, 'optime:', m.optimeDate, 'lag(s)=', Math.round((prim-new Date(m.optimeDate))/1000)));
"
Failover demo (stop/start):

powershell
Copiar
Editar
docker stop mongo1
# esperar, comprobar nuevo primary en mongo2
docker exec -it mongo2 mongosh --eval "rs.status().members.forEach(m=>print(m.name,m.stateStr))"
# volver a levantar
docker start mongo1
Troubleshooting rápido (errores comunes y soluciones)
Contenedores se cierran y logs muestran permissions on /etc/mongo-keyfile are too open
→ No montar keyfile desde Windows; usar la estrategia del entrypoint o construir la imagen con keyfile dentro (ver sección Modo seguro).

Logs: error opening file: /etc/mongo-keyfile: bad file
→ Si copiaste keyfile desde Windows, convíertelo a formato Unix/UTF-8 o genera el keyfile dentro del contenedor.

mongoimport no carga filas (colección con 0)
→ Revisar delimitador (, vs ;) y encoding/BOM. Usa import_all_fix.ps1 para convertir automáticamente.

Conexión desde host a secundario
→ Usa localhost:27018 y localhost:27019 (puertos mapeados en docker-compose).

Docker en Windows en modo Windows containers
→ Cambia a Linux containers en Docker Desktop.

.gitignore recomendado (añádelo al repo)
bash
Copiar
Editar
# datos y recibos de importación
mongo-keyfile
mongo1_data/
mongo2_data/
mongo3_data/
import_all_log/
.env
Qué entregar en el repo / qué deben revisar tus compañeros al clonar
docker-compose.yml, init-replica.js, import_all_fix.ps1 y data/ con CSVs limpios.

(Opcional) Dockerfile y docker-entrypoint-genkey.sh si van a usar modo seguro.

Añadir al README los pasos de arriba y ejemplo de comandos para la demo de failover.

Si quieres, yo:

Puedo generar un README.md listo con los comandos exactos (te lo dejo aquí para pegar).

O generar los archivos Dockerfile y docker-entrypoint-genkey.sh listos para que los añadas al repo y, si quieres, te doy el docker-compose.yml final para modo seguro.

¿Quieres que te cree ahora el Dockerfile + docker-entrypoint-genkey.sh y un .gitignore listo para pegar en tu repo?