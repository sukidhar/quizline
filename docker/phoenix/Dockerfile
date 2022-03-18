FROM elixir:1.12.2-alpine 

# install build dependencies
RUN \
    apk add --no-cache \
    netcat-openbsd \
    build-base \
    npm \
    git \
    python3 \
    make \
    cmake \
    openssl-dev \ 
    libsrtp-dev \
    libnice-dev \
    ffmpeg-dev \
    opus-dev \
    inotify-tools\
    clang-dev

# change to server directory
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force



# ENTRYPOINT [ "/app/container/init.sh" ]

