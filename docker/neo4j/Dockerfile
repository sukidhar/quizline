FROM neo4j:enterprise

RUN apt update \
    &&  apt install -y netcat

COPY db-init.sh db-init.sh
RUN chmod +x db-init.sh

ENTRYPOINT [ "./db-init.sh" ]