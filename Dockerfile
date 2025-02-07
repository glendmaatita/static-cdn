FROM docker.io/debian:12.9-slim as base

WORKDIR /app

ENV DNS_RESOLVER="8.8.8.8 8.8.8.4"
ENV ENABLE_IPV6="off"
ENV EXPIRE_TIME="360"

RUN apt update -y && apt install -y nginx nginx-extras lua5.1 liblua5.1-dev wget gnupg ca-certificates zip build-essential gettext cron
RUN wget -O - https://openresty.org/package/pubkey.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/openresty.gpg && \
    codename=`grep -Po 'VERSION="[0-9]+ \(\K[^)]+' /etc/os-release` && \
    echo "deb http://openresty.org/package/debian $codename openresty" \
    | tee /etc/apt/sources.list.d/openresty.list

RUN apt update -y && apt install -y openresty

# install luarocks
RUN wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz && \
    tar zxpf luarocks-3.11.1.tar.gz && \
    cd luarocks-3.11.1 && ./configure && make && make install && \
    luarocks install lua-resty-http && luarocks install lua-resty-string

    # cleanup
RUN rm luarocks-3.11.1.tar.gz && rm -rf luarocks-3.11.1 && \
    apt remove -y wget gnupg zip build-essential && apt autoremove -y && apt clean -y && rm -rf /var/lib/apt/lists/*

FROM base as runner
COPY ./nginx/nginx.conf /tmp/nginx.conf
COPY ./nginx/default.conf /tmp/default.conf
COPY ./scripts/init-cron /tmp/init-cron
COPY ./scripts/cdn.lua /etc/nginx/conf.d/lua/cdn.lua
COPY ./scripts/start.sh /app/start.sh

RUN chmod +x /app/start.sh && \
    chmod 0644 /tmp/init-cron && \
    touch /var/log/cron.log && \
    mkdir -p /opt/data/static && \
    chmod 777 -R /opt/data/static

ENTRYPOINT [ "/app/start.sh" ]