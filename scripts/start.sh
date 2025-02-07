#!/bin/bash

envsubst < /tmp/nginx.conf > /etc/nginx/nginx.conf
envsubst < /tmp/default.conf > /etc/nginx/conf.d/default.conf
envsubst < /tmp/init-cron > /etc/cron.d/init-cron

/usr/bin/crontab /etc/cron.d/init-cron
cron

nginx -g 'daemon off;'