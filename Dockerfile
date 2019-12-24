FROM node:10.14-alpine

RUN apk add --no-cache \
    git curl tar \
    openssh-client


######### golang
ARG GO_VERSION="1.13.5"

# target go version
ENV go_version="$GO_VERSION" \
	bootstrap_go_version="1.4"

# other variables
ENV go_repository="https://go.googlesource.com/go" \
	bootstrap_go_branch="release-branch.go$bootstrap_go_version" \
	bootstrap_go_dir="/go1.4" \
	go_branch="go$go_version" \
	go_dir="/go-$go_version"

# install packages,
# clone bootstrap go (1.4) repository,
# build bootstrap go (1.4),
# build go with bootstrap go,
# then remove unneeded files
RUN apk add --no-cache bash git gcc libc-dev linux-headers && \
	git clone -b $bootstrap_go_branch $go_repository $bootstrap_go_dir && \
	cd $bootstrap_go_dir/src && \
	./make.bash && \
	git clone -b $go_branch $go_repository $go_dir && \
	cd $go_dir/src && \
	GOROOT_BOOTSTRAP=$bootstrap_go_dir ./make.bash && \
	rm -rf $bootstrap_go_dir && \
	rm -rf $go_dir/.git $go_dir/pkg/obj $go_dir/pkg/bootstrap && \
	mkdir /go

# set PATH, GOROOT and GOPATH
ENV GOROOT="$go_dir" \
	GOPATH="/go" \
	PATH="$PATH:$go_dir/bin"

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

######### golang end

RUN apk add --no-cache make py-pip bash jq ca-certificates
RUN pip install --no-cache-dir awscli awslogs

ENV DOCKER_CHANNEL stable
ENV DOCKER_VERSION 17.06.1-ce
# TODO ENV DOCKER_SHA256
# https://github.com/docker/docker-ce/blob/5b073ee2cf564edee5adca05eee574142f7627bb/components/packaging/static/hash_files !!
# (no SHA file artifacts on download.docker.com yet as of 2017-06-07 though)

RUN set -ex; \
    # why we use "curl" instead of "wget":
    # + wget -O docker.tgz https://download.docker.com/linux/static/stable/x86_64/docker-17.03.1-ce.tgz
    # Connecting to download.docker.com (54.230.87.253:443)
    # wget: error getting response: Connection reset by peer
    apk add --no-cache --virtual .fetch-deps \
    curl \
    tar \
    ; \
    \
    # this "case" statement is generated via "update.sh"
    apkArch="$(apk --print-arch)"; \
    case "$apkArch" in \
    x86_64) dockerArch='x86_64' ;; \
    s390x) dockerArch='s390x' ;; \
    *) echo >&2 "error: unsupported architecture ($apkArch)"; exit 1 ;;\
    esac; \
    \
    if ! curl -fL -o docker.tgz "https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${dockerArch}/docker-${DOCKER_VERSION}.tgz"; then \
    echo >&2 "error: failed to download 'docker-${DOCKER_VERSION}' from '${DOCKER_CHANNEL}' for '${dockerArch}'"; \
    exit 1; \
    fi; \
    \
    tar --extract \
    --file docker.tgz \
    --strip-components 1 \
    --directory /usr/local/bin/ \
    ; \
    rm docker.tgz; \
    \
    apk del .fetch-deps; \
    \
    dockerd -v; \
    docker -v

# Download and install the cloud sdk
RUN apk add --update openssl
RUN wget https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz --no-check-certificate \
    && tar zxvf google-cloud-sdk.tar.gz \
    && rm google-cloud-sdk.tar.gz \
    && ls -l \
    && ./google-cloud-sdk/install.sh --usage-reporting=true --path-update=true

# Add gcloud to the path
ENV PATH /google-cloud-sdk/bin:$PATH

# Configure gcloud for your project
RUN yes | gcloud components update
RUN yes | gcloud components update preview
# 
RUN gcloud components install kubectl
# heroku cli install
RUN npm install -g heroku-cli

# yarn install
RUN npm install -g yarn

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sh"]
