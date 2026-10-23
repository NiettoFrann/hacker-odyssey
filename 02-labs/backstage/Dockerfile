# ┌──────────────────────────────────────────────────────────────┐
# │  SPOILER: este archivo contiene la solución del lab.           │
# │  No lo abras si querés resolver "Backstage" por tu cuenta.     │
# └──────────────────────────────────────────────────────────────┘
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apache2 openssh-server sudo ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ─── Usuario del sistema (movimiento lateral vía SSH) ───────────────
RUN useradd -m -s /bin/bash jmanning \
    && usermod -L jmanning \
    && mkdir -p /home/jmanning/.ssh \
    && chmod 700 /home/jmanning/.ssh
COPY setup/jmanning_authorized_keys /home/jmanning/.ssh/authorized_keys
RUN chmod 600 /home/jmanning/.ssh/authorized_keys \
    && chown -R jmanning:jmanning /home/jmanning/.ssh

# ─── Contenido web ──────────────────────────────────────────────────
COPY web/ /var/www/html/
RUN chown -R www-data:www-data /var/www/html

# ─── Autenticación básica del panel interno (misconfig 2: el backup
#     del .htpasswd quedó expuesto en /backup/htpasswd.bak) ───────────
COPY web/backup/htpasswd.bak /etc/apache2/.htpasswd
RUN chmod 644 /etc/apache2/.htpasswd

# ─── VirtualHost ────────────────────────────────────────────────────
COPY setup/000-backstage.conf /etc/apache2/sites-available/000-backstage.conf
RUN a2dissite 000-default >/dev/null \
    && a2ensite 000-backstage >/dev/null \
    && a2enmod authn_file authn_core authz_user auth_basic >/dev/null \
    && echo "ServerName backstage.lab" > /etc/apache2/conf-available/servername.conf \
    && a2enconf servername >/dev/null

# ─── Escalada de privilegios (sudo mal configurado: GTFOBin find) ────
RUN echo "jmanning ALL=(root) NOPASSWD: /usr/bin/find" > /etc/sudoers.d/jmanning \
    && chmod 440 /etc/sudoers.d/jmanning

# ─── Flags ──────────────────────────────────────────────────────────
COPY setup/user.flag /home/jmanning/user.txt
COPY setup/root.flag /root/root.txt
RUN chown jmanning:jmanning /home/jmanning/user.txt \
    && chmod 644 /home/jmanning/user.txt \
    && chown root:root /root/root.txt \
    && chmod 600 /root/root.txt

# ─── Arranque ───────────────────────────────────────────────────────
COPY setup/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
