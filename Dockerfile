FROM debian:jessie

ENV JULIA_PATH /usr/local/julia
ENV JULIA_VERSION 0.3.6

RUN mkdir $JULIA_PATH \
	&& apt-get update && apt-get install -y curl \
	&& curl -sSL "https://julialang.s3.amazonaws.com/bin/linux/x64/${JULIA_VERSION%[.-]*}/julia-${JULIA_VERSION}-linux-x86_64.tar.gz" \
		| tar -xz -C $JULIA_PATH --strip-components 1 \
	&& apt-get purge -y --auto-remove \
		-o APT::AutoRemove::RecommendsImportant=false \
		-o APT::AutoRemove::SuggestsImportant=false curl \
	&& rm -rf /var/lib/apt/lists/*


ENV PATH $JULIA_PATH/bin:$PATH

CMD ["julia"]
