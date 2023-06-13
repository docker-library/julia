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
ENV JULIA_VERSION 1.9.1

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
# https://julialang-s3.julialang.org/bin/checksums/julia-1.9.1.sha256
	arch="$(dpkg --print-architecture)"; \
	case "$arch" in \
		'amd64') \
			url='https://julialang-s3.julialang.org/bin/linux/x64/1.9/julia-1.9.1-linux-x86_64.tar.gz'; \
			sha256='cde14a58f899251f30cfced87055626f44845780659ebe8d50cbc4c67b31997c'; \
			;; \
		'arm64') \
			url='https://julialang-s3.julialang.org/bin/linux/aarch64/1.9/julia-1.9.1-linux-aarch64.tar.gz'; \
			sha256='b643ccd3e2a5960f7ce7055243743d0a39badda3974bce3d77861dd363badd10'; \
			;; \
		'i386') \
			url='https://julialang-s3.julialang.org/bin/linux/x86/1.9/julia-1.9.1-linux-i686.tar.gz'; \
			sha256='662111251fe82fca5a23321cbe218d98c23683e76dc32e1a9756aa436de97890'; \
			;; \
		'ppc64el') \
			url='https://julialang-s3.julialang.org/bin/linux/ppc64le/1.9/julia-1.9.1-linux-ppc64le.tar.gz'; \
			sha256='391aba8e239bfa29c1d96e2d81d6ec50ab5b924ac2132ef934c556e0a3329fc5'; \
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
