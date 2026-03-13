# 🔍 TP Elasticsearch — Opération Sauvetage

> **Il est 3h du matin. L'application est down. `grep` tourne depuis 3 minutes.**
> Ce TP t'apprend à utiliser Elasticsearch pour ne plus jamais revivre ça.

---

## 📋 Contenu du repo

```
├── setup_elasticsearch.sh   # Script d'installation automatique (WSL Ubuntu)
├── tp_elasticsearch.pdf     # Le TP complet (8 missions)
└── README.md                # Ce fichier
```

---

## ⚡ Démarrage rapide

### 1. Prérequis

- Windows 10/11 avec **WSL 2** activé
- Ubuntu 20.04 ou 22.04 dans WSL
- 4 GB de RAM minimum recommandés
- Connexion internet

> Pas encore WSL ? Ouvre PowerShell en admin et tape :
> ```powershell
> wsl --install -d Ubuntu
> ```
> Redémarre, puis reviens ici.

---

### 2. Installation — une seule fois

Ouvre ton terminal WSL Ubuntu et lance :

```bash
# Cloner le repo
https://github.com/ayaeljahidi/ElasticSearch.git
cd ElasticSearch

# Rendre le script exécutable
chmod +x setup_elasticsearch.sh

# Lancer l'installation (5 à 10 min)
./setup_elasticsearch.sh

# Recharger les alias
source ~/.bashrc
```

Le script installe automatiquement :
-  OpenJDK 17
-  Elasticsearch 8.x
-  Kibana 8.x
-  Les commandes `es-start`, `es-stop`, `es-status`, `es-reset`

---

### 3. Tous les jours — avant le TP

```bash
es-start    # Démarre Elasticsearch + Kibana
```

Attends le message ✔ **Tout est prêt**, puis ouvre dans ton navigateur :

```
http://localhost:5601
```

> Menu **☰** → **Management** → **Dev Tools**
> Tape `GET /` et clique sur ▶

---

## 🛠️ Commandes disponibles

| Commande | Description |
|----------|-------------|
| `es-start` | Démarre Elasticsearch + Kibana |
| `es-stop` | Arrête tout proprement |
| `es-status` | Vérifie que les services tournent |
| `es-reset` | Supprime l'index `logs` pour recommencer le TP |

---

## 🗺️ Plan du TP

Le TP se déroule en **4 parties** et **8 missions**. Chaque mission contient :
- Un contexte narratif (tu es dev en prod à 3h du matin 🌙)
- La requête à compléter
- Un indice si tu bloques
- La solution complète avec explication

| # | Mission | Concept clé |
|---|---------|-------------|
| 1 | Créer l'index | `PUT /logs` — Mapping |
| 2 | Ingérer les logs | `POST /_doc` — Indexation |
| 3 | Première recherche | `match` — Full-text search |
| 4 | Filtres exacts | `term` + `range` |
| 5 | Combiner les conditions | `bool` — must / filter / must_not |
| 6 | Observer la tokenization | `_analyze` — Analyzers |
| 7 | Statistiques en temps réel | `aggs` — terms / avg / max |
| 8 | Recherche sémantique | `kNN` — dense_vector |

---

## 🔧 Dépannage

### Elasticsearch ne démarre pas

```bash
# Voir les logs d'erreur
sudo journalctl -u elasticsearch -n 50

# Vérifier l'état du service
sudo systemctl status elasticsearch
```

### Kibana ne répond pas

```bash
# Voir les logs Kibana
sudo journalctl -u kibana -n 50

# Kibana peut prendre jusqu'à 60s au premier démarrage — sois patient
```

### WSL manque de mémoire

Crée le fichier `%USERPROFILE%\.wslconfig` sur Windows avec :

```ini
[wsl2]
memory=4GB
processors=2
```

Puis redémarre WSL depuis PowerShell :

```powershell
wsl --shutdown
wsl
```

### Tout réinitialiser

```bash
# Supprimer l'index du TP et repartir de zéro
es-reset
```

---

## 📡 Vérifications rapides

```bash
# Elasticsearch répond ?
curl http://localhost:9200

# Kibana répond ?
curl http://localhost:5601/api/status

# L'index logs existe ?
curl http://localhost:9200/_cat/indices?v
```

---

## 📚 Pour aller plus loin

- [Documentation officielle Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Kibana Dev Tools](https://www.elastic.co/guide/en/kibana/current/console-kibana.html)
- [Elasticsearch — The Definitive Guide](https://www.elastic.co/guide/en/elasticsearch/guide/current/index.html)

---

## 🏗️ Stack technique

![Elasticsearch](https://img.shields.io/badge/Elasticsearch-8.x-005571?style=flat&logo=elasticsearch)
![Kibana](https://img.shields.io/badge/Kibana-8.x-005571?style=flat&logo=kibana)
![Java](https://img.shields.io/badge/Java-17-ED8B00?style=flat&logo=java)
![Ubuntu](https://img.shields.io/badge/Ubuntu-WSL2-E95420?style=flat&logo=ubuntu)

---

<div align="center">
  <sub>TP réalisé dans le cadre du cours Elasticsearch · <code>grep</code> c'était hier.</sub>
</div>
