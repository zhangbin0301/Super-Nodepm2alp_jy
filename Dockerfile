FROM node:alpine

WORKDIR /app

# 先装系统依赖
RUN set -eux; \
    apk update; \
    apk add --no-cache \
      bash wget curl procps \
      # 如果你的依赖里有需要编译的原生模块，解开下面三行注释：
      # python3 \
      # make \
      # g++ \
    ;

# 只拷贝 package*，利用缓存
COPY package*.json ./

# 使用国内源 + 安装依赖 + 全局 pm2
RUN set -eux; \
    npm config set registry https://registry.npmmirror.com; \
    npm install; \
    npm install -g pm2;

# 拷贝业务代码
COPY app.js start.sh ./
RUN chmod +x start.sh

EXPOSE 3000
ENV PM2_HOME=/tmp

# 你现在 ENTRYPOINT 用的是 node，实际上 pm2 没用上
# 如果你是想用 pm2 管理进程，可以改成：
# ENTRYPOINT ["pm2-runtime", "start", "start.sh"]
# 或者：
# ENTRYPOINT ["pm2-runtime", "start", "app.js"]

# 如果暂时就想先跑起来，保留 node 也可以：
ENTRYPOINT [ "node", "app.js" ]
