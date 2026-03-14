#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# TP Elasticsearch — Script d'installation automatique corrigé pour WSL
# Installe : Java 17 + Elasticsearch 8.x + Kibana 8.x
# Avec corrections : vm.max_map_count, permissions, dossiers Elasticsearch
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# ─── Couleurs ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; GRAY='\033[0;37m'; NC='\033[0m'; BOLD='\033[1m'

print_banner() {
  echo ""
  echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║${WHITE}        TP Elasticsearch — Installation automatique           ${BLUE}║${NC}"
  echo -e "${BLUE}║${GRAY}        WSL Ubuntu · Elasticsearch 8.x · Kibana 8.x          ${BLUE}║${NC}"
  echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

print_step() { echo -e "\n${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}\n${CYAN}│${BOLD}  $1${NC}\n${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"; }
print_ok()   { echo -e "  ${GREEN}✔${NC}  $1"; }
print_info(){ echo -e "  ${BLUE}ℹ${NC}  $1"; }
print_warn(){ echo -e "  ${YELLOW}⚠${NC}  $1"; }
print_err() { echo -e "  ${RED}✗${NC}  $1"; }

# ─── Vérifications préalables ─────────────────────────────────────────────────
check_wsl() {
  print_step "Vérification de l'environnement WSL"
  if grep -qi microsoft /proc/version 2>/dev/null; then
    print_ok "WSL détecté — parfait !"
  else
    print_warn "WSL non détecté — le script fonctionne aussi sur Ubuntu natif."
  fi

  MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  MEM_GB=$((MEM_TOTAL / 1024 / 1024))
  if [ "$MEM_GB" -lt 2 ]; then
    print_warn "Mémoire détectée : ${MEM_GB}GB. Elasticsearch recommande 2GB minimum."
    print_warn "Si WSL est lent, ajoute dans %USERPROFILE%\.wslconfig :"
    echo -e "     ${GRAY}[wsl2]${NC}\n     ${GRAY}memory=4GB${NC}"
  else
    print_ok "Mémoire disponible : ${MEM_GB}GB — OK"
  fi

  if curl -s --max-time 5 https://artifacts.elastic.co > /dev/null 2>&1; then
    print_ok "Connexion internet — OK"
  else
    print_err "Pas de connexion internet. Vérifie ta connexion et relance le script."
    exit 1
  fi
}

# ─── Étape 1 : Mise à jour ─────────────────────────────────────────
update_system() {
  print_step "Étape 1/5 — Mise à jour du système"
  print_info "sudo apt update && apt upgrade..."
  sudo apt-get update -qq
  sudo apt-get upgrade -y -qq
  print_ok "Système à jour"
}

# ─── Étape 2 : Java 17 ─────────────────────────────────────────────
install_java() {
  print_step "Étape 2/5 — Installation de Java 17"
  if java -version 2>/dev/null | grep -q "17\|18\|19\|20\|21"; then
    JAVA_VER=$(java -version 2>&1 | head -1)
    print_ok "Java déjà installé : $JAVA_VER"
    return
  fi
  print_info "Installation de OpenJDK 17..."
  sudo apt-get install -y -qq openjdk-17-jdk

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

# ─── Étape 3 : Elasticsearch ───────────────────────────────────────
install_elasticsearch() {
  print_step "Étape 3/5 — Installation d'Elasticsearch 8.x"

  if systemctl is-active --quiet elasticsearch 2>/dev/null || [ -f /usr/share/elasticsearch/bin/elasticsearch ]; then
    print_ok "Elasticsearch déjà installé — passage à la configuration"
    configure_elasticsearch
    return
  fi

  print_info "Ajout du dépôt Elastic..."
  sudo apt-get install -y -qq apt-transport-https wget gnupg
  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list > /dev/null

  sudo apt-get update -qq

  print_info "Téléchargement rapide d'Elasticsearch..."
  wget -c https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.19.12-amd64.deb -O elasticsearch-8.19.12-amd64.deb
  sudo dpkg -i elasticsearch-8.19.12-amd64.deb || sudo apt-get install -f -y

  configure_elasticsearch
  print_ok "Elasticsearch installé"
}

configure_elasticsearch() {
  print_info "Configuration d'Elasticsearch..."
  ES_CONFIG="/etc/elasticsearch/elasticsearch.yml"
  sudo tee "$ES_CONFIG" > /dev/null << 'EOF'
cluster.name: tp-elasticsearch
node.name: node-1
network.host: 127.0.0.1
http.port: 9200
discovery.type: single-node
xpack.security.enabled: false
xpack.security.http.ssl.enabled: false
xpack.security.transport.ssl.enabled: false
bootstrap.memory_lock: false
EOF

  ES_JVM="/etc/elasticsearch/jvm.options.d/tp.options"
  sudo tee "$ES_JVM" > /dev/null << 'EOF'
-Xms512m
-Xmx1g
EOF
  print_ok "Elasticsearch configuré"
}

# ─── Étape 4 : Kibana ─────────────────────────────────────────────
install_kibana() {
  print_step "Étape 4/5 — Installation de Kibana 8.x (téléchargement rapide)"

  if [ -f /usr/share/kibana/bin/kibana ]; then
    print_ok "Kibana déjà installé — passage à la configuration"
    configure_kibana
    return
  fi

  print_info "Téléchargement rapide de Kibana..."
  wget -c https://artifacts.elastic.co/downloads/kibana/kibana-8.19.12-amd64.deb -O kibana-8.19.12-amd64.deb

  print_info "Installation de Kibana..."
  sudo dpkg -i kibana-8.19.12-amd64.deb || sudo apt-get install -f -y

  configure_kibana
  print_ok "Kibana installé"
}

configure_kibana() {
  print_info "Configuration de Kibana..."
  sudo tee /etc/kibana/kibana.yml > /dev/null << 'EOF'
server.port: 5601
server.host: "127.0.0.1"
elasticsearch.hosts: ["http://127.0.0.1:9200"]
i18n.locale: "fr-FR"
logging.root.level: warn
EOF
  print_ok "Kibana configuré"
}

# ─── Étape 5 : Scripts ───────────────────────────────────────────
create_scripts() {
  print_step "Étape 5/5 — Création des scripts de démarrage"

  SCRIPTS_DIR="$HOME/elasticsearch-tp"
  mkdir -p "$SCRIPTS_DIR"

  # start.sh
  cat > "$SCRIPTS_DIR/start.sh" << 'STARTSCRIPT'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

# WSL fix
sudo sysctl -w vm.max_map_count=262144
sudo mkdir -p /usr/share/elasticsearch/logs /var/lib/elasticsearch /var/run/elasticsearch
sudo chown -R elasticsearch:elasticsearch /usr/share/elasticsearch /var/lib/elasticsearch /var/run/elasticsearch

sudo systemctl daemon-reload
sudo systemctl start elasticsearch
sudo systemctl start kibana

echo -e "${GREEN}✔ Elasticsearch et Kibana démarrés${NC}"
STARTSCRIPT

# stop.sh
cat > "$SCRIPTS_DIR/stop.sh" << 'STOPSCRIPT'
#!/bin/bash
sudo systemctl stop kibana
sudo systemctl stop elasticsearch
echo "✔ Tous les services arrêtés."
STOPSCRIPT

# status.sh
cat > "$SCRIPTS_DIR/status.sh" << 'STATUSSCRIPT'
#!/bin/bash
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo ""
if curl -s http://localhost:9200 > /dev/null 2>&1; then
  echo -e "${GREEN}✔ Elasticsearch actif${NC}"
else
  echo -e "${RED}✗ Elasticsearch non disponible${NC}"
fi
if curl -s http://localhost:5601/api/status > /dev/null 2>&1; then
  echo -e "${GREEN}✔ Kibana actif${NC}"
else
  echo -e "${YELLOW}⚠ Kibana non disponible${NC}"
fi
STATUSSCRIPT

# reset_tp.sh
cat > "$SCRIPTS_DIR/reset_tp.sh" << 'RESETSCRIPT'
#!/bin/bash
YELLOW='\033[1;33m'; GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
echo -e "${YELLOW}⚠ Suppression de l'index 'logs'...${NC}"
read -r
curl -s -X DELETE "http://localhost:9200/logs" && echo -e "${GREEN}✔ Index supprimé${NC}"
RESETSCRIPT

chmod +x "$SCRIPTS_DIR/"*.sh
if ! grep -q "elasticsearch-tp" ~/.bashrc; then
  cat >> ~/.bashrc << ALIASES
alias es-start="$SCRIPTS_DIR/start.sh"
alias es-stop="$SCRIPTS_DIR/stop.sh"
alias es-status="$SCRIPTS_DIR/status.sh"
alias es-reset="$SCRIPTS_DIR/reset_tp.sh"
ALIASES
fi
print_ok "Scripts créés et alias ajoutés"
}

# ─── Démarrage initial ───────────────────────────────────────────
first_start() {
  print_step "Démarrage initial — vérification que tout fonctionne"
  print_info "Configuration WSL et dossiers Elasticsearch..."
  sudo sysctl -w vm.max_map_count=262144
  sudo mkdir -p /usr/share/elasticsearch/logs /var/lib/elasticsearch /var/run/elasticsearch
  sudo chown -R elasticsearch:elasticsearch /usr/share/elasticsearch /var/lib/elasticsearch /var/run/elasticsearch

  print_info "Démarrage Elasticsearch..."
  sudo systemctl daemon-reload
  sudo systemctl enable elasticsearch --quiet
  sudo systemctl start elasticsearch

  echo -ne "  ${YELLOW}En attente d'Elasticsearch${NC}"
  MAX_WAIT=60; WAITED=0
  while ! curl -s http://localhost:9200 > /dev/null 2>&1; do sleep 2; WAITED=$((WAITED+2))
    echo -ne "."; if [ $WAITED -ge $MAX_WAIT ]; then echo -e "\n  ${RED}✗ Elasticsearch n'a pas démarré${NC}"; exit 1; fi
  done
  echo -e "\n  ${GREEN}✔ Elasticsearch prêt${NC}"

  print_info "Démarrage Kibana..."
  sudo systemctl enable kibana --quiet
  sudo systemctl start kibana

  MAX_WAIT=120; WAITED=0
  while ! curl -s http://localhost:5601/api/status > /dev/null 2>&1; do sleep 3; WAITED=$((WAITED+3))
    echo -ne "  \r${YELLOW}En attente Kibana... (${WAITED}s)${NC}"; if [ $WAITED -ge $MAX_WAIT ]; then echo -e "\n  ${RED}✗ Kibana n'a pas démarré${NC}"; exit 1; fi
  done
  echo -e "\n  ${GREEN}✔ Kibana prêt${NC}"
}

# ─── Résumé final ─────────────────────────────────────────────
print_summary() {
  echo -e "\n${GREEN}✔ Installation terminée !${NC}"
  echo "Elasticsearch → http://localhost:9200"
  echo "Kibana       → http://localhost:5601"
  echo "Commandes : es-start, es-stop, es-status, es-reset"
}

# ─── Main ─────────────────────────────────────────────────────
main() {
  clear
  print_banner
  echo "Appuie sur ENTRÉE pour commencer..."
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
