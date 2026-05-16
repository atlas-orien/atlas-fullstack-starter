FROM nginx:stable-alpine-slim

ARG APP_NAME=web

COPY deploy/frontend/default.conf.template /etc/nginx/templates/default.conf.template
COPY frontend/apps/${APP_NAME}/dist /usr/share/nginx/html

EXPOSE 80
