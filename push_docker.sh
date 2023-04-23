#!/bin/bash
docker image build --platform linux/amd64 -t ivangudak096/dt-java-agents:latest .
docker push ivangudak096/dt-java-agents:latest

#docker image build --platform linux/arm64 -t ivangudak096/dt-java-agents:arm64 .
#docker push ivangudak096/dt-java-agents:arm64
