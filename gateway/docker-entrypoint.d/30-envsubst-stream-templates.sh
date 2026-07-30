#!/bin/sh
# Process /etc/nginx/templates/*.stream-template → /etc/nginx/stream-conf.d/*.conf
# Official nginx image only envsubst's *.template into conf.d; stream needs this hook.
set -e

template_dir="${NGINX_ENVSUBST_TEMPLATE_DIR:-/etc/nginx/templates}"
output_dir="${NGINX_ENVSUBST_STREAM_OUTPUT_DIR:-/etc/nginx/stream-conf.d}"
suffix=".stream-template"

mkdir -p "$output_dir"

filter="${NGINX_ENVSUBST_FILTER:-.}"
defined_envs=$(printf '${%s} ' $(awk "END { for (name in ENVIRON) { print ( name ~ /${filter}/ ) ? name : \"\" } }" < /dev/null))

find "$template_dir" -follow -type f -name "*$suffix" -print | while read -r template; do
  relative="${template#"$template_dir"/}"
  output="$output_dir/${relative%"$suffix"}.conf"
  outdir=$(dirname "$output")
  mkdir -p "$outdir"
  echo "Running envsubst on $template → $output"
  # shellcheck disable=SC2086
  envsubst "$defined_envs" < "$template" > "$output"
done
