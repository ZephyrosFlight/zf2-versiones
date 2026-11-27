#!/bin/bash
# ZephyrosFlight 2 — instalación en una Raspberry Pi con Raspberry Pi OS (64 bits).
# Sirve para una Pi nueva y para pasar una instalación antigua (con el código fuente) a la
# versión compilada: descarga el programa ya compilado, lo deja en ~/zf2 (borrando el código
# que hubiera) y activa el arranque automático. Los mapas (~/zf2-mapas) y tus ajustes,
# aviones y vuelos (~/.config/zf2) se conservan.
# Uso, en la Pi:
#   curl -fsSL https://raw.githubusercontent.com/ZephyrosFlight/zf2-versiones/main/instalar.sh | bash
URL_BASE="https://raw.githubusercontent.com/ZephyrosFlight/zf2-versiones/main"

principal() {      # todo dentro de una función: con "curl | bash", bash lo lee entero antes de empezar
  set -e
  local DIR="$HOME/zf2" TMP
  if [ "$(uname -m)" != "aarch64" ]; then
    echo "Esto es para una Raspberry Pi con el sistema de 64 bits (aarch64); aquí es $(uname -m)."; exit 1
  fi
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT

  echo "== 1/4 Paquetes del sistema"
  sudo apt-get update -q < /dev/null || true
  sudo apt-get install -y -q libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-ttf-2.0-0 fonts-dejavu-core \
       curl ca-certificates python3 network-manager < /dev/null

  echo "== 2/4 Descargando la última versión"
  curl -fsSL --max-time 30 "$URL_BASE/ultima.txt?t=$(date +%s)" -o "$TMP/ultima.txt"
  val() { sed -n "s/^$1=//p" "$TMP/ultima.txt" | head -1; }
  local PQ SHA
  PQ=$(val paquete); SHA=$(val sha256)
  curl -fSL --retry 3 --progress-bar "$URL_BASE/$PQ" -o "$TMP/p.tgz"
  echo "$SHA  $TMP/p.tgz" | sha256sum -c --status || { echo "La descarga está incompleta: vuelve a intentarlo."; exit 1; }
  mkdir "$TMP/x"
  tar -xzf "$TMP/p.tgz" -C "$TMP/x"
  "$TMP/x/zf2/mapa_prueba/mapa_prueba" --version

  echo "== 3/4 Instalando en ~/zf2"
  sudo systemctl stop zf2-mapa.service zf2-portal.service 2>/dev/null || true
  if [ -d "$DIR" ]; then
    # mapas que quedaran en la carpeta antigua de pruebas
    if [ -d "$DIR/mapa_prueba/teselas" ] && [ ! -e "$HOME/zf2-mapas" ]; then mv "$DIR/mapa_prueba/teselas" "$HOME/zf2-mapas"; fi
    # espacios aéreos descargados a mano en la instalación antigua: a ~/.config/zf2 (no se borran nunca)
    mkdir -p "$HOME/.config/zf2"
    if [ -f "$DIR/datos/espacios.txt" ] && [ ! -e "$HOME/.config/zf2/espacios.txt" ]; then cp "$DIR/datos/espacios.txt" "$HOME/.config/zf2/"; fi
    rm -rf "$DIR.antiguo"
    mv "$DIR" "$DIR.antiguo"
  fi
  mv "$TMP/x/zf2" "$DIR"
  rm -rf "$DIR.antiguo"          # la instalación antigua, con el código fuente, se borra

  echo "== 4/4 Arranque automático"
  cd "$DIR/mapa_prueba"
  ./autoarranque.sh si
  echo
  echo "Listo: ZephyrosFlight 2 $(sed -n 's/^version=//p' "$DIR/VERSION") instalado."
  echo "Las actualizaciones llegarán solas (o con AJUSTES > SISTEMA > BUSCAR ACTUALIZACIÓN)."
}
principal "$@"
