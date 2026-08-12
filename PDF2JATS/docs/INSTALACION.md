# Instalación y despliegue

## Requisitos

- Python 3
- `python3-venv`
- Apache o Nginx como proxy inverso en producción
- systemd en el ejemplo de producción

## Instalación de dependencias

```bash
cd /var/www/html/PDF2JATS
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip
.venv/bin/python -m pip install -r requirements.txt
```

## Ejecución de prueba

```bash
.venv/bin/gunicorn -w 2 -b 127.0.0.1:5000 app:app
```

Comprueba localmente:

```bash
curl -I http://127.0.0.1:5000/
```

## systemd

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
ExecStart=/var/www/html/PDF2JATS/.venv/bin/gunicorn -w 2 -b 127.0.0.1:5000 app:app
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Después:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pdf2jats
```

## Apache como proxy inverso

Ejemplo para publicar la aplicación bajo `/PDF2JATS/`:

```apache
ProxyPreserveHost On
ProxyPass        /PDF2JATS/ http://127.0.0.1:5000/
ProxyPassReverse /PDF2JATS/ http://127.0.0.1:5000/
```

Activa los módulos de proxy necesarios según la distribución y recarga Apache.

## Actualización en el servidor institucional

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
