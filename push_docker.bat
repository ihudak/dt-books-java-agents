docker image build --platform linux/amd64 -t ivangudak096/dt-java-agents-x64:latest .
docker push ivangudak096/dt-java-agents-x64:latest

docker image build --platform linux/arm64/v8 -t ivangudak096/dt-java-agents-arm64:latest .
docker push ivangudak096/dt-java-agents-arm64:latest
