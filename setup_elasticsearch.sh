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
  print_info "Installation d'Elasticsearch (peut prendre 2-3 minutes)..."
  sudo apt-get install -y elasticsearch

  configure_elasticsearch
  print_ok "Elasticsearch installé"
}

# ─── Configuration Elasticsearch ──────────────────────────────────────────────
configure_elasticsearch() {
  print_info "Configuration d'Elasticsearch pour le TP..."

  ES_CONFIG="/etc/elasticsearch/elasticsearch.yml"

  # Désactiver la sécurité (pour le TP uniquement)
  sudo tee "$ES_CONFIG" > /dev/null << 'EOF'
# TP Elasticsearch — Configuration simplifiée
cluster.name: tp-elasticsearch
node.name: node-1

# Réseau
network.host: 127.0.0.1
http.port: 9200

# Mode single-node (pas de cluster distribué pour le TP)
discovery.type: single-node

# Désactiver la sécurité pour le TP (NE PAS FAIRE EN PRODUCTION)
xpack.security.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false

# Mémoire (adapté pour WSL)
bootstrap.memory_lock: false
EOF

  # Limiter la mémoire JVM pour WSL (1GB max)
  ES_JVM="/etc/elasticsearch/jvm.options.d/tp.options"
  sudo tee "$ES_JVM" > /dev/null << 'EOF'
# Limiter la mémoire pour WSL
-Xms512m
-Xmx1g
EOF

  print_ok "Elasticsearch configuré"
}

# ─── Étape 4 : Installation de Kibana ─────────────────────────────────────────
install_kibana() {
  print_step "Étape 4/5 — Installation de Kibana 8.x"

  if [ -f /usr/share/kibana/bin/kibana ]; then
    print_ok "Kibana déjà installé — passage à la configuration"
    configure_kibana
    return
  fi

  print_info "Installation de Kibana (peut prendre 2-3 minutes)..."
  sudo apt-get install -y kibana

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
create_scripts() {
  print_step "Étape 5/5 — Création des scripts de démarrage"

  SCRIPTS_DIR="$HOME/elasticsearch-tp"
  mkdir -p "$SCRIPTS_DIR"

  # ── Script de démarrage ────────────────────────────────────────────────────
  cat > "$SCRIPTS_DIR/start.sh" << 'STARTSCRIPT'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${BOLD}${WHITE}           TP Elasticsearch — Démarrage                      ${NC}${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Démarrer Elasticsearch
echo -e "${CYAN}[1/2]${NC} Démarrage d'Elasticsearch..."
sudo systemctl start elasticsearch

# Attendre qu'Elasticsearch soit prêt
echo -e "     ${YELLOW}En attente d'Elasticsearch...${NC}"
MAX_WAIT=60
WAITED=0
while ! curl -s http://localhost:9200 > /dev/null 2>&1; do
  sleep 2
  WAITED=$((WAITED + 2))
  if [ $WAITED -ge $MAX_WAIT ]; then
    echo -e "     ${RED}✗  Elasticsearch n'a pas démarré en ${MAX_WAIT}s${NC}"
    echo -e "     ${YELLOW}Lance : sudo journalctl -u elasticsearch -n 50${NC}"
    exit 1
  fi
  echo -ne "     \r${YELLOW}En attente... (${WAITED}s)${NC}   "
done
echo -e "\n     ${GREEN}✔  Elasticsearch prêt sur http://localhost:9200${NC}"

# Démarrer Kibana
echo ""
echo -e "${CYAN}[2/2]${NC} Démarrage de Kibana..."
sudo systemctl start kibana

# Attendre que Kibana soit prêt
echo -e "     ${YELLOW}En attente de Kibana (peut prendre 30-60s)...${NC}"
MAX_WAIT=120
WAITED=0
while ! curl -s http://localhost:5601/api/status > /dev/null 2>&1; do
  sleep 3
  WAITED=$((WAITED + 3))
  if [ $WAITED -ge $MAX_WAIT ]; then
    echo -e "     ${RED}✗  Kibana n'a pas démarré en ${MAX_WAIT}s${NC}"
    echo -e "     ${YELLOW}Lance : sudo journalctl -u kibana -n 50${NC}"
    exit 1
  fi
  echo -ne "     \r${YELLOW}En attente... (${WAITED}s)${NC}   "
done

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${BOLD}${WHITE}  ✔  Tout est prêt ! Voici tes accès :                       ${NC}${GREEN}║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║${NC}  Elasticsearch  →  ${BOLD}http://localhost:9200${NC}               ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  Kibana         →  ${BOLD}http://localhost:5601${NC}               ${GREEN}║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║${NC}  Dans Kibana :                                           ${GREEN}║${NC}"
echo -e "${GREEN}║${NC}  Menu (☰) → Management → Dev Tools                      ${GREEN}║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║${NC}  Teste avec :  GET /                                     ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
STARTSCRIPT

  # ── Script d'arrêt ─────────────────────────────────────────────────────────
  cat > "$SCRIPTS_DIR/stop.sh" << 'STOPSCRIPT'
#!/bin/bash
echo ""
echo "  Arrêt de Kibana..."
sudo systemctl stop kibana
echo "  Arrêt d'Elasticsearch..."
sudo systemctl stop elasticsearch
echo ""
echo "  ✔  Tout est arrêté."
echo ""
STOPSCRIPT

  # ── Script de statut ───────────────────────────────────────────────────────
  cat > "$SCRIPTS_DIR/status.sh" << 'STATUSSCRIPT'
#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "  ─── Statut des services ───────────────────────────────"
echo ""

# Elasticsearch
if curl -s http://localhost:9200 > /dev/null 2>&1; then
  ES_VERSION=$(curl -s http://localhost:9200 | grep -o '"number" : "[^"]*"' | cut -d'"' -f4)
  echo -e "  ${GREEN}✔${NC}  Elasticsearch  → http://localhost:9200  (v${ES_VERSION})"
else
  echo -e "  ${RED}✗${NC}  Elasticsearch  → non disponible"
fi

# Kibana
if curl -s http://localhost:5601/api/status > /dev/null 2>&1; then
  echo -e "  ${GREEN}✔${NC}  Kibana         → http://localhost:5601"
else
  echo -e "  ${YELLOW}⚠${NC}  Kibana         → non disponible (ou en cours de démarrage)"
fi

echo ""

# Test rapide
if curl -s http://localhost:9200 > /dev/null 2>&1; then
  echo "  ─── Test de connexion ─────────────────────────────────"
  echo ""
  curl -s http://localhost:9200 | python3 -m json.tool 2>/dev/null || \
  curl -s http://localhost:9200
  echo ""
fi
STATUSSCRIPT

  # ── Script de reset (vider les données du TP) ──────────────────────────────
  cat > "$SCRIPTS_DIR/reset_tp.sh" << 'RESETSCRIPT'
#!/bin/bash

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${YELLOW}  ⚠  Cela va supprimer l'index 'logs' du TP.${NC}"
echo -e "  Appuie sur ENTRÉE pour confirmer, Ctrl+C pour annuler."
read -r

if curl -s http://localhost:9200 > /dev/null 2>&1; then
  RESULT=$(curl -s -X DELETE "http://localhost:9200/logs")
  if echo "$RESULT" | grep -q '"acknowledged":true'; then
    echo -e "  ${GREEN}✔  Index 'logs' supprimé. Tu peux recommencer le TP.${NC}"
  else
    echo -e "  ${YELLOW}  Index 'logs' n'existait pas — c'est déjà propre.${NC}"
  fi
else
  echo -e "  ${RED}✗  Elasticsearch n'est pas démarré. Lance ./start.sh d'abord.${NC}"
fi
echo ""
RESETSCRIPT

  # ── Rendre tous les scripts exécutables ───────────────────────────────────
  chmod +x "$SCRIPTS_DIR/start.sh"
  chmod +x "$SCRIPTS_DIR/stop.sh"
  chmod +x "$SCRIPTS_DIR/status.sh"
  chmod +x "$SCRIPTS_DIR/reset_tp.sh"

  # ── Alias dans .bashrc ─────────────────────────────────────────────────────
  if ! grep -q "elasticsearch-tp" ~/.bashrc; then
    cat >> ~/.bashrc << ALIASES

# ── TP Elasticsearch ──────────────────────────────────
alias es-start="$SCRIPTS_DIR/start.sh"
alias es-stop="$SCRIPTS_DIR/stop.sh"
alias es-status="$SCRIPTS_DIR/status.sh"
alias es-reset="$SCRIPTS_DIR/reset_tp.sh"
# ─────────────────────────────────────────────────────
ALIASES
  fi

  print_ok "Scripts créés dans $SCRIPTS_DIR"
  print_ok "Alias disponibles : es-start · es-stop · es-status · es-reset"
}

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

  if curl -s http://localhost:9200 > /dev/null 2>&1; then
    print_ok "Elasticsearch répond sur http://localhost:9200"
  else
    print_warn "Elasticsearch prend plus de temps que prévu."
    print_info "Lance: sudo journalctl -u elasticsearch -n 50"
  fi

  print_info "Démarrage de Kibana..."
  sudo systemctl enable kibana --quiet
  sudo systemctl start kibana
  print_info "Kibana peut prendre 30 à 60 secondes pour démarrer."
  print_ok "Kibana démarré → http://localhost:5601 (dans quelques secondes)"
}

# ─── Résumé final ─────────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║${BOLD}${WHITE}  Installation terminée avec succès !                        ${NC}${GREEN}║${NC}"
  echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
  echo -e "${GREEN}║                                                              ║${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}Accès :${NC}                                                  ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}    Elasticsearch  →  http://localhost:9200               ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}    Kibana         →  http://localhost:5601               ${GREEN}║${NC}"
  echo -e "${GREEN}║                                                              ║${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}Commandes disponibles :${NC}                                  ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}    ${CYAN}es-start${NC}   →  Démarrer Elasticsearch + Kibana         ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}    ${CYAN}es-stop${NC}    →  Arrêter tout                            ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}    ${CYAN}es-status${NC}  →  Vérifier que tout tourne               ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}    ${CYAN}es-reset${NC}   →  Vider les données du TP                ${GREEN}║${NC}"
  echo -e "${GREEN}║                                                              ║${NC}"
  echo -e "${GREEN}║${NC}  ${BOLD}Pour le TP :${NC}                                             ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}    1. Ouvre http://localhost:5601 dans ton navigateur     ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}    2. Menu (☰) → Management → Dev Tools                  ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}    3. Tape : GET /  et clique sur le bouton Play ▶        ${GREEN}║${NC}"
  echo -e "${GREEN}║                                                              ║${NC}"
  echo -e "${GREEN}║${NC}  ${YELLOW}⚠  Recharge ton terminal pour activer les alias :${NC}       ${GREEN}║${NC}"
  echo -e "${GREEN}║${NC}    ${CYAN}source ~/.bashrc${NC}                                       ${GREEN}║${NC}"
  echo -e "${GREEN}║                                                              ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
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
  create_scripts
  first_start
  print_summary
}

main
