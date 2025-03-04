FROM node:18-alpine

WORKDIR /app

# npmのグローバルインストールを避けるための設定
ENV NPM_CONFIG_PREFIX=/app/.npm-global
ENV PATH=$PATH:/app/.npm-global/bin

# 必要なパッケージのインストール
RUN npm install -g zenn-cli@latest

# コンテナ起動時に実行するコマンド
CMD ["sh", "-c", "cd /app && /bin/sh"]