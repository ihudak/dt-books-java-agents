FROM eclipse-temurin:17-focal
MAINTAINER dynatrace.com

ENV ONE_AGENT="oneAgent"
ENV OTEL_AGENT="otelAgent"

# otel config
RUN echo "export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=\$TENANT_URL/api/v2/otlp/v1/traces" >> /opt/otel.sh && \
    echo "export OTEL_EXPORTER_OTLP_TRACES_HEADERS=Authorization=\"Api-Token \$OTEL_TOKEN\"" >> /opt/otel.sh && \
    chmod +x /opt/otel.sh

ENV OTEL_RESOURCE_ATTRIBUTES="service.name=java-quickstart,service.version=1.0.1"
#ENV OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=$TENANT_URL/api/v2/otlp/v1/traces
#ENV OTEL_EXPORTER_OTLP_TRACES_HEADERS="Authorization=\"Api-Token $OTEL_TOKEN\""
ENV OTEL_METRICS_EXPORTER=none
ENV OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf

RUN mkdir -p /opt/app && mkdir -p  /var/lib/dynatrace/oneagent

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
    --output '/var/lib/dynatrace/oneagent/OneAgent.zip' && \
    curl -X GET $DT_AGENT_DOWNLOAD_TENANT_URL/api/v1/deployment/installer/agent/connectioninfo \
    -H "accept: application/json" \
    -H "Authorization: Api-Token $DT_AGENT_DOWNLOAD_TOKEN" | \
    grep tenantToken | \
    sed s/\ \ \"tenantToken\"\ :\ \"// | sed s/\",// > /opt/tenant.token && \
    rm /opt/env.sh

RUN cd /var/lib/dynatrace/oneagent && unzip /var/lib/dynatrace/oneagent/OneAgent.zip && rm /var/lib/dynatrace/oneagent/OneAgent.zip

RUN wget -O /opt/opentelemetry-javaagent.jar https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.25.0/opentelemetry-javaagent.jar

RUN  echo "tenant tenant_id" >> /var/lib/dynatrace/oneagent/agent/conf/standalone.conf && \
     echo -n "tenantToken " >> /var/lib/dynatrace/oneagent/agent/conf/standalone.conf &&  \
     cat /opt/tenant.token >>  /var/lib/dynatrace/oneagent/agent/conf/standalone.conf &&  \
     echo "serverAddress {tenant_url:443/communication}" >> /var/lib/dynatrace/oneagent/agent/conf/standalone.conf && \
     echo "" && \
     rm /opt/tenant.token

RUN echo "sed -i s/tenant_id/\$TENANT_ID/g /var/lib/dynatrace/oneagent/agent/conf/standalone.conf" >> /opt/oneAgent.sh && \
    echo "sed -i \"s|tenant_url|\$TENANT_URL|g\" /var/lib/dynatrace/oneagent/agent/conf/standalone.conf" >> /opt/oneAgent.sh && \
    chmod +x /opt/oneAgent.sh
##     echo "sed -i s/tenant_token/\$OA_TOKEN/g /var/lib/dynatrace/oneagent/agent/conf/standalone.conf" >> /opt/oneAgent.sh && \
ENV JAVA_TOOL_OPTIONS -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005

ENTRYPOINT if [ -z ${AGENT+x} ]; then \
                java -jar /opt/app/app.jar; \
           elif [ $AGENT = $ONE_AGENT ]; then \
                /opt/oneAgent.sh; \
                java -jar -agentpath:/var/lib/dynatrace/oneagent/agent/lib64/liboneagentloader.so -Xshare:off /opt/app/app.jar -nofork; \
           elif [ $AGENT = $OTEL_AGENT ]; then \
                . /opt/otel.sh; \
                java -javaagent:/opt/opentelemetry-javaagent.jar -jar /opt/app/app.jar; \
           else \
                java -jar /opt/app/app.jar; \
           fi

EXPOSE 8080
EXPOSE 5005
