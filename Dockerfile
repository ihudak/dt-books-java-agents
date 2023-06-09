FROM eclipse-temurin:17-focal
MAINTAINER dynatrace.com

ENV ONE_AGENT="oneAgent"
ENV OTEL_AGENT="otelAgent"

# Prepare OTel config
# otel.sh will set tenant-specific settings on deploy
ARG OTEL_VER="v1.25.0"
ENV OTEL_RESOURCE_ATTRIBUTES="service.name=java-quickstart,service.version=1.0.1"
ENV OTEL_METRICS_EXPORTER=none
ENV OTEL_EXPORTER_OTLP_TRACES_PROTOCOL=http/protobuf
RUN echo "export OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=\$TENANT_URL/api/v2/otlp/v1/traces" >> /opt/otel.sh && \
    echo "export OTEL_EXPORTER_OTLP_TRACES_HEADERS=Authorization=\"Api-Token \$OTEL_TOKEN\"" >> /opt/otel.sh && \
    chmod +x /opt/otel.sh && \
    wget -O /opt/opentelemetry-javaagent.jar https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/$OTEL_VER/opentelemetry-javaagent.jar

# Prepare OA. Download Java Agent
# oneAgent.sh will set tenant-specific settings on deploy
ARG ENV_FILE=env
COPY ${ENV_FILE} /opt/env
RUN mkdir -p /opt/app && mkdir -p  /var/lib/dynatrace/oneagent && \
    apt-get update && apt-get install -y unzip && rm -rf /var/lib/apt/lists/* && \
    export DT_AGENT_DOWNLOAD_TENANT_URL=`cat /opt/env | grep DT_AGENT_DOWNLOAD_TENANT_URL | sed s/DT_AGENT_DOWNLOAD_TENANT_URL=//` && \
    export DT_AGENT_DOWNLOAD_TOKEN=`cat /opt/env | grep DT_AGENT_DOWNLOAD_TOKEN | sed s/DT_AGENT_DOWNLOAD_TOKEN=//` &&  \
    curl --request GET -sL \
    --url "$DT_AGENT_DOWNLOAD_TENANT_URL/api/v1/deployment/installer/agent/unix/paas/latest?flavor=default&arch=x86&bitness=64&include=java&skipMetadata=true" \
    --header 'accept: */*' \
    --header "Authorization: Api-Token $DT_AGENT_DOWNLOAD_TOKEN" \
    --output '/var/lib/dynatrace/oneagent/OneAgent.zip' && \
    rm /opt/env && \
    cd /var/lib/dynatrace/oneagent && unzip /var/lib/dynatrace/oneagent/OneAgent.zip && rm /var/lib/dynatrace/oneagent/OneAgent.zip && \
    export OA_CONF_FILE=/var/lib/dynatrace/oneagent/agent/conf/standalone.conf && \
    echo "tenant tenant_id"                             >> $OA_CONF_FILE && \
    echo "tenantToken tenant_token"                     >> $OA_CONF_FILE &&  \
    echo "serverAddress {tenant_url:443/communication}" >> $OA_CONF_FILE && \
    echo ""                                             >> $OA_CONF_FILE && \
    echo "curl -X GET \$TENANT_URL/api/v1/deployment/installer/agent/connectioninfo \\"     >> /opt/oneAgent.sh && \
    echo "  -H \"accept: application/json\" \\"                                             >> /opt/oneAgent.sh && \
    echo "  -H \"Authorization: Api-Token \$OA_TOKEN\" | \\"                                >> /opt/oneAgent.sh && \
    echo "grep tenantToken | \\"                                                            >> /opt/oneAgent.sh && \
    echo "sed s/\ \\ \\\"tenantToken\\\"\\ :\\ \\\"// | sed s/\\\",// > /opt/tenant.token"  >> /opt/oneAgent.sh && \
    echo "export TENANT_TOKEN=\`cat /opt/tenant.token\`"                                    >> /opt/oneAgent.sh && \
    echo "rm /opt/tenant.token"                                                             >> /opt/oneAgent.sh && \
    echo "sed -i s/tenant_id/\$TENANT_ID/g $OA_CONF_FILE"                                   >> /opt/oneAgent.sh && \
    echo "sed -i \"s|tenant_url|\$TENANT_URL|g\" $OA_CONF_FILE"                             >> /opt/oneAgent.sh && \
    echo "sed -i s/tenant_token/\$TENANT_TOKEN/g $OA_CONF_FILE"                             >> /opt/oneAgent.sh && \
    echo ""                                                                                 >> /opt/oneAgent.sh && \
    chmod +x /opt/oneAgent.sh

ENV JAVA_TOOL_OPTIONS -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005

ENTRYPOINT if [ -z ${AGENT+x} ]; then \
                java -jar /opt/app/app.jar; \
           elif [ $AGENT = $ONE_AGENT ]; then \
                [ -f /opt/oneAgent.sh ] && { /opt/oneAgent.sh; rm /opt/oneAgent.sh; } || echo "oneAgent.sh gone"; \
                java -jar -agentpath:/var/lib/dynatrace/oneagent/agent/lib64/liboneagentloader.so -Xshare:off /opt/app/app.jar -nofork; \
           elif [ $AGENT = $OTEL_AGENT ]; then \
                . /opt/otel.sh; \
                java -javaagent:/opt/opentelemetry-javaagent.jar -jar /opt/app/app.jar; \
           else \
                java -jar /opt/app/app.jar; \
           fi

EXPOSE 8080
EXPOSE 5005
