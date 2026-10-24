# ┌──────────────────────────────────────────────────────────────┐
# │  SPOILER: este archivo contiene la solución del lab.           │
# │  No lo abras si querés resolver "Switchboard" por tu cuenta.   │
# └──────────────────────────────────────────────────────────────┘
FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apache2 openssh-server git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ─── Usuario del sistema. Accede por SSH con CONTRASEÑA (la misma que
#     quedó filtrada en el historial de git). Pertenece al grupo
#     especial "shadow": ese es el vector de escalada. ───────────────
RUN useradd -m -s /bin/bash -g users operator \
    && usermod -aG shadow operator \
    && echo 'operator:superman' | chpasswd

# ─── Contraseña de root: débil a propósito. Su hash sha512crypt vive
#     en /etc/shadow y es crackeable offline con rockyou una vez que
#     operator (grupo shadow) puede leer el archivo. ─────────────────
RUN echo 'root:iloveyou' | chpasswd -c SHA512

# ─── Contenido web (panel de operaciones legacy) ───────────────────
COPY web/ /var/www/html/
RUN chown -R www-data:www-data /var/www/html

# ─── MISCONFIG: la carpeta .git del proyecto se desplegó dentro del
#     webroot. En el árbol actual el secreto ya "se borró", pero sigue
#     vivo en el HISTORIAL. Reconstruimos ese historial aquí. ─────────
RUN git config --global user.email "ci@switchboard.lab" \
    && git config --global user.name "switchboard-ci" \
    && git config --global init.defaultBranch main \
    && git init -q /tmp/repo \
    && cd /tmp/repo \
    && cp /var/www/html/index.html index.html \
    && git add index.html && git commit -q -m "init: panel de operaciones" \
    && printf '#!/bin/bash\n# Despliegue del panel al host de operaciones.\n# TODO: mover esto a un secreto del CI, no versionarlo.\nSSH_USER="operator"\nSSH_PASS="superman"\nscp -r ./dist "$SSH_USER"@switchboard:/var/www/html\n' > deploy.sh \
    && git add deploy.sh && git commit -q -m "add: script de despliegue" \
    && git rm -q deploy.sh && git commit -q -m "fix: quitar credenciales del repo" \
    && cp -r /tmp/repo/.git /var/www/html/.git \
    && rm -rf /tmp/repo \
    && chown -R www-data:www-data /var/www/html/.git

# ─── Autenticación básica del panel (sin relación con la escalada;
#     solo da color al recon). ─────────────────────────────────────
COPY setup/000-switchboard.conf /etc/apache2/sites-available/000-switchboard.conf
RUN a2dissite 000-default >/dev/null \
    && a2ensite 000-switchboard >/dev/null \
    && echo "ServerName switchboard.lab" > /etc/apache2/conf-available/servername.conf \
    && a2enconf servername >/dev/null

# ─── Flags ──────────────────────────────────────────────────────────
COPY setup/user.flag /home/operator/user.txt
COPY setup/root.flag /root/root.txt
RUN chown operator:users /home/operator/user.txt \
    && chmod 644 /home/operator/user.txt \
    && chown root:root /root/root.txt \
    && chmod 600 /root/root.txt

# ─── Arranque ───────────────────────────────────────────────────────
COPY setup/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 80 22
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
