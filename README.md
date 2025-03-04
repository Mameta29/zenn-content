# Zenn CLI

* [📘 How to use](https://zenn.dev/zenn/articles/zenn-cli-guide)

## プロジェクト立ち上げ
Docker コンテナの起動
```sh
docker compose up -d --build
```

コンテナに接続
```sh
docker compose exec zenn sh
```

作業が終了したらコンテナをダウンする
```sh
docker compose down
```