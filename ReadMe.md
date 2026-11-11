# Open WebUI sur Raspberry Pi 5 (16 Go RAM, NVMe 1 To)

Interface web de type « chat » pour des modèles de langage locaux, installée avec Docker et reliée à un serveur **Ollama déjà présent sur le Pi**. Les modèles ne sont stockés qu'une seule fois, l'interface s'utilise depuis n'importe quel appareil du réseau local ou du tunnel WireGuard.

Version testée : Open WebUI 0.13.3, Ollama 0.23.4, Raspberry Pi OS 64 bits.

---

## 1. Principe

```
Navigateur (PC, téléphone)  ──►  Open WebUI (Docker, port 3000)  ──►  Ollama (hôte, 127.0.0.1:11434)
                                                                        └─ modèles sur le NVMe
```

- Ollama reste un service système de l'hôte et n'écoute que sur `127.0.0.1` (il n'est pas exposé au réseau).
- Open WebUI tourne dans un conteneur en mode réseau « host » pour joindre Ollama sur `127.0.0.1`.
- Le Pi fait les calculs. L'affichage se fait de préférence sur **un autre appareil** : un navigateur lancé sur le Pi lui-même manque de CPU pendant une génération (texte qui saccade, changement de modèle tardif).

## 2. Matériel et modèles

| Élément         | Valeur                                                               |
|---              |---                                                                   |
| Carte           | Raspberry Pi 5, 16 Go de RAM                                         |
| Stockage        | NVMe de 1 To                                                         |
| Calcul          | CPU uniquement (4 cœurs), pas de GPU                                 |
| Refroidissement | Actif indispensable (les 4 cœurs sont saturés pendant la génération) |

Modèles installés dans Ollama :

| Modèle                | Taille | Usage                                      |
|---                    |---     |---                                         |
| `llama3.2:3b`         | 2,0 Go | Questions rapides, **modèle par défaut**   |
| `llama32-8k:latest`   | 2,0 Go | Variante de Llama 3.2 avec contexte de 8 K |
| `mistral:7b`          | 4,4 Go | Généraliste, bon français                  |
| `qwen2.5:7b`          | 4,7 Go | Généraliste multilingue, raisonnement      |
| `gemma2:9b`           | 5,4 Go | Rédaction, style naturel                   |
| `deepseek-coder:6.7b` | 3,8 Go | Code                                       |
| `llama3.2-vision:11b` | 7,8 Go | Texte et images                            |
| `moondream:latest`    | 1,7 Go | Vision légère (questions en anglais)       |

Ordre de grandeur des performances mesurées avec Ollama seul (chargement du modèle compris dans la durée totale) :

| Modèle        | Durée totale (question courte) | Génération           |
|---            |---                             |---                   |
| `llama3.2:3b` | environ 23 s                   | environ 5,4 tokens/s |
| `mistral:7b`  | environ 46 s                   | environ 2,3 tokens/s |
| `qwen2.5:7b`  | environ 60 s                   | environ 2,1 tokens/s |

Un modèle de 7 milliards de paramètres écrit environ 2 mots par seconde : une longue réponse prend plusieurs minutes. Un seul modèle est chargé à la fois ; changer de modèle recharge le suivant (20 à 40 s).

## 3. Prérequis

1. **Ollama** installé comme service système, avec les modèles ci-dessus :

   ```bash
   curl -s http://127.0.0.1:11434          # doit répondre « Ollama is running »
   ollama list
   ```

2. **Docker** installé et fonctionnel :

   ```bash
   sudo docker run --rm hello-world
   ```

## 4. Installation

Ne pas utiliser l'image `open-webui:ollama` : elle embarque son propre Ollama et ses propres modèles, ce qui double l'espace disque. On utilise l'image standard `:main`.

Créer le script de lancement `~/Projects/WebUI/open-webui-run.sh` :

```bash
#!/bin/bash
# Relance Open WebUI avec la configuration allégée (Pi 5, Ollama sur l'hôte)
sudo docker rm -f open-webui

sudo docker run -d --network=host \
  -e PORT=3000 \
  -e OLLAMA_BASE_URL=http://127.0.0.1:11434 \
  -e ENABLE_OPENAI_API=False \
  -e ENABLE_PERSISTENT_CONFIG=False \
  -e ENABLE_TITLE_GENERATION=False \
  -e ENABLE_TAGS_GENERATION=False \
  -e ENABLE_FOLLOW_UP_GENERATION=False \
  -e ENABLE_AUTOCOMPLETE_GENERATION=False \
  -e ENABLE_RETRIEVAL_QUERY_GENERATION=False \
  -e ENABLE_SEARCH_QUERY_GENERATION=False \
  -e ENABLE_WEB_SEARCH=False \
  -e ENABLE_CODE_INTERPRETER=False \
  -e ENABLE_CODE_EXECUTION=False \
  -e ENABLE_IMAGE_GENERATION=False \
  -e DEFAULT_MODELS=llama3.2:3b \
  -e 'DEFAULT_MODEL_METADATA={"capabilities":{"builtin_tools":false,"web_search":false,"code_interpreter":false,"image_generation":false,"terminal":false}}' \
  -v open-webui:/app/backend/data \
  --name open-webui --restart always \
  ghcr.io/open-webui/open-webui:main
```

Lancer :

```bash
bash ~/Projects/WebUI/open-webui-run.sh
curl -s http://127.0.0.1:3000/health        # attendre environ 1 minute → {"status":true}
```

Le premier démarrage est long (initialisation de la base, petits modèles d'embeddings). Ouvrir ensuite `http://<IP-du-Pi>:3000` : **le premier compte créé devient administrateur**. L'adresse e-mail n'est pas vérifiée, le compte est local.

## 5. Pourquoi cette configuration (point crucial)

Avec les réglages par défaut, Open WebUI joint à **chaque message** la définition de ses outils intégrés (heure, mémoire, notes, connaissances, recherche, etc.). Mesuré sur ce montage : pour un message de 7 caractères, la requête contenait **38 outils, soit près de 28 000 caractères (environ 5 400 tokens)**.

Sur un Pi, un modèle lit son prompt à 4 à 10 tokens/s : cela représente de 10 à plus de 20 minutes de calcul avant le premier mot, CPU à 390 % et aucune réponse. Après désactivation des outils, le même message passe à environ 210 caractères et la réponse arrive en quelques secondes.

La configuration ci-dessus agit à trois niveaux :

| Variable                                                                                                                                                                                    | Effet                                                                                                                                                                       |
|---                                                                                                                                                                                          |---                                                                                                                                                                          |
| `ENABLE_TITLE_GENERATION`, `ENABLE_TAGS_GENERATION`, `ENABLE_FOLLOW_UP_GENERATION`, `ENABLE_AUTOCOMPLETE_GENERATION`, `ENABLE_RETRIEVAL_QUERY_GENERATION`, `ENABLE_SEARCH_QUERY_GENERATION` | Supprime les requêtes automatiques lancées après chaque message                                                                                                             |
| `DEFAULT_MODEL_METADATA`                                                                                                                                                                    | Capacités par défaut de **tous** les modèles : outils intégrés, recherche web, interpréteur de code, images et terminal désactivés. Un réglage propre à un modèle l'emporte |
| `DEFAULT_MODELS`                                                                                                                                                                            | Modèle proposé au démarrage                                                                                                                                                 |
| `ENABLE_PERSISTENT_CONFIG=False`                                                                                                                                                            | Impose ces valeurs à chaque démarrage. Les réglages faits dans l'interface pour ces options sont alors réinitialisés au redémarrage du conteneur                            |

Les comptes, conversations et réglages propres à un modèle sont conservés dans le volume Docker `open-webui`.

Pour gérer ces options dans l'interface plutôt que par variables, retirer `ENABLE_PERSISTENT_CONFIG=False` : les valeurs ne sont alors lues qu'au premier démarrage.

Les modèles de vision n'ont pas la vision désactivée par ce réglage : ne pas ajouter `vision` à la liste des capacités désactivées.

## 6. Pare-feu (UFW)

Le port 3000 n'est ouvert qu'au réseau local et au tunnel WireGuard, jamais à Internet. Ne pas rediriger ce port depuis la box.

```bash
sudo ufw allow from <réseau-local>/24 to any port 3000 proto tcp
sudo ufw allow in on wg0 from <réseau-wireguard>/24 to any port 3000 proto tcp comment 'open-webui'
sudo ufw status | grep 3000
```

Comme le conteneur est en mode réseau « host », il n'y a pas de redirection de port Docker : UFW filtre le port 3000 comme n'importe quel service local.

## 7. Accès

| Depuis                             | Adresse                            |
|---                                 |---                                 |
| Un appareil du réseau local        | `http://<IP-du-Pi>:3000`           |
| Un appareil connecté par WireGuard | `http://<IP-WireGuard-du-Pi>:3000` |

L'adresse WireGuard du Pi se lit avec `ip -4 addr show wg0 | grep inet`.

## 8. Vérifications

```bash
# Conteneur et santé
sudo docker ps --format '{{.Names}} | {{.Status}}'
curl -s http://127.0.0.1:3000/health

# Variables appliquées
sudo docker inspect open-webui --format '{{range .Config.Env}}{{println .}}{{end}}' | grep -E "ENABLE_|DEFAULT"

# Ollama : modèle chargé, port d'écoute
ollama ps
sudo ss -tlnp | grep -E ":3000|:11434"        # 11434 doit rester sur 127.0.0.1

# Durée des dernières requêtes
journalctl -u ollama --since "-10min" --no-pager | grep "POST.*api/chat"
```

Test fonctionnel : nouvelle conversation, envoyer « Bonjour, présente-toi en une phrase » avec un modèle jamais personnalisé. La réponse doit arriver en moins d'une minute (chargement compris).

## 9. Dépannage

**Le CPU reste à 390 % sans réponse.** Soit les outils sont renvoyés (voir le point 5), soit un calcul orphelin tourne encore (page rechargée ou génération interrompue). Pour l'arrêter :

```bash
sudo pkill -f "ollama runner"
sudo systemctl restart ollama
```

Refaire cette opération avant chaque nouveau test de performance.

**Voir ce qu'Open WebUI envoie réellement à Ollama.** Activer temporairement la journalisation des requêtes :

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
printf '[Service]\nEnvironment="OLLAMA_DEBUG=1"\nEnvironment="OLLAMA_DEBUG_LOG_REQUESTS=true"\n' | sudo tee /etc/systemd/system/ollama.service.d/debug.conf
sudo systemctl daemon-reload && sudo systemctl restart ollama
```

Après une requête, la ligne `completion request ... prompt=` du journal donne la taille du prompt, et un fichier `*_api_chat_body.json` est écrit dans `/tmp/ollama-request-logs-*` (liste `messages` et éventuelle clé `tools`).

**Retirer ensuite ce mode, car il enregistre le contenu des conversations en clair :**

```bash
sudo rm /etc/systemd/system/ollama.service.d/debug.conf
sudo systemctl daemon-reload && sudo systemctl restart ollama
sudo rm -rf /tmp/ollama-request-logs-*
```

**La page reste sur le logo au démarrage.** Le serveur n'a pas fini d'initialiser : suivre `sudo docker logs --tail 30 open-webui` et attendre que `/health` réponde.

**Un modèle n'apparaît pas dans la liste.** Admin > Réglages > Connexions : l'URL Ollama doit être `http://127.0.0.1:11434`.

**La liste de modèles est lente ou l'affichage saccade.** Utiliser un autre appareil comme client plutôt qu'un navigateur sur le Pi.

**Un `docker logs -f` bloque le terminal.** C'est normal (suivi continu) : Ctrl+C l'arrête sans arrêter le conteneur.

## 10. Maintenance

**Mise à jour d'Open WebUI** (les données sont conservées) :

```bash
sudo docker pull ghcr.io/open-webui/open-webui:main
bash ~/Projects/WebUI/open-webui-run.sh
```

Après une mise à jour, vérifier que les noms de variables sont toujours reconnus (section 8).

**Sauvegarde des comptes et conversations :**

```bash
sudo docker run --rm -v open-webui:/data -v "$PWD":/backup alpine tar czf /backup/open-webui-backup.tgz -C /data .
```

**Arrêt et redémarrage :**

```bash
sudo docker stop open-webui
sudo docker start open-webui
```

Le conteneur est lancé avec `--restart always` : il redémarre seul après un redémarrage du Pi.

**Désinstallation :**

```bash
sudo docker rm -f open-webui
sudo docker rmi ghcr.io/open-webui/open-webui:main
sudo docker volume rm open-webui        # supprime comptes et conversations
```

Les modèles Ollama ne sont pas touchés.

## 11. Points d'attention

- **Mémoire** : un seul gros modèle à la fois. Ollama garde un modèle en mémoire 5 minutes après usage par défaut.
- **Partage d'Ollama** : si un autre programme utilise le même Ollama et arrête ses générations avec `pkill` sur les processus `ollama runner`, une génération en cours dans Open WebUI sera coupée aussi.
- **Nouveaux modèles** : ceux téléchargés depuis Open WebUI vont dans le stock Ollama de l'hôte, donc disponibles pour les autres programmes qui l'utilisent. Penser à vérifier ses capacités, car les réglages par défaut s'y appliquent.
- **Sécurité** : mot de passe solide pour le compte administrateur, port 3000 filtré par le pare-feu, aucun accès depuis Internet.
