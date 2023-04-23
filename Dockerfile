FROM --platform=linux/x86-64 eclipse-temurin:17-focal
MAINTAINER dynatrace.com

ENV ONE_AGENT="oneAgent"
ENV OTEL_AGENT="otelAgent"

# otel config
ENV OTEL_RESOURCE_ATTRIBUTES="service.name=java-quickstart,service.version=1.0.1"
ENV OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=$TENANT_URL/api/v2/otlp/v1/traces
ENV OTEL_EXPORTER_OTLP_TRACES_HEADERS="Authorization=\"Api-Token $OTEL_TOKEN\""
ENV OTEL_METRICS_EXPORTER=none
ENV OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf

RUN mkdir -p /opt/app

RUN  apt-get update \
  && apt-get install -y unzip \
  && rm -rf /var/lib/apt/lists/*

ARG ENV_FILE=env
COPY ${ENV_FILE} /opt/env.sh

RUN export DT_AGENT_DOWNLOAD_TENANT_URL=`cat /opt/env.sh | grep DT_AGENT_DOWNLOAD_TENANT_URL | sed s/DT_AGENT_DOWNLOAD_TENANT_URL=//` && \
    export DT_AGENT_DOWNLOAD_TOKEN=`cat /opt/env.sh | grep DT_AGENT_DOWNLOAD_TOKEN | sed s/DT_AGENT_DOWNLOAD_TOKEN=//` &&  \
    curl --request GET -sL \
    --url "$DT_AGENT_DOWNLOAD_TENANT_URL/api/v1/deployment/installer/agent/unix/paas/latest?flavor=default&arch=x86&bitness=64&include=java&skipMetadata=true" \
    --header 'accept: */*' \
    --header "Authorization: Api-Token $DT_AGENT_DOWNLOAD_TOKEN" \
    --output '/opt/OneAgent.zip' && \
    rm /opt/env.sh
RUN cd /opt && unzip /opt/OneAgent.zip && rm /opt/OneAgent.zip

RUN wget -O /opt/opentelemetry-javaagent.jar https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.25.0/opentelemetry-javaagent.jar

RUN  echo "tenant tenant_id" >> /opt/agent/conf/standalone.conf && \
     echo "tenantToken tenant_token" >> /opt/agent/conf/standalone.conf &&  \
     echo "serverAddress {tenant_url:443/communication}" >> /opt/agent/conf/standalone.conf && \
     echo ""

RUN  sed -i s/tenant_id/$TENANT_ID/g /opt/agent/conf/standalone.conf && \
     sed -i s/tenant_token/$OA_TOKEN/g /opt/agent/conf/standalone.conf && \
     sed -i "s|tenant_url|$TENANT_URL|g" /opt/agent/conf/standalone.conf

ENV JAVA_TOOL_OPTIONS -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005
