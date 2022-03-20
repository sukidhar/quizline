#!/bin/ash



while ! nc -z neo4j 7687 ; do sleep 1 ; done

echo 'export SENDGRID_API_KEY=${SENDGRID_KEY}' >> /root/.ashrc

#clean up mac build cache and deps cache
rm -rf deps
mix setup
mix assets.deploy

echo $SENDGRID_API_KEY

exec mix phx.server