---
name: url-digest
description: URL要約スキル。1つ以上のURLを受け取り、コアメッセージがわかるように要約して `_inbox/digest/YYYYMMDD-digest.md` に保存する。「このURL要約して」「記事まとめて」「URL読んで」などと言われたとき、またはURLが貼り付けられたときに使用する。HN・Redditはコメントも含めて分析する。
allowed-tools: Bash, WebFetch, Write, Read
---

# URL要約

複数のURLを読み取り、コアメッセージがわかるように要約して `_inbox/digest/YYYYMMDD-digest.md` に保存する。

## 実行手順

### 1. URL種別判定

| 種別 | パターン | 取得方法 |
|------|---------|---------|
| 通常記事 | それ以外 | WebFetch |
| Hacker News | `news.ycombinator.com/item?id=XXX` | Algolia API + WebFetch（元記事） |
| Reddit | `reddit.com/r/*/comments/*` | Bashでcurl（JSON） |
| X (Twitter) | `x.com/*` / `twitter.com/*` | ブラウザ自動化ツール |

### 2. コンテンツ取得

#### 通常記事
WebFetchでタイトルと本文を取得し、コアメッセージを要約。

#### Hacker News

```bash
curl -s "https://hn.algolia.com/api/v1/items/{item_id}" | jq '.'
```

- `url` フィールドが存在する場合、WebFetchで元記事も取得
- `children` から上位5件程度のコメントを確認し、インサイトを抽出

#### Reddit

**投稿情報の取得**（投稿とコメントは別クエリで取得すること）：

```bash
curl -s -H "User-Agent: url-digest/1.0" \
  "https://old.reddit.com/r/{subreddit}/comments/{post_id}.json" \
  | jq '.[0].data.children[0].data | {title, url, selftext, is_self}'
```

**コメントの取得**（別クエリで実行）：

```bash
curl -s -H "User-Agent: url-digest/1.0" \
  "https://old.reddit.com/r/{subreddit}/comments/{post_id}.json" \
  | jq '[.[1].data.children[:8][].data | select(.body) | {body: .body[0:500], score}]'
```

- `select(.body)` を使う（`select(.body != null)` は感嘆符がシェルでエスケープされるため不可）
- `url` が外部URLの場合はWebFetchで元記事も取得

### 3. 要約生成

各URLについて：
- **タイトル**: 英語の場合は日本語に翻訳
- **要約**: コアメッセージを3〜5行。HN/Redditはコミュニティの反応・インサイト・反論も含める
- **URL**: 入力されたURLをそのまま記載

### 4. 出力

**まず「要約完了。」と返してから**、`_inbox/digest/YYYYMMDD-digest.md` に保存（YYYYMMDDは実行日）。既存ファイルがある場合は末尾に追記する。

```markdown
# URL Digest: YYYY-MM-DD

---

## [記事タイトル]

要約本文。コアメッセージを3〜5行で記述。
HN/Redditの場合はコミュニティの反応やインサイトも含める。

URL

---
```

## 注意事項

- **すべての記事にURLを必ず含める**
- **英語タイトルは日本語に翻訳**
- **HN/Redditは元記事とコメントの両方を確認**
- **Redditはcurlを使用**（WebFetchはブロックされる）
- Reddit APIレート制限に注意（1分あたり60リクエスト程度）
