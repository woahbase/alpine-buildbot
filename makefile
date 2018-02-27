# {{{ -- meta

HOSTARCH      := x86_64# on travis.ci
ARCH          := $(shell uname -m | sed "s_armv7l_armhf_")# armhf/x86_64 auto-detect on build and run
OPSYS         := alpine
SHCOMMAND     := /bin/bash
SVCNAME       := buildbot
USERNAME      := woahbase
ROLE          := master# master / worker

DOCKERSRC     := $(OPSYS)-python3#
DOCKEREPO     := $(OPSYS)-$(SVCNAME)
IMAGETAG      := $(USERNAME)/alpine-build$(ROLE):$(ARCH)

WORKERNAME    := $(shell cat /etc/hostname)

REQUIRED_PIP  := "PyMySQL txrequests"#
REQUIRED_APK  := "curl git"# openssh-client git make docker

BUILDBOT_HOME := /home/alpine/buildbot-config

# for creating workers
MASTERADDRESS := localhost
PASSWORD      := insecurebydefault# worker credentials : WORKERNAME / PASSWORD

CNTNAME       := build$(ROLE) # name for container name : docker_name, hostname : name

# -- }}}

# {{{ -- flags

BUILDFLAGS := --rm --force-rm --compress -f $(CURDIR)/Dockerfile_$(ARCH) -t $(IMAGETAG) \
	--build-arg ARCH=$(ARCH) \
	--build-arg DOCKERSRC=$(DOCKERSRC) \
	--build-arg USERNAME=$(USERNAME) \
	--build-arg ROLE=$(ROLE) \
	--label org.label-schema.build-date=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ") \
	--label org.label-schema.name=$(DOCKEREPO) \
	--label org.label-schema.schema-version="1.0" \
	--label org.label-schema.url="https://woahbase.online/" \
	--label org.label-schema.usage="https://woahbase.online/\#/images/$(DOCKEREPO)" \
	--label org.label-schema.vcs-ref=$(shell git rev-parse --short HEAD) \
	--label org.label-schema.vcs-url="https://github.com/$(USERNAME)/$(DOCKEREPO)" \
	--label org.label-schema.vendor=$(USERNAME)

CACHEFLAGS := --no-cache=true --pull
MOUNTFLAGS := -v $(CURDIR)/config:$(BUILDBOT_HOME)
NAMEFLAGS  := --name docker_$(CNTNAME) --hostname $(CNTNAME)
OTHERFLAGS := # -v /etc/hosts:/etc/hosts:ro -v /etc/localtime:/etc/localtime:ro -e TZ=Asia/Kolkata
PORTFLAGS  := -p 9989:9989 -p 8010:8010 -p 9990:9990
PROXYFLAGS := --build-arg http_proxy=$(http_proxy) --build-arg https_proxy=$(https_proxy) --build-arg no_proxy=$(no_proxy)

RUNFLAGS   := -c 256 -m 256m \
	-e PGID=$(shell id -g) -e PUID=$(shell id -u) \
	-e WORKERNAME=$(WORKERNAME) -e BUILDBOT_HOME=$(BUILDBOT_HOME) \
	-e REQUIRED_PIP=$(REQUIRED_PIP) -e REQUIRED_APK=$(REQUIRED_APK) \
	-e http_proxy=$(http_proxy) -e https_proxy=$(https_proxy) -e no_proxy=$(no_proxy)

# -- }}}

# {{{ -- docker targets

all : run #setup first

build :
	echo "Building for $(ARCH) from $(HOSTARCH)";
	if [ "$(ARCH)" != "$(HOSTARCH)" ]; then make regbinfmt ; fi;
	docker build $(BUILDFLAGS) $(CACHEFLAGS) $(PROXYFLAGS) .

clean :
	docker images | awk '(NR>1) && ($$2!~/none/) {print $$1":"$$2}' | grep "$(USERNAME)/build$(ROLE)" | xargs -n1 docker rmi
	rm -rf ./config/*

logs :
	if [ "$(ROLE)" = "master" ]; \
	then \
		docker exec -it docker_$(CNTNAME) tail -f $(BUILDBOT_HOME)/$(WORKERNAME)-master/twistd.log; \
	elif [ "$(ROLE)" = "worker" ]; \
	then \
		docker exec -it docker_$(CNTNAME) tail -f $(BUILDBOT_HOME)/$(WORKERNAME)-worker/twistd.log; \
	fi;

pull :
	docker pull $(IMAGETAG)

push :
	docker push $(IMAGETAG); \
	if [ "$(ARCH)" = "$(HOSTARCH)" ]; \
		then \
		LATESTTAG=$$(echo $(IMAGETAG) | sed 's/:$(ARCH)/:latest/'); \
		docker tag $(IMAGETAG) $${LATESTTAG}; \
		docker push $${LATESTTAG}; \
	fi;

restart :
	docker ps -a | grep 'docker_$(CNTNAME)' -q && docker restart docker_$(CNTNAME) || echo "Service not running.";

rm : stop
	docker rm -f docker_$(CNTNAME)

run :
	if [ "$(ROLE)" = "master" ]; \
	then \
		docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) -e ROLE=$(ROLE) \
			$(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) $(IMAGETAG); \
	elif [ "$(ROLE)" = "worker" ]; \
	then \
		docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) -e ROLE=$(ROLE) \
			$(MOUNTFLAGS) $(OTHERFLAGS) $(IMAGETAG); \
	fi;

rshell :
	docker exec -u root -it docker_$(CNTNAME) $(SHCOMMAND)

setup :
	if [ "$(ROLE)" = "master" ]; \
	then \
		docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) \
			-e ROLE=$(ROLE) -e PASSWORD=$(PASSWORD) \
			$(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) $(IMAGETAG); \
	elif [ "$(ROLE)" = "worker" ]; \
	then \
		docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) -e ROLE=$(ROLE) \
			-e MASTERADDRESS=$(MASTERADDRESS) -e PASSWORD=$(PASSWORD) \
			$(MOUNTFLAGS) $(OTHERFLAGS) $(IMAGETAG); \
	fi;
shell :
	docker exec -it docker_$(CNTNAME) $(SHCOMMAND)

stop :
	docker stop -t 2 docker_$(CNTNAME)

test :
	if [ "$(ROLE)" = "master" ]; \
	then \
		docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) $(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) --entrypoint buildbot $(IMAGETAG) '--version'; \
	elif [ "$(ROLE)" = "worker" ]; \
	then \
		docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) $(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) --entrypoint buildbot-worker $(IMAGETAG) '--version'; \
	fi;

# -- }}}

# {{{ -- other targets

regbinfmt :
	docker run --rm --privileged multiarch/qemu-user-static:register --reset

# -- }}}
