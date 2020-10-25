# kdb+tick docker

The goal of this code is to demonstrate how to spin up an instance of a kdb+ data pipeline in a docker container.
It's currently a piece of learning work towards an easily deployable low footprint installation. 

As well as taking the tick code directly, this repo also relies on the work done dockerising embedPy and uses this as a base image for the Q installation.

Forked from https://github.com/KxSystems/kdb-tick
Using a base build from https://github.com/KxSystems/embedPy


# Tick changes

The base of the program is an almost vanilla installation of kdb+tick.
The following changes have been made (so far): -
-  time column is expected to be `timestamp` instead of `timespan`.
- Added sym.q containing trade and quote tables
- Added feed.q to publish some data

In order to start up the system you can run the following commands
(TODO - TP port is currently hardcoded into the feed)

```
cd $QTICKHOME/kdb-tick
nohup q tick.q sym  .  -p 5010	< /dev/null > $QTICKHOME/kdb-tick/tick.log 2>&1 &  
nohup q tick/r.q :5010 -p 5011	< /dev/null > $QTICKHOME/kdb-tick/rdb.log 2>&1 &
nohup q sym            -p 5012	< /dev/null > $QTICKHOME/kdb-tick/hdb.log 2>&1 &
nohup q tick/feed.q  < /dev/null > $QTICKHOME/kdb-tick/feed.log 2>&1 &
```

# Dockerized q

First stage in development is to get embedPy running
I created my own build locally for this using the instructions

I also created an environment file so that I could build and run the application easily.
This creates auto answers for the license questions and I've included an example here.

to run a stock docker container using the environment files, create `mytick.env` from the example file and run

```docker run --env-file mytick.env -ti kxsys/embedPy```

```
bash-3.2$ docker run --env-file mytick.env  -ti kxsys/embedpy
KDB+ 3.6 2018.06.14 Copyright (C) 1993-2018 Kx Systems
l64/ 2()core 1991MB kx XXXXXXXX XXX.XXX.XXX.XXXX EXPIRE 2021.04.09 peteclarkez@XXX.com KOD #XXXXXXX

q)
```

> Note: this will create a new container each time.

# Dockerized Tick


Finally to merge the tick system and docker container, a new Dockerfile has been introduced.

This file copies the tick system to the appropriate folder & also has a shell script to run processes.

In order to run this up, first build the image and then run the container

```
docker build -t kdb-tick -f docker/Dockerfile .
docker run --env-file mytick.env -p 5010:5010 -p 5011:5011 -ti kdb-tick
```

# TODO

- Properly test HDB over longer period
- Add GW processes to allow a single entry point
