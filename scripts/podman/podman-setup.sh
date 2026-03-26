#!/usr/bin/env bash
set -euo pipefail

echo "Podman-Container-Setup – ohne systemd, nur Bash. Los geht's."

# Defaults
DEFAULT_NAME="mybox"
DEFAULT_IMAGE="ubuntu:24.04"
DEFAULT_USER="user"
DEFAULT_PASS="secret"
DEFAULT_PORTS="2222:22" # host:container
DEFAULT_ENV="MYAPP_DEBUG=1"
DEFAULT_PKGS="bash screen vim sed git openssh-server curl dnsutils net-tools iputils-ping"
DEFAULT_PERL="libwww-perl libjson-perl libdbd-sqlite3-perl" # Beispiel – ändere nach Bedarf

# Abfragen
read -p "Container-Name : " NAME
NAME=${NAME:-$DEFAULT_NAME}

read -p "Basis-Image : " IMAGE
IMAGE=${IMAGE:-$DEFAULT_IMAGE}

read -p "Benutzername im Container : " USER
USER=${USER:-$DEFAULT_USER}

read -s -p "Passwort für $USER : " PASS
echo
PASS=${PASS:-$DEFAULT_PASS}

read -p "SSH-Port (host:container) : " PORTS
PORTS=${PORTS:-$DEFAULT_PORTS}

read -p "Extra ENV-Vars (z.B. KEY=VAL KEY2=VAL2) : " ENV
ENV=${ENV:-$DEFAULT_ENV}

read -p "Pakete zum Installieren : " PKGS
PKGS=${PKGS:-$DEFAULT_PKGS}

read -p "Perl-Module (libfoo-perl etc.) : " PERL
PERL=${PERL:-$DEFAULT_PERL}

# Podman-Volume für Persistenz (Home + SSH)
podman volume create "${NAME}-home" || true

# Dockerfile on-the-fly erstellen (weil wir custom wollen)
cat > Dockerfile.${NAME} <<EOF
FROM ${IMAGE}

RUN apt-get update && apt-get install -y ${PKGS} ${PERL} && \
 apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash ${USER} && \
 echo "${USER}:${PASS}" | chpasswd && \
 mkdir -p /home/${USER}/.ssh && chmod 700 /home/${USER}/.ssh

# SSH aktivieren
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
 sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
 echo "Port 22" >> /etc/ssh/sshd_config

# ENV setzen
$(echo "$ENV" | sed 's/ /\\nENV /g' | sed 's/^/ENV /')

CMD ["/usr/sbin/sshd", "-D"]
EOF

# Builden
echo "Baue Image..."
podman build -t "${NAME}:latest" -f Dockerfile.${NAME} .

# Starten – rootless, mit Port-Forward, Volume, Env
echo "Starte Container..."
podman run -d \
 --name "${NAME}" \
 -p "${PORTS}" \
 -v "${NAME}-home:/home/${USER}" \
 $(echo "$ENV" | sed 's/[^ ]*=[^ ]*/--env &/g') \
 "${NAME}:latest"

echo
echo "Fertig! Verbinde dich mit:"
echo " ssh ${USER}@localhost -p ${PORTS%%:*}"
echo " Passwort: ${PASS}"
echo " (oder scp, git clone etc. – alles drin)"
echo "Stoppen: podman stop ${NAME}"
