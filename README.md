# tdt-local en Docker

Imagen **no oficial** de [tdt-local](https://github.com/cibernicola/tdt-local): visor web de la TDT española y la
radio, alimentado por las listas públicas de [TDTChannels](https://github.com/LaQuay/TDTChannels).

> El proyecto original **no publica Docker** (ni Dockerfile ni imagen). Esto es un envoltorio: descarga su código
> fuente de la versión fijada, lo instala con `pip` y lo arranca escuchando en la red local. Todos los méritos son
> de [cibernicola](https://github.com/cibernicola); los fallos de empaquetado son de aquí.

Imagen publicada en GHCR: `ghcr.io/pcaro/tdt-local-docker` · `linux/amd64` y `linux/arm64`.

## Inicio rápido

```bash
docker run -d --name tdt-local -p 8788:8788 -v "$PWD/data:/data" \
  -e TDT_AI_ENABLED=0 -e TDT_STT_ENABLED=0 --restart unless-stopped \
  ghcr.io/pcaro/tdt-local-docker:latest
```

Abre <http://IP-del-NAS:8788/>. La primera vez necesita internet para bajar las listas; después usa la copia
guardada en el volumen.

Con Compose, [`compose.yaml`](compose.yaml) ya viene listo: `docker compose up -d`.

## Unraid

**Opcional pero recomendado:** instala antes el plugin *Compose Manager* y usa el `compose.yaml`; es lo que menos
sorpresas da al actualizar.

Con plantilla (aparece como un contenedor normal, con su icono y sus campos):

1. **Docker** → *Add Container*.
2. En *Template* pega:
   `https://raw.githubusercontent.com/pcaro/tdt-local-docker/main/unraid/tdt-local.xml`
3. Ajusta el puerto si el 8788 está ocupado, deja `/mnt/user/appdata/tdt-local` como carpeta de datos y pulsa
   **Apply**.

El XML está en [`unraid/tdt-local.xml`](unraid/tdt-local.xml). Los cuatro campos de la plantilla
(`TDT_AI_ENABLED`, `TDT_STT_ENABLED`, `TDT_UPDATE_HOURS`, `TDT_AUTO_CHECK`) son los que de verdad se usan aquí.

## Ajustes: la web no deja guardarlos dentro de Docker

El programa solo escribe en `/api/settings` si la petición viene de `127.0.0.1`, y desde Docker llega con la IP del
bridge. La respuesta es siempre:

```text
POST /api/settings → 403 {"error": "los ajustes solo se pueden cambiar desde el propio equipo"}
```

Tres formas de vivir con ello, de menos a más incómoda:

1. **Variables de entorno** (lo normal). Cualquier ajuste de la pantalla «Ajustes» se fija con
   `TDT_<NOMBRE_EN_MAYÚSCULAS>` y, al estar fijado, la interfaz lo muestra de solo lectura. Ejemplos:
   `TDT_UPDATE_HOURS=12`, `TDT_EPG_ENABLED=0`, `TDT_AUTO_CHECK=1`, `TDT_LLM_URL=http://192.168.1.10:8080/v1`,
   `TDT_LLM_API_KEY=…` (así la clave no queda en `settings.json`).
2. **`docker exec`**, para un cambio puntual:
   ```bash
   docker exec tdt-local python -c "import urllib.request as u, json; \
     r=u.Request('http://127.0.0.1:8788/api/settings', data=json.dumps({'update_hours':12}).encode(), \
     headers={'Content-Type':'application/json'}); print(u.urlopen(r).read().decode())"
   ```
   (Dentro del contenedor `127.0.0.1` sí es loopback.)
3. **Túnel SSH + red host**: pon `network_mode: host` en el compose y luego
   `ssh -L 8788:127.0.0.1:8788 root@tu-nas`; así la petición entra como loopback y la UI guarda con normalidad.
   Con red `bridge` el túnel **no** sirve.

Leer ajustes, refrescar las listas, comprobar canales y añadir canales propios funciona sin problema.

## Qué no trae la imagen

- **Asistente de IA y subtítulos**: necesitan `llama.cpp` y `whisper-server`, que son programas aparte y piden CPU
  y RAM de verdad. Van desactivados con `TDT_AI_ENABLED=0` y `TDT_STT_ENABLED=0`. Si tienes un servidor de IA en la
  red, apunta `TDT_LLM_URL` a él y pon `TDT_AI_ENABLED=1`.
- **`ffmpeg`** sí está incluido (subtítulos y marcas de publicidad SCTE-35). Si no lo quieres, la imagen baja de
  ~580 MB a ~120 MB: `docker build --build-arg WITH_FFMPEG=0 -t tdt-local .`

## Avisos

- **Sin autenticación.** El propio autor lo dice: no lo expongas a internet. LAN o VPN, y nunca detrás de un
  reverse proxy público.
- El contenedor **no transcodifica**, solo hace de proxy: cualquier CPU sirve. A cambio, todo el vídeo pasa por el
  NAS, así que cada canal consume el doble de su bitrate en su tarjeta de red (multivisión de 4 canales a 6 Mbps ≈
  48 Mbps).
- Datos en el volumen (`/data`): listas, guía, canales propios y ajustes. Cópialo si quieres respaldar.

## Construir en local

```bash
docker build -t tdt-local .
docker run -d --name tdt-local -p 8788:8788 -v "$PWD/data:/data" tdt-local
```

## Actualizar a una versión nueva de tdt-local

La versión está fijada en el `Dockerfile` con `ARG TDT_VERSION` y el SHA-256 del código fuente. Para subirla:

```bash
V=1.4.0   # la que haya en https://github.com/cibernicola/tdt-local/releases
curl -sL "https://github.com/cibernicola/tdt-local/archive/refs/tags/v$V.tar.gz" | sha256sum
```

Cambia `TDT_VERSION` y `TDT_SHA256` en el `Dockerfile` y haz push a `main`: la Action construye y publica
`ghcr.io/pcaro/tdt-local-docker:$V` y `:latest` (amd64 y arm64).

## Cómo está montado

- [`Dockerfile`](Dockerfile) — `python:3.12-slim`, código fuente del release verificado por SHA-256, `pip install .`
- [`.github/workflows/image.yml`](.github/workflows/image.yml) — buildx multi-arquitectura y push a GHCR
- [`compose.yaml`](compose.yaml) — arranque típico
- [`unraid/tdt-local.xml`](unraid/tdt-local.xml) — plantilla de Unraid (con icono en `unraid/tdt-local.png`)

## Licencia

Apache-2.0. El código de tdt-local es de [cibernicola](https://github.com/cibernicola/tdt-local) y viaja sin
modificar; su `LICENSE` y su `NOTICE` se copian en la imagen (`/usr/share/doc/tdt-local/`). Ver [`NOTICE`](NOTICE).
Nada de esto da derecho sobre los canales ni sus emisiones.
