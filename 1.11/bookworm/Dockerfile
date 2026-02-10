#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM debian:bookworm-slim

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
# ERROR: no download agent available; install curl, wget, or fetch
		curl \
	; \
	rm -rf /var/lib/apt/lists/*

ENV JULIA_PATH /usr/local/julia
ENV PATH $JULIA_PATH/bin:$PATH

# https://julialang.org/juliareleases.asc
# Julia (Binary signing key) <buildbot@julialang.org>
ENV JULIA_GPG 3673DF529D9049477F76B37566E3C7DC03D6E495

# https://julialang.org/downloads/
ENV JULIA_VERSION 1.11.9

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		gnupg \
	; \
	rm -rf /var/lib/apt/lists/*; \
	\
# https://julialang.org/downloads/#julia-command-line-version
# https://julialang-s3.julialang.org/bin/checksums/julia-1.11.9.sha256
	arch="$(dpkg --print-architecture)"; \
	case "$arch" in \
		'amd64') \
			url='https://julialang-s3.julialang.org/bin/linux/x64/1.11/julia-1.11.9-linux-x86_64.tar.gz'; \
			sha256='b36363356d7a05eaf8b7b9e7a91c710f6bd3d2940be4d4e6d14b9a9f2927de35'; \
			;; \
		'i386') \
			url='https://julialang-s3.julialang.org/bin/linux/x86/1.11/julia-1.11.9-linux-i686.tar.gz'; \
			sha256='74df5031a93bce45e30582a71bf70f4ba983ff42f6eaf54eb9effb6e124604ca'; \
			;; \
		'arm64') \
			url='https://julialang-s3.julialang.org/bin/linux/aarch64/1.11/julia-1.11.9-linux-aarch64.tar.gz'; \
			sha256='a2071f0654d1d6af4381cba650b9f790f5f8bb7a570e51e378de8bcf67ff623e'; \
			;; \
		'ppc64el') \
			url='https://julialang-s3.julialang.org/bin/linux/ppc64le/1.11/julia-1.11.9-linux-ppc64le.tar.gz'; \
			sha256='3c25d5bf70d65da5859d65b34d17646dd1b3f1b50ea2090d13e63171d6dbf861'; \
			;; \
		*) \
			echo >&2 "error: current architecture ($arch) does not have a corresponding Julia binary release"; \
			exit 1; \
			;; \
	esac; \
	\
	curl -fL -o julia.tar.gz.asc "$url.asc"; \
	curl -fL -o julia.tar.gz "$url"; \
	\
	echo "$sha256 *julia.tar.gz" | sha256sum --strict --check -; \
	\
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$JULIA_GPG"; \
	gpg --batch --verify julia.tar.gz.asc julia.tar.gz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" julia.tar.gz.asc; \
	\
	mkdir "$JULIA_PATH"; \
	tar -xzf julia.tar.gz -C "$JULIA_PATH" --strip-components 1; \
	rm julia.tar.gz; \
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
# smoke test
	julia --version

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["julia"]
