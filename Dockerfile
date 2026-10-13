FROM nginx:stable-alpine
ARG REVISION=local
COPY index.html /usr/share/nginx/html/index.html
RUN printf '%s\n' "$REVISION" > /usr/share/nginx/html/revision.txt
