[![build status][251]][232] [![commit][255]][231] [![version:x86_64][256]][235] [![size:x86_64][257]][235] [![version:armhf][258]][236] [![size:armhf][259]][236]
[![version:x86_64][260]][237] [![size:x86_64][261]][237] [![version:armhf][262]][238] [![size:armhf][263]][238]

## [Alpine-Buildbot][234]
#### Container for Alpine Linux + Python3 + Buildbot
---

This [image][233] serves as the base container for running
a [Buildbot][135] instance ( [`master/localworker`][233] or standalone
[`worker`][239] roles ) to build applications, run tasks, and other
automations.

Based on [Alpine Linux][131] from my [alpine-python3][132] image with
the [s6][133] init system [overlayed][134] in it.

The image is tagged respectively for the following architectures/roles,
* [Buildmaster][233] - to run the master node
    * **armhf**
    * **x86_64** (retagged as the `latest` )

* [Buildworker][239] - to run a standalone worker on other devices.
    * **armhf**
    * **x86_64** (retagged as the `latest` )

**armhf** builds have embedded binfmt_misc support and contain the
[qemu-user-static][105] binary that allows for running it also inside
an x64 environment that has it.

---
#### Get the Image
---

Pull the master image for your architecture it's already available from
Docker Hub.

```
# make pull
docker pull woahbase/alpine-buildmaster:x86_64
```
or just pull the worker,

```
# make pull ROLE=worker
docker pull woahbase/alpine-buildworker:x86_64
```

---
#### Configuration Defaults
---

* This images already has a user `alpine` configured to drop
  privileges to the passed `PUID`/`PGID` which is ideal if its
  used to run in non-root mode. That way you only need to specify
  the values at runtime and pass the `-u alpine` if need be. (run
  `id` in your terminal to see your own `PUID`/`PGID` values.)

* The env variable `ROLE` determines if you are running a master
  or worker. This also determines what image you'll be running
  when used with the `makefile`.

* The `WORKERNAME` variable determines the name of the worker, or
  the default worker in case of master, defaults to `hostname`.

* For the master node, mount the configurations at the
  `BUILDBOT_HOME` directory inside the container, by default it is
  `/home/alpine/buildbot-config`. This is optional for workers,
  however make sure you have enough cpu power and memory for the
  workers to do the heavy lifting if required.

* To create a default master check the `setup` target in
  the makefile. This will generate a master with default
  configurations, which also includes a remote worker, so for
  setting up the worker credentials you need to provide the
  password in the env variable `PASSWORD`.

* The above can also setup a worker depending on the `ROLE`
  variable, for workers, you need to pass the `MASTERADDRESS` and
  `PASSWORD`.

* Before the master or worker is started, there is option to
  install project dependencies as APK or PIP packages if required.
  The env variables `REQUIRED_APK` and `REQUIRED_PIP` installs the
  list of packages from alpine repository or pip respectively.

* If you need to perform some tasks before the services are
  started, consider dropping a `cont-init` script inside
  `/etc/cont-init.d/`, the name should begin with atleast `20-*`
  as `10-setup` is already taken.

---
#### Setup / Run
---

If you want to run images for other architectures, you will need
to have binfmt support configured for your machine. [**multiarch**][104],
has made it easy for us containing that into a docker container.

```
# make regbinfmt
docker run --rm --privileged multiarch/qemu-user-static:register --reset
```

Without the above, you can still run the image that is made for your
architecture, e.g for an x86_64 machine..

Run `setup` to generate the default configurations if you don't
already have one.

```
# make setup ROLE=master PASSWORD=insecurebydefault
docker run --rm -it \
  --name docker_buildmaster --hostname buildmaster \
  -c 256 -m 256m \
  -e BUILDBOT_HOME=/home/alpine/buildbot-config \
  -e PASSWORD=insecurebydefault \
  -e PGID=1000 -e PUID=1000 \
  -e ROLE=master \
  -e WORKERNAME=buildbot \
  -p 9989:9989 -p 8010:8010 -p 9990:9990 \
  -v config:/home/alpine/buildbot-config \
  woahbase/alpine-buildmaster:x86_64
```

for the worker,

```
# make setup ROLE=worker PASSWORD=insecurebydefault
docker run --rm -it \
  --name docker_buildworker --hostname buildworker \
  -e BUILDBOT_HOME=/home/alpine/buildbot-config \
  -e MASTERADDRESS=localhost \
  -e PASSWORD=insecurebydefault \
  -e PGID=1000 -e PUID=1000 \
  -e ROLE=worker \
  -e WORKERNAME=buildbot \
  -v config:/home/alpine/buildbot-config \
  woahbase/alpine-buildworker:x86_64
```

Running `make` starts the service.

```
# make ROLE=master REQUIRED_PIP="txrequests" REQUIRED_APK="curl git"
docker run --rm -it \
  --name docker_buildmaster --hostname buildmaster \
  -c 256 -m 256m \
  -e BUILDBOT_HOME=/home/alpine/buildbot-config \
  -e PGID=1000 -e PUID=1000 \
  -e REQUIRED_APK="curl git" \
  -e REQUIRED_PIP="txrequests" \
  -e ROLE=master \
  -e WORKERNAME=buildbot \
  -v config:/home/alpine/buildbot-config  \
  woahbase/alpine-buildmaster:x86_64
```

or,

```
# make ROLE=worker REQUIRED_PIP="" REQUIRED_APK="curl git make"
docker run --rm -it \
  --name docker_buildworker --hostname buildworker \
  -e BUILDBOT_HOME=/home/alpine/buildbot-config \
  -e PGID=1000 -e PUID=1000 \
  -e REQUIRED_APK="curl git make" \
  -e REQUIRED_PIP="" \
  -e ROLE=worker \
  -e WORKERNAME=buildbot \
  -v config:/home/alpine/buildbot-config \
  woahbase/alpine-buildworker:x86_64
```

Stop the container with a timeout, (defaults to 2 seconds)

```
# make stop ROLE=master
docker stop -t 2 docker_buildmaster

# make stop ROLE=worker
docker stop -t 2 docker_buildworker
```

Removes the container, (always better to stop it first and `-f`
only when needed most)

```
# make rm ROLE=master
docker rm -f docker_buildmaster

# make rm ROLE=worker
docker rm -f docker_buildworker
```

Restart the container with

```
# make restart ROLE=master
docker restart docker_buildmaster

# make restart ROLE=worker
docker restart docker_buildworker
```

---
#### Shell access
---

Get a shell inside a already running container,

```
# make shell ROLE=master
docker exec -it docker_buildmaster /bin/bash

# make shell ROLE=worker
docker exec -it docker_buildworker /bin/bash
```

set user or login as root,

```
# make rshell ROLE=master
docker exec -u root -it docker_buildmaster /bin/bash

# make rshell ROLE=worker
docker exec -u root -it docker_buildworker /bin/bash
```

To check logs of a running container in real time

```
# make logs ROLE=master
docker exec -it docker_buildmaster \
  tail -f /home/alpine/buildbot-config/$(WORKERNAME)-master/twistd.log

# make logs ROLE=worker
docker exec -it docker_buildworker \
  tail -f /home/alpine/buildbot-config/$(WORKERNAME)-worker/twistd.log
```

---
### Development
---

If you have the repository access, you can clone and
build the image yourself for your own system, and can push after.

---
#### Setup
---

Before you clone the [repo][231], you must have [Git][101], [GNU make][102],
and [Docker][103] setup on the machine.

```
git clone https://github.com/woahbase/alpine-buildbot
cd alpine-buildbot
```
You can always skip installing **make** but you will have to
type the whole docker commands then instead of using the sweet
make targets.

---
#### Build
---

You need to have binfmt_misc configured in your system to be able
to build images for other architectures.

Otherwise to locally build the image for your system.
[`ARCH` defaults to `x86_64`, need to be explicit when building
for other architectures.]

```
# make ARCH=x86_64 ROLE=master build
# sets up binfmt if not x86_64
docker build --rm --force-rm --compress \
  --no-cache=true --pull \
  -f /home/arch/software/woahbase/alpine-buildbot/Dockerfile_x86_64 \
  --build-arg ARCH=x86_64 \
  --build-arg DOCKERSRC=alpine-python3 \
  --build-arg PGID=1000 \
  --build-arg PUID=1000 \
  --build-arg ROLE=master \
  --build-arg USERNAME=woahbase \
  -t woahbase/alpine-buildmaster:x86_64 \
  .
```
and for the worker,

```
# make ARCH=x86_64 ROLE=worker build
# sets up binfmt if not x86_64
docker build --rm --force-rm --compress \
  --no-cache=true --pull \
  -f /home/arch/software/woahbase/alpine-buildbot/Dockerfile_x86_64 \
  --build-arg ARCH=x86_64 \
  --build-arg DOCKERSRC=alpine-python3 \
  --build-arg PGID=1000 \
  --build-arg PUID=1000 \
  --build-arg ROLE=worker \
  --build-arg USERNAME=woahbase \
  -t woahbase/alpine-buildworker:x86_64 \
  .
```

To check if its working..

```
# make ARCH=x86_64 ROLE=master test
docker run --rm -it \
  --name docker_buildmaster --hostname buildmaster \
  -e WORKERNAME=buildbot \
  -e REQUIRED_PIP="PyMySQL txrequests" \
  -e REQUIRED_APK="curl git" \
  --entrypoint buildbot \
  woahbase/alpine-buildmaster:x86_64 \
  '--version'

# make ARCH=x86_64 ROLE=worker test
docker run --rm -it \
  --name docker_buildworker --hostname buildworker \
  -e WORKERNAME=buildbot \
  --entrypoint buildbot-worker \
  woahbase/alpine-buildworker:x86_64 \
  '--version'
```

And finally, if you have push access,

```
# make ARCH=x86_64 ROLE=master push
docker push woahbase/alpine-buildmaster:x86_64

# make ARCH=x86_64 ROLE=worker push
docker push woahbase/alpine-buildworker:x86_64
```

---
### Maintenance
---

Sources at [Github][106]. Built at [Travis-CI.org][107] (armhf / x64 builds). Images at [Docker hub][108]. Metadata at [Microbadger][109].

Maintained by [WOAHBase][204].

[101]: https://git-scm.com
[102]: https://www.gnu.org/software/make/
[103]: https://www.docker.com
[104]: https://hub.docker.com/r/multiarch/qemu-user-static/
[105]: https://github.com/multiarch/qemu-user-static/releases/
[106]: https://github.com/
[107]: https://travis-ci.org/
[108]: https://hub.docker.com/
[109]: https://microbadger.com/

[131]: https://alpinelinux.org/
[132]: https://hub.docker.com/r/woahbase/alpine-python2
[133]: https://skarnet.org/software/s6/
[134]: https://github.com/just-containers/s6-overlay
[135]: https://buildbot.net/

[201]: https://github.com/woahbase
[202]: https://travis-ci.org/woahbase/
[203]: https://hub.docker.com/u/woahbase
[204]: https://woahbase.online/

[231]: https://github.com/woahbase/alpine-buildbot
[232]: https://travis-ci.org/woahbase/alpine-buildbot
[233]: https://hub.docker.com/r/woahbase/alpine-buildmaster
[234]: https://woahbase.online/#/images/alpine-buildbot
[235]: https://microbadger.com/images/woahbase/alpine-buildmaster:x86_64
[236]: https://microbadger.com/images/woahbase/alpine-buildmaster:armhf
[237]: https://microbadger.com/images/woahbase/alpine-buildworker:x86_64
[238]: https://microbadger.com/images/woahbase/alpine-buildworker:armhf
[239]: https://hub.docker.com/r/woahbase/alpine-buildworker

[251]: https://travis-ci.org/woahbase/alpine-buildbot.svg?branch=master

[255]: https://images.microbadger.com/badges/commit/woahbase/alpine-buildmaster.svg

[256]: https://images.microbadger.com/badges/version/woahbase/alpine-buildmaster:x86_64.svg
[257]: https://images.microbadger.com/badges/image/woahbase/alpine-buildmaster:x86_64.svg

[258]: https://images.microbadger.com/badges/version/woahbase/alpine-buildmaster:armhf.svg
[259]: https://images.microbadger.com/badges/image/woahbase/alpine-buildmaster:armhf.svg

[260]: https://images.microbadger.com/badges/version/woahbase/alpine-buildworker:x86_64.svg
[261]: https://images.microbadger.com/badges/image/woahbase/alpine-buildworker:x86_64.svg

[262]: https://images.microbadger.com/badges/version/woahbase/alpine-buildworker:armhf.svg
[263]: https://images.microbadger.com/badges/image/woahbase/alpine-buildworker:armhf.svg
