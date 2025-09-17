[![Docker images build](https://github.com/lj020326/docker-ansible-test/actions/workflows/build-images.yml/badge.svg)](https://github.com/lj020326/docker-ansible-test/actions/workflows/build-images.yml)
[![License](https://img.shields.io/badge/license-MIT-brightgreen.svg?style=flat)](LICENSE)

# docker-ansible-test

Ansible in a Docker container.

The ansible enabled docker image used in examples here can be found on [dockerhub](https://hub.docker.com/repository/docker/lj020326/ansible-test).

Running Ansible in Docker makes a lot of sense: its super quick to get going, and you can just expose the ports needed to access via the web interface. But it also makes sense to run your test cases/builds inside Docker as well: its compartmentalised, with full control of the environment inside.

## Status

[![GitHub issues](https://img.shields.io/github/issues/lj020326/docker-ansible-test.svg?style=flat)](https://github.com/lj020326/docker-ansible-test/issues)
[![GitHub stars](https://img.shields.io/github/stars/lj020326/docker-ansible-test.svg?style=flat)](https://github.com/lj020326/docker-ansible-test/stargazers)
[![Docker Pulls - lj020326/ansible-runner](https://img.shields.io/docker/pulls/lj020326/ansible-test.svg?style=flat)](https://hub.docker.com/repository/docker/lj020326/ansible-test/)

### Docker in Docker
It's possible to run into some problems with Docker running inside another Docker container ([more info here](https://github.com/lj020326/pipeline-automation-lib/blob/main/docs/docker-in-docker-the-good-the-bad-and-the-fix.md)). A better approach is that a container does not run its own Docker daemon, but connects to the Docker daemon of the host system. That means, you will have a Docker CLI in the container, as well as on the host system, but they both connect to one and the same Docker daemon. At any time, there is only one Docker daemon running in your machine, the one running on the host system. This [article](https://github.com/lj020326/pipeline-automation-lib/blob/main/docs/docker-inside-a-docker-container.md) really helped me understand this. To do this, you just bind mount to the host system daemon, using this argument when you run Docker: `-v /var/run/docker.sock:/var/run/docker.sock`

### Running the container
The easiest way is to pull from Docker Hub:

```shell
$ docker run -it -p 8080:8080 -p 50000:50000 \
    -v ansible_home:/var/ansible_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --restart unless-stopped \
    lj020326/docker-ansible-test
```

Alternatively, you can clone this repository, build the image from the Dockerfile, and then run the container

```shell
$ docker build -t ansible-test .

$ docker run -it -p 8080:8080 -p 50000:50000 \
    -v ansible_home:/var/ansible_home \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --restart unless-stopped \
    ansible-test
```

## Contact

[![Linkedin](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/leejjohnson/)
