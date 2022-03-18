#!/bin/ash



while ! nc -z neo4j 7687 ; do sleep 1 ; done


mix setup
mix assets.deploy

exec mix phx.server