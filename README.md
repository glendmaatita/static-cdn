# static-cdn

Like [Thumbor](https://www.thumbor.org/), but works for static files.

## Getting Started

### Run

```
docker run -p 8080:8080 ghcr.io/glendmaatita/static-cdn 
```

Serve static files through cdn, e.g `http://localhost:8080/serve/https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@3.1.0/dist/tabler-icons.min.css`

### Mount Volume

```
docker run -p 8080:8080 -v .:/opt/data/static ghcr.io/glendmaatita/static-cdn 
```

Make sure the directory is writable

### Set Expire (in minutes)

```
docker run -p 8080:8080 -v .:/opt/data/static -e EXPIRE_TIME="5" ghcr.io/glendmaatita/static-cdn 
```