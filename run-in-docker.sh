#!/bin/bash
IMAGE_NAME=replace-ssh-key
is_built(){
  docker images|awk '{print $1}'|grep $IMAGE_NAME
}
build(){
  docker build -t $IMAGE_NAME .
}

if [ "" = "$(is_built)" ];then build;fi
docker run --rm -ti -v $HOME/.ssh:/root/.ssh -v $PWD:/work $IMAGE_NAME "$@"
