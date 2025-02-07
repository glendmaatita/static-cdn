#!/bin/bash

envsubst < /tmp/nginx.conf > /etc/nginx/nginx.conf
envsubst < /tmp/default.conf > /etc/nginx/conf.d/default.conf

nginx -g 'daemon off;'