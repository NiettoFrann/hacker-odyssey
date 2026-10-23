# ┌──────────────────────────────────────────────────────────────┐
# │  SPOILER: este archivo contiene la solución del lab.           │
# │  No lo abras si querés resolver "Foundry" por tu cuenta.       │
# └──────────────────────────────────────────────────────────────┘
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx openssh-server python3 zip libcap2-bin ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ─── Usuario del sistema (acceso inicial por SSH con clave) ─────────
RUN useradd -m -s /bin/bash builder \
    && usermod -L builder \
    && mkdir -p /home/builder/.ssh \
    && chmod 700 /home/builder/.ssh

# ─── Par de claves del "pipeline de build". La privada acaba dentro
#     del artefacto .zip publicado por error; la pública autoriza el
#     acceso de builder. La clave NO tiene passphrase (misconfig). ───
RUN ssh-keygen -t rsa -b 2048 -N "" -C "builder@foundry" -f /tmp/id_rsa \
    && cp /tmp/id_rsa.pub /home/builder/.ssh/authorized_keys \
    && chmod 600 /home/builder/.ssh/authorized_keys \
    && chown -R builder:builder /home/builder/.ssh

# ─── Contenido web (portal público del build server) ───────────────
COPY web/ /var/www/html/
RUN chown -R www-data:www-data /var/www/html

# ─── MISCONFIG: el .zip de artefactos quedó publicado en /artifacts/
#     (listado de directorio activo) y está protegido con una
#     contraseña DÉBIL, crackeable offline con rockyou. Dentro va la
#     clave privada de builder y una nota con el usuario. ────────────
RUN printf 'Artefacto de build interno de Foundry.\n\nClave de mantenimiento del pipeline (no distribuir).\nUsuario del host para despliegues: builder\n\n  ssh -i id_rsa builder@<host>\n' > /tmp/NOTES.txt \
    && cd /tmp \
    && zip -P princess -q /var/www/html/artifacts/build-artifacts.zip id_rsa NOTES.txt \
    && rm -f /tmp/id_rsa /tmp/id_rsa.pub /tmp/NOTES.txt \
    && chown -R www-data:www-data /var/www/html/artifacts

# ─── VirtualHost de nginx ───────────────────────────────────────────
COPY setup/foundry.conf /etc/nginx/sites-available/foundry
RUN rm -f /etc/nginx/sites-enabled/default \
    && ln -s /etc/nginx/sites-available/foundry /etc/nginx/sites-enabled/foundry

# ─── Escalada de privilegios: CAPABILITY cap_setuid en el intérprete
#     de Python. getcap -r / lo revela; GTFOBins (capabilities) permite
#     os.setuid(0) y lanzar una shell de root. ─────────────────────────
RUN setcap cap_setuid+ep "$(readlink -f /usr/bin/python3)"

# ─── Flags ──────────────────────────────────────────────────────────
COPY setup/user.flag /home/builder/user.txt
COPY setup/root.flag /root/root.txt
RUN chown builder:builder /home/builder/user.txt \
    && chmod 644 /home/builder/user.txt \
    && chown root:root /root/root.txt \
    && chmod 600 /root/root.txt

# ─── Arranque ───────────────────────────────────────────────────────
COPY setup/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
