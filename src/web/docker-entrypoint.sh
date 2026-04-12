#!/bin/sh
# Substitute only ${API_URL} in the nginx template, leaving nginx variables
# like $host, $uri, $remote_addr untouched (single-quotes pass literal string to envsubst).
envsubst '${API_URL}' < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf
exec nginx -g 'daemon off;'
