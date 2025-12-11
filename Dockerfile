FROM node:alpine

WORKDIR /app

# 1. 换 apk 源 + 安装依赖
RUN set -eux; \
    # 有些镜像里 repositories 里是 https://dl-cdn...，用这个替换更保险
    sed -i 's#https://dl-cdn.alpinelinux.org#https://mirrors.aliyun.com#g' /etc/apk/repositories; \
    apk update; \
    apk add --no-cache \
      bash wget curl procps;

# 2. 复制依赖文件
COPY package*.json ./

# 3. 安装 node 依赖 + pm2（可加国内源）
RUN set -eux; \
    npm config set registry https://registry.npmmirror.com; \
    npm install; \
    npm install -g pm2;

# 4. 复制代码
COPY app.js start.sh ./
RUN chmod +x start.sh

EXPOSE 3000
ENV PM2_HOME=/tmp

ENTRYPOINT ["node", "app.js"]
