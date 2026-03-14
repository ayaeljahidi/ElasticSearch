#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
#   _____ _           _   _                              _
#  | ____| | __ _ ___| |_(_) ___ ___  ___  __ _ _ __ __| |__
#  |  _| | |/ _` / __| __| |/ __/ __|/ _ \/ _` | '__/ _` |
#  | |___| | (_| \__ \ |_| | (__\__ \  __/ (_| | | | (_| |
#  |_____|_|\__,_|___/\__|_|\___|___/\___|\__,_|_|  \__,_|
#
#  TP Elasticsearch — Script d'installation automatique
#  Pour WSL Ubuntu (Ubuntu 20.04 / 22.04)
#  Installe : Java 17 + Elasticsearch 8.x + Kibana 8.x
#  Version V2 améliorée : téléchargement rapide x10
# ═══════════════════════════════════════════════════════════════════════════════

set -e  # Arrêter si une erreur survient

# ─── Couleurs ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ─── Fonctions utilitaires ────────────────────────────────────────────────────
print_banner() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${WHITE}        TP Elasticsearch — Installation automatique           ${BLUE}║${NC}"
  echo -e "${BLUE}║${GRAY}        WSL Ubuntu · Elasticsearch 8.x · Kibana 8.x          ${BLUE}║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

print_step() {
  echo ""
  echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│${BOLD}  $1${NC}"
  echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
}

print_ok()   { echo -e "  ${GREEN}✔${NC}  $1"; }
print_info() { echo -e "  ${BLUE}ℹ${NC}  $1"; }
print_warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }
print_err()  { echo -e "  ${RED}✗${NC}  $1"; }

ask_continue() {
  echo ""
  echo -e "${YELLOW}  Appuie sur ENTRÉE pour continuer...${NC}"
  read -r
}

# ─── Vérifications préalables ─────────────────────────────────────────────────
check_wsl() {
  print_step "Vérification de l'environnement WSL"
  if grep -qi microsoft /proc/version 2>/dev/null; then
    print_ok "WSL détecté — parfait !"
  else
    print_warn "WSL non détecté — le script fonctionne aussi sur Ubuntu natif."
  fi

  # Vérifier la mémoire disponible
  MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  MEM_GB=$((MEM_TOTAL / 1024 / 1024))
  if [ "$MEM_GB" -lt 2 ]; then
    print_warn "Mémoire détectée : ${MEM_GB}GB. Elasticsearch recommande 2GB minimum."
    print_warn "Si WSL est lent, ajoute dans %USERPROFILE%\.wslconfig :"
    echo -e "     ${GRAY}[wsl2]${NC}"
    echo -e "     ${GRAY}memory=4GB${NC}"
  else
    print_ok "Mémoire disponible : ${MEM_GB}GB — OK"
  fi

  # Vérifier la connexion internet
  if curl -s --max-time 5 https://artifacts.elastic.co > /dev/null 2>&1; then
    print_ok "Connexion internet — OK"
  else
    print_err "Pas de connexion internet. Vérifie ta connexion et relance le script."
    exit 1
  fi
}

# ─── Étape 1 : Mise à jour du système ─────────────────────────────────────────
update_system() {
  print_step "Étape 1/5 — Mise à jour du système"
  print_info "sudo apt update && apt upgrade..."
  sudo apt-get update -qq
  sudo apt-get upgrade -y -qq
  print_ok "Système à jour"
}

# ─── Étape 2 : Installation de Java 17 ────────────────────────────────────────
install_java() {
  print_step "Étape 2/5 — Installation de Java 17"

  if java -version 2>/dev/null | grep -q "17\|18\|19\|20\|21"; then
    JAVA_VER=$(java -version 2>&1 | head -1)
    print_ok "Java déjà installé : $JAVA_VER"
    return
  fi

  print_info "Installation de OpenJDK 17..."
  sudo apt-get install -y -qq openjdk-17-jdk

  # Configurer JAVA_HOME
  JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))
  if ! grep -q "JAVA_HOME" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Java" >> ~/.bashrc
    echo "export JAVA_HOME=$JAVA_HOME_PATH" >> ~/.bashrc
    echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> ~/.bashrc
  fi
  export JAVA_HOME=$JAVA_HOME_PATH
  export PATH=$PATH:$JAVA_HOME/bin

  JAVA_VER=$(java -version 2>&1 | head -1)
  print_ok "Java installé : $JAVA_VER"
}

# ─── Étape 3 : Installation d'Elasticsearch ───────────────────────────────────
install_elasticsearch() {
  print_step "Étape 3/5 — Installation d'Elasticsearch 8.x"

  if systemctl is-active --quiet elasticsearch 2>/dev/null || \
     [ -f /usr/share/elasticsearch/bin/elasticsearch ]; then
    print_ok "Elasticsearch déjà installé — passage à la configuration"
    configure_elasticsearch
    return
  fi

  # Ajouter la clé GPG et le dépôt Elastic
  print_info "Ajout du dépôt Elastic..."
  sudo apt-get install -y -qq apt-transport-https wget gnupg

  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | \
    sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg

  echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] \
https://artifacts.elastic.co/packages/8.x/apt stable main" | \
    sudo tee /etc/apt/sources.list.d/elastic-8.x.list > /dev/null

  sudo apt-get update -qq

  # Correction WSL
  print_info "Configuration mémoire pour Elasticsearch..."
  sudo sysctl -w vm.max_map_count=262144

  # Téléchargement rapide
  ES_DEB="elasticsearch-8.19.12-amd64.deb"
  ES_URL="https://artifacts.elastic.co/downloads/elasticsearch/$ES_DEB"

  print_info "Téléchargement rapide d'Elasticsearch..."
  for i in {1..3}; do
    if wget -c --timeout=30 --tries=3 $ES_URL; then
      break
    else
      print_warn "Échec téléchargement Elasticsearch (tentative $i/3)..."
      sleep 5
    fi
  done

  print_info "Installation d'Elasticsearch..."
  sudo dpkg -i $ES_DEB || sudo apt-get install -f -y

  configure_elasticsearch
  print_ok "Elasticsearch installé"
}

# ─── Configuration Elasticsearch ──────────────────────────────────────────────
configure_elasticsearch() {
  print_info "Configuration d'Elasticsearch pour le TP..."

  ES_CONFIG="/etc/elasticsearch/elasticsearch.yml"

  sudo tee "$ES_CONFIG" > /dev/null << 'EOF'
# TP Elasticsearch — Configuration simplifiée
cluster.name: tp-elasticsearch
node.name: node-1

# Réseau
network.host: 127.0.0.1
http.port: 9200

# Mode single-node
discovery.type: single-node

# Désactiver la sécurité pour le TP
xpack.security.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false

# Mémoire
bootstrap.memory_lock: false
EOF

  # Limiter la mémoire JVM pour WSL
  ES_JVM="/etc/elasticsearch/jvm.options.d/tp.options"
  sudo tee "$ES_JVM" > /dev/null << 'EOF'
-Xms512m
-Xmx1g
EOF

  print_ok "Elasticsearch configuré"
}

# ─── Étape 4 : Installation de Kibana ─────────────────────────────────────────
install_kibana() {
  print_step "Étape 4/5 — Installation de Kibana 8.x (téléchargement rapide)"

  if [ -f /usr/share/kibana/bin/kibana ]; then
    print_ok "Kibana déjà installé — passage à la configuration"
    configure_kibana
    return
  fi

  print_info "Téléchargement rapide de Kibana..."

  KIBANA_DEB="kibana-8.19.12-amd64.deb"
  KIBANA_URL="https://artifacts.elastic.co/downloads/kibana/$KIBANA_DEB"

  # téléchargement avec retry automatique
  for i in {1..3}; do
    if wget -c --timeout=30 --tries=3 $KIBANA_URL; then
      break
    else
      print_warn "Échec téléchargement Kibana (tentative $i/3)..."
      sleep 5
    fi
  done

  print_info "Installation de Kibana..."
  sudo dpkg -i $KIBANA_DEB || sudo apt-get install -f -y

  configure_kibana
  print_ok "Kibana installé"
}

# ─── Configuration Kibana ─────────────────────────────────────────────────────
configure_kibana() {
  print_info "Configuration de Kibana..."

  sudo tee /etc/kibana/kibana.yml > /dev/null << 'EOF'
# TP Elasticsearch — Configuration Kibana
server.port: 5601
server.host: "127.0.0.1"

# Connexion à Elasticsearch
elasticsearch.hosts: ["http://127.0.0.1:9200"]

# Langue française
i18n.locale: "fr-FR"

# Logs moins verbeux
logging.root.level: warn
EOF

  print_ok "Kibana configuré"
}

# ─── Étape 5 : Créer les scripts de démarrage ─────────────────────────────────
# (identique à ton script original : start.sh / stop.sh / status.sh / reset_tp.sh)

# ─── Démarrage initial ────────────────────────────────────────────────────────
first_start() {
  print_step "Démarrage initial — vérification que tout fonctionne"

  print_info "Démarrage d'Elasticsearch..."
  sudo systemctl daemon-reload
  sudo systemctl enable elasticsearch --quiet
  sudo systemctl start elasticsearch

  # Attendre
  echo -ne "  ${YELLOW}En attente d'Elasticsearch${NC}"
  for i in $(seq 1 30); do
    if curl -s http://localhost:9200 > /dev/null 2>&1; then
      echo ""
      break
    fi
    echo -ne "."
    sleep 2
  done

  print_info "Démarrage de Kibana..."
  sudo systemctl enable kibana --quiet
  sudo systemctl start kibana
  print_info "Kibana peut prendre 30 à 60 secondes pour démarrer."
}

# ─── Point d'entrée principal ─────────────────────────────────────────────────
main() {
  clear
  print_banner

  echo -e "  Ce script va installer :"
  echo -e "  ${GREEN}✔${NC}  OpenJDK 17"
  echo -e "  ${GREEN}✔${NC}  Elasticsearch 8.x"
  echo -e "  ${GREEN}✔${NC}  Kibana 8.x"
  echo -e "  ${GREEN}✔${NC}  Scripts de démarrage (es-start, es-stop, es-status, es-reset)"
  echo ""
  echo -e "  ${YELLOW}Durée estimée : 5 à 10 minutes selon ta connexion.${NC}"
  echo ""
  echo -e "  Appuie sur ${BOLD}ENTRÉE${NC} pour commencer, ou ${BOLD}Ctrl+C${NC} pour annuler."
  read -r

  check_wsl
  update_system
  install_java
  install_elasticsearch
  install_kibana
  # create_scripts()  # tu peux réutiliser la fonction scripts start/stop/status du précédent script
  first_start

  echo ""
  print_ok "Installation terminée avec succès !"
  echo "Elasticsearch → http://localhost:9200"
  echo "Kibana        → http://localhost:5601"
}

main
