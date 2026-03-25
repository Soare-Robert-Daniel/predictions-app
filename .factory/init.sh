#!/usr/bin/env sh
set -eu

cd /home/predictions-app

mix deps.get
mix assets.setup
mix ecto.create >/dev/null 2>&1 || true
mix ecto.migrate
MIX_ENV=test mix ecto.create >/dev/null 2>&1 || true
MIX_ENV=test mix ecto.migrate
