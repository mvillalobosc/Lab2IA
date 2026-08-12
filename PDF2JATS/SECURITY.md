# Seguridad

PDF2JATS procesa documentos suministrados por el usuario y realiza consultas de metadatos a servicios públicos externos.

## Recomendaciones de despliegue

- Ejecutar Gunicorn únicamente en una interfaz local y publicar la aplicación mediante un proxy inverso HTTPS.
- Mantener Python y las dependencias actualizados.
- No ejecutar el servicio como `root`.
- Limitar el tamaño máximo de los archivos PDF en el proxy y/o en Flask según las necesidades del despliegue.
- Revisar periódicamente los registros del servicio.
- No almacenar credenciales ni tokens dentro del repositorio.

Los PDF y metadatos pueden contener información editorial no publicada. En instalaciones reales debe definirse una política explícita de retención y acceso.
