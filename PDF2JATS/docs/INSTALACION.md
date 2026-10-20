# Instalación y despliegue · Installation and deployment

[Español](#español) · [English](#english)

## Español

Para probar la aplicación en un computador basta con `python3 app.py`, como explica el [README del proyecto](../README.md#ejecución-local). Esta guía cubre la instalación en un servidor.

### Requisitos

- Python 3 (las versiones mínimas de `requirements.txt` necesitan Python 3.8 o superior)
- `python3-venv`
- Apache o Nginx como proxy inverso en producción
- systemd en el ejemplo de producción

### Instalación de dependencias

```bash
cd /var/www/html/PDF2JATS
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -r requirements.txt
```

### Ejecución de prueba

```bash
.venv/bin/gunicorn -w 1 -b 127.0.0.1:5000 app:app
```

Comprueba localmente:

```bash
curl -I http://127.0.0.1:5000/
```

La sesión de trabajo vive en la memoria de cada proceso, así que los ejemplos usan un solo worker (`-w 1`). Con más workers, una petición puede llegar a un proceso que no tiene el artículo cargado y responder "no encontrado".

### systemd

Ejemplo de unidad:

```ini
[Unit]
Description=PDF2JATS
After=network.target

[Service]
Type=simple
User=USUARIO
Group=GRUPO
WorkingDirectory=/var/www/html/PDF2JATS
ExecStart=/var/www/html/PDF2JATS/.venv/bin/gunicorn -w 1 -b 127.0.0.1:5000 app:app
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

`USUARIO` y `GRUPO` son la cuenta del sistema con que corre el servicio. Las variables de entorno opcionales (por ejemplo `PDF2JATS_CROSSREF_MAILTO`) se agregan en la sección `[Service]` con líneas `Environment=`; la lista está en el [README del proyecto](../README.md#variables-de-entorno).

Después:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pdf2jats
```

### Apache como proxy inverso

Ejemplo para publicar la aplicación bajo `/PDF2JATS/`:

```apache
ProxyPreserveHost On
ProxyPass        /PDF2JATS/ http://127.0.0.1:5000/
ProxyPassReverse /PDF2JATS/ http://127.0.0.1:5000/
```

Activa los módulos de proxy necesarios según la distribución y recarga Apache.

### Actualización en el servidor institucional

El repositorio incluye `ACTIVAR.sh` para el despliegue ya configurado:

```bash
cd /var/www/html/PDF2JATS
bash ACTIVAR.sh
```

El script:

1. crea `.venv` si falta;
2. instala/actualiza dependencias;
3. compila los módulos Python como validación básica;
4. reinicia `pdf2jats.service`;
5. comprueba `127.0.0.1:5000`.

Al terminar imprime la dirección pública de la aplicación. El script entra a la ruta fija `/var/www/html/PDF2JATS` y usa `sudo systemctl`, por lo que solo sirve en un servidor con esa ruta y con la unidad `pdf2jats` ya instalada.

## English

To try the application on a computer, `python3 app.py` is enough, as the [project README](../README.md#running-locally) explains. This guide covers installation on a server.

### Requirements

- Python 3 (the minimum versions in `requirements.txt` need Python 3.8 or later)
- `python3-venv`
- Apache or Nginx as a reverse proxy in production
- systemd in the production example

### Installing the dependencies

```bash
cd /var/www/html/PDF2JATS
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -r requirements.txt
```

### Test run

```bash
.venv/bin/gunicorn -w 1 -b 127.0.0.1:5000 app:app
```

Check it locally:

```bash
curl -I http://127.0.0.1:5000/
```

The working session lives in the memory of each process, so the examples use a single worker (`-w 1`). With more workers, a request can reach a process that does not hold the article and answer "no encontrado" (not found).

### systemd

Example unit:

```ini
[Unit]
Description=PDF2JATS
After=network.target

[Service]
Type=simple
User=USUARIO
Group=GRUPO
WorkingDirectory=/var/www/html/PDF2JATS
ExecStart=/var/www/html/PDF2JATS/.venv/bin/gunicorn -w 1 -b 127.0.0.1:5000 app:app
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

`USUARIO` and `GRUPO` are the system user and group that run the service. Optional environment variables (for example `PDF2JATS_CROSSREF_MAILTO`) go in the `[Service]` section as `Environment=` lines; the list is in the [project README](../README.md#environment-variables).

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pdf2jats
```

### Apache as a reverse proxy

Example that publishes the application under `/PDF2JATS/`:

```apache
ProxyPreserveHost On
ProxyPass        /PDF2JATS/ http://127.0.0.1:5000/
ProxyPassReverse /PDF2JATS/ http://127.0.0.1:5000/
```

Enable the proxy modules your distribution needs and reload Apache.

### Updating the institutional server

The repository includes `ACTIVAR.sh` for the deployment that is already configured:

```bash
cd /var/www/html/PDF2JATS
bash ACTIVAR.sh
```

The script:

1. creates `.venv` if it is missing;
2. installs or updates the dependencies;
3. compiles the Python modules as a basic check;
4. restarts `pdf2jats.service`;
5. checks `127.0.0.1:5000`.

When it finishes it prints the public address of the application. The script moves to the fixed path `/var/www/html/PDF2JATS` and uses `sudo systemctl`, so it only works on a server with that path and with the `pdf2jats` unit already installed.
