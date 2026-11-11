#!/bin/bash
# Relance Open WebUI avec la configuration allégée (Pi 5, Ollama sur l'hôte)
# Personalisation des réglages sur Pi5 - 16 Go
#
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
