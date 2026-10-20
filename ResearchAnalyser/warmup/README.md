# warmup/

[Español](#español) · [English](#english)

## Español

Esta carpeta de [ResearchAnalyser](../README.md) deja un modelo cargado en la memoria de un servidor Ollama, para que la primera consulta no espere la carga del modelo.

| Archivo | Qué hace |
|---|---|
| `warmup.sh` | Envía `pub_body.json` y `tesis_body.json` a `$OLLAMA_URL/api/chat` (por defecto `http://127.0.0.1:11434`) y muestra el código HTTP y el tiempo de cada petición. Se ejecuta con `./warmup.sh`; para otro equipo o puerto, `OLLAMA_URL=http://IP:11434 ./warmup.sh`. Necesita bash y curl. En el repositorio no tiene permiso de ejecución, así que antes hay que darle `chmod +x warmup.sh` o correrlo con `bash warmup.sh`. |
| `pub_body.json` | Cuerpo de una petición de chat para el modelo `llama3.2:3b`: un mensaje de sistema de asistente bibliométrico del DIINF con un resumen del filtro de Publicaciones y un mensaje de usuario. Usa `keep_alive: -1` y `num_predict: 1`, así que solo carga el modelo y no genera una respuesta útil. |
| `tesis_body.json` | El mismo tipo de cuerpo para el módulo de tesis. |
| `ollama-warmup.service` | Unidad systemd de tipo `oneshot` que corre después de `ollama.service`, espera ocho segundos y ejecuta `/var/www/html/ResearchAnalyser/warmup/warmup.sh`. Esa ruta está fija y hay que ajustarla si la carpeta vive en otro lugar; además el script tiene que ser ejecutable. |

Ninguna página de la app actual llama a Ollama: el asistente de los módulos responde en el navegador, y las herramientas de [../herramientas/](../herramientas/) usan `/api/generate` con el modelo que se elija en ellas (por defecto `llama3.1:8b`). Esta carpeta solo sirve si se quiere mantener `llama3.2:3b` cargado en un servidor.

## English

This folder of [ResearchAnalyser](../README.md) keeps a model loaded in the memory of an Ollama server, so that the first request does not wait for the model to load.

| File | What it does |
|---|---|
| `warmup.sh` | Sends `pub_body.json` and `tesis_body.json` to `$OLLAMA_URL/api/chat` (by default `http://127.0.0.1:11434`) and prints the HTTP status and time of each request. Run it with `./warmup.sh`; for another host or port, `OLLAMA_URL=http://IP:11434 ./warmup.sh`. It needs bash and curl. In the repository it lacks the executable bit, so first run `chmod +x warmup.sh` or call it with `bash warmup.sh`. |
| `pub_body.json` | Body of a chat request for the `llama3.2:3b` model: a system message for a DIINF bibliometric assistant with a summary of the Publications filter, and one user message. It sets `keep_alive: -1` and `num_predict: 1`, so it only loads the model and does not produce a useful answer. |
| `tesis_body.json` | The same kind of body for the theses module. |
| `ollama-warmup.service` | `oneshot` systemd unit that runs after `ollama.service`, waits eight seconds and executes `/var/www/html/ResearchAnalyser/warmup/warmup.sh`. That path is fixed and has to be adjusted if the folder lives elsewhere; the script also has to be executable. |

No page of the current app calls Ollama: the modules' assistant answers in the browser, and the tools in [../herramientas/](../herramientas/) use `/api/generate` with the model chosen in them (by default `llama3.1:8b`). This folder is only useful to keep `llama3.2:3b` loaded on a server.
