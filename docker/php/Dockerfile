FROM php:8.4-fpm-alpine

# 让 apk/pecl 走宿主机代理下载，绕过污染 DNS（Clash 默认 127.0.0.1:7890）。
# 构建时通过 --build-arg 传入，或在 compose build.args 指定。
ARG http_proxy
ARG https_proxy
ARG no_proxy
ENV http_proxy=${http_proxy} \
    https_proxy=${https_proxy} \
    no_proxy=${no_proxy}

# apk 源：默认官方源（Anycast）。若官方源仍超时，启用清华镜像：
# RUN sed -i 's|dl-cdn.alpinelinux.org|mirrors.tuna.tsinghua.edu.cn/alpine|g' /etc/apk/repositories
# $PHPIZE_DEPS 提供编译 pecl 扩展所需的 autoconf/gcc/make，装完即清理以减小镜像
RUN apk add --no-cache \
    postgresql-dev \
    libpq \
    icu-dev \
    git \
    unzip \
    bash \
    gmp-dev \
    $PHPIZE_DEPS \
    && docker-php-ext-install -j$(nproc) \
    pdo_pgsql \
    pgsql \
    bcmath \
    intl \
    gmp \
    && printf '\n' | pecl install redis \
    && docker-php-ext-enable redis \
    && rm -rf /tmp/pear \
    && apk del $PHPIZE_DEPS

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

RUN addgroup -g 1000 www && adduser -u 1000 -G www -D www

USER www
