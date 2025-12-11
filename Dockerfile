FROM node:18-alpine

WORKDIR /app

# 1. 换 apk 源 + 安装系统依赖（如确实需要 bash / wget / curl / ps）
RUN set -eux; \
    # 把官方源换成阿里云镜像，减少网络问题
    sed -i 's#https://dl-cdn.alpinelinux.org#https://mirrors.aliyun.com#g' /etc/apk/repositories; \
    apk update; \
    apk add --no-cache \
      bash wget curl procps;

# 2. 先拷贝依赖文件，利用缓存
COPY package*.json ./

# 3. npm 使用国内源 + 安装依赖 + 全局 pm2
RUN set -eux; \
    npm config set registry https://registry.npmmirror.com; \
    npm install --production; \
    npm install -g pm2;

# 4. 再拷贝项目代码
COPY app.js start.sh ./
# 如果还有别的源码文件，可以写：
# COPY . .

RUN chmod +x start.sh

EXPOSE 3000
ENV PM2_HOME=/tmp

# 用 pm2 来跑（你之前全局装了 pm2，其实没用到）
# 如果 start.sh 里就是启动 app.js，可以这样：
CMD ["pm2-runtime", "start", "start.sh"]

# 如果你想直接用 pm2 启动 app.js，也可以：
# CMD ["pm2-runtime", "start", "app.js"]
