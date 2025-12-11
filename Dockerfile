FROM node:alpine

WORKDIR /app

ARG PORT=3000
ENV PORT=$PORT
EXPOSE $PORT

COPY package.json ./
RUN apk update && \
    apk add --no-cache bash wget curl procps && \
    npm install && \
    npm install -g pm2

COPY app.js start.sh ./
RUN chmod +x start.sh

ENV PM2_HOME=/tmp

ENTRYPOINT [ "node", "app.js" ]
