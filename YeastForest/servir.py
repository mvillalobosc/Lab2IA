#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Lanzador del Bosque Filogenético.
Coloca este archivo en la MISMA carpeta que index.html y data/.
Doble-clic (si .py esta asociado a Python) o ejecuta:  python servir.py
Levanta un servidor local y abre el navegador solo.  Ctrl+C para detener.
"""
import os, sys, socket, threading, webbrowser
import http.server, socketserver

os.chdir(os.path.dirname(os.path.abspath(__file__)))

if not os.path.exists("index.html"):
    print("\n  [!] No encuentro index.html en esta carpeta.")
    print("      Pon servir.py junto a index.html y data/, y vuelve a ejecutar.\n")
    input("  Enter para cerrar...")
    sys.exit(1)

def libre(p):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(("127.0.0.1", p)) != 0

PORT = 8000
while not libre(PORT) and PORT < 8030:
    PORT += 1

URL = f"http://localhost:{PORT}/index.html"

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):  # menos ruido en consola
        pass

threading.Timer(0.9, lambda: webbrowser.open(URL)).start()

print("\n  Bosque Filogenetico S. cerevisiae y S. eubayanus")
print("  --------------------------------------------")
print(f"  Sirviendo en:  {URL}")
print("  Abriendo el navegador...")
print("  (Ctrl+C para detener)\n")

try:
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\n  Servidor detenido. Chao.\n")
