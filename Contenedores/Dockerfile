FROM mongo:6.0

# instalamos openssl para poder generar keyfile en runtime (wrapper lo utilizará)
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# copiamos el script wrapper
COPY docker-entrypoint-genkey.sh /usr/local/bin/docker-entrypoint-genkey.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-genkey.sh

# dejamos el ENTRYPOINT al wrapper (luego ejecutará el entrypoint original)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-genkey.sh"]
CMD ["mongod"]
