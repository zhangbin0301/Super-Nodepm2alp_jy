FROM node:alpine

WORKDIR /app

# 1. 换 apk 源 + 装系统依赖
RUN set -eux; \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    apk update; \
    apk add --no-cache \
      bash wget curl procps;

# 2. 只复制 package*，利用缓存
COPY package*.json ./

# 3. npm 用国内源 + 安装依赖 + 全局 pm2
RUN set -eux; \
    npm config set registry https://registry.npmmirror.com; \
    npm install; \
    npm install -g pm2;

# 4. 复制代码和启动脚本
COPY app.js start.sh ./
RUN chmod +x start.sh

EXPOSE 3000
ENV PM2_HOME=/tmp

# 目前你是直接用 node 启动
ENTRYPOINT [ "node", "app.js" ]
# 如果之后想用 pm2 管理进程，也可以改成：
# ENTRYPOINT [ "pm2-runtime", "start", "start.sh" ]
