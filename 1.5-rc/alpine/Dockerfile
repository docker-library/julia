FROM alpine:latest

RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache wget tar

ENV JULIA_PATH /usr/local/julia 
ENV PATH $JULIA_PATH/bin:$PATH

# https://julialang.org/downloads/
ENV JULIA_VERSION 1.5.0-rc1
ENV JULIA_URL https://julialang-s3.julialang.org/bin/musl/x64/1.5/julia-${JULIA_VERSION}-musl-x86_64.tar.gz
ENV JULIA_GPG 43e3a30133aee14657cc8984cc51e8f308ac1978e4c5986f4c976b8e8747194f

RUN mkdir ${JULIA_PATH} && \
    wget -q ${JULIA_URL} && \ 
    echo "${JULIA_GPG}  julia-${JULIA_VERSION}-musl-x86_64.tar.gz" | sha256sum -c - && \ 
    tar -xzf "julia-${JULIA_VERSION}-musl-x86_64.tar.gz" -C ${JULIA_PATH} --strip-components=1 && \ 
    rm "julia-${JULIA_VERSION}-musl-x86_64.tar.gz" && \
    julia --version # smoke test


CMD ["julia"]
