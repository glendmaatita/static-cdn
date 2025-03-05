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

## Upload

static-cdn also support upload to S3-compatible API such as AWS S3, MinIO, or Digital Ocean. Pass Key and Secret when run docker

```
docker run -p 8080:8080 -e AWS_ACCESS_KEY_ID=key-id -e AWS_SECRET_ACCESS_KEY=access-key static-cdn
```

Example of Python code to upload files to S3

```
import boto3
import logging

# Proxy-based endpoint
endpoint_url = "http://localhost:8080/upload/s3.ap-southeast-3.amazonaws.com"

s3 = boto3.client(
    "s3",
    endpoint_url=endpoint_url,
    aws_access_key_id="key-id",
    aws_secret_access_key="access-key",
    region_name="ap-southeast-3"
)

# Upload file (ensure the path is correct)
s3.upload_file("source.txt", bucket-name, "destination.txt")

print("File uploaded successfully!")

```