#!/bin/bash
docker image build --platform linux/amd64 -t ihudak/dt-java-agents:latest .
docker push ihudak/dt-java-agents:latest

docker image build --platform linux/arm64 -t ihudak/dt-java-agents:arm64 .
docker push ihudak/dt-java-agents:arm64
