FROM node:18-slim

WORKDIR /app

# 安装系统工具
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash wget curl procps && \
    rm -rf /var/lib/apt/lists/*

# 使用国内 npm 源（可选）
RUN npm config set registry https://registry.npmmirror.com

# 复制依赖文件
COPY package*.json ./

# 安装依赖
RUN npm install --production && \
    npm install -g pm2

# 复制项目文件
COPY app.js start.sh ./
RUN chmod +x start.sh

EXPOSE 3000
ENV PM2_HOME=/tmp

CMD ["pm2-runtime", "start", "start.sh"]
