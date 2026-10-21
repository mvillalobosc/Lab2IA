# Seguridad · Security

[Español](#español) · [English](#english)

## Español

PDF2JATS procesa documentos suministrados por el usuario y realiza consultas de metadatos a servicios públicos externos.

### Recomendaciones de despliegue

- Ejecutar Gunicorn únicamente en una interfaz local y publicar la aplicación mediante un proxy inverso HTTPS.
- Mantener Python y las dependencias actualizados.
- No ejecutar el servicio como `root`.
- Limitar el tamaño máximo de los archivos PDF en el proxy y/o en Flask según las necesidades del despliegue (`app.py` ya limita cada petición a 120 MB).
- Revisar periódicamente los registros del servicio.
- No almacenar credenciales ni tokens dentro del repositorio.
- La aplicación no tiene cuentas de usuario. Cada navegador tiene su propia sesión, identificada por una cookie firmada con la clave de `PDF2JATS_SECRET_KEY` (o con una que el servidor genera al arrancar), y no ve los PDF ni los artículos de las demás. Aun así, cualquiera que llegue a la dirección puede usar la aplicación: si no debe quedar abierta a terceros, restringe el acceso en el proxy.

Los PDF y metadatos pueden contener información editorial no publicada. En instalaciones reales debe definirse una política explícita de retención y acceso. Hoy los PDF quedan en una subcarpeta por sesión dentro de la carpeta temporal del sistema (`pdf2jats_pdfs`) hasta que se quitan, se limpia la sesión o la sesión pasa 6 horas sin actividad.

## English

PDF2JATS processes documents supplied by the user and queries external public services for metadata.

### Deployment recommendations

- Run Gunicorn only on a local interface and publish the application through an HTTPS reverse proxy.
- Keep Python and the dependencies up to date.
- Do not run the service as `root`.
- Limit the maximum size of the PDF files in the proxy and/or in Flask as the deployment requires (`app.py` already limits each request to 120 MB).
- Review the service logs regularly.
- Do not store credentials or tokens in the repository.
- The application has no user accounts. Each browser has its own session, identified by a cookie signed with the key in `PDF2JATS_SECRET_KEY` (or with one that the server generates when it starts), and it does not see the PDFs or the articles of the others. Even so, anyone who reaches the address can use the application: if it must not be open to third parties, restrict access in the proxy.

PDFs and metadata can contain unpublished editorial information. Real installations need an explicit retention and access policy. At present the PDFs stay in one subfolder per session inside the system temporary folder (`pdf2jats_pdfs`) until they are removed, the session is cleared or the session goes 6 hours without activity.
