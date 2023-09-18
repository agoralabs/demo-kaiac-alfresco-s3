#!/usr/bin/env bash

rm -rf ./data

rm -rf ./logs

docker volume rm $(docker volume ls -q)