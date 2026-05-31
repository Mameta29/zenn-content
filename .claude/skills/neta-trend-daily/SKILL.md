---
name: neta-trend-daily
description: 日次トレンドネタ収集スキル。はてなブックマークIT人気エントリー、Hacker News、Reddit（13サブレッド）、セキュリティブログからトレンド情報を収集し `_inbox/daily/YYYYMMDD-trend.md` に保存する。「トレンド収集」「ネタ収集」「今日のトレンド」などと言われたとき、または `/neta-trend-daily` で直接呼び出されたときに使用する。
disable-model-invocation: true
allowed-tools: Bash, WebFetch, Write, Read
---

# トレンドネタ収集

はてなブックマークIT・Hacker News・Reddit・セキュリティブログからトレンドを収集し、`_inbox/daily/YYYYMMDD-trend.md` に保存する。

## 実行手順

### 0. ユーザープロファイル読み込み

`CLAUDE.md` を読み込み、以下の興味領域を把握する：
- AI（開発とセキュリティへの応用）
- Webセキュリティ/ハッキング（OWASP、脆弱性、サプライチェーン攻撃）
- OSS開発/コミュニティ
- 個人開発/SaaS運営（Technical SEO、グロースハック、収益化）
- キャリア/人生哲学（経済的自由、外資転職、Build in Public）
- JavaScript/TypeScript技術スタック

### 1. トレンド情報の収集

**日本市場（はてブIT）** — WebFetchで取得：
- https://b.hatena.ne.jp/hotentry/it
- https://b.hatena.ne.jp/hotentry/it/%E3%83%97%E3%83%AD%E3%82%B0%E3%83%A9%E3%83%9F%E3%83%B3%E3%82%B0
- https://b.hatena.ne.jp/hotentry/it/AI%E3%83%BB%E6%A9%9F%E6%A2%B0%E5%AD%A6%E7%BF%92
- https://b.hatena.ne.jp/hotentry/it/%E3%81%AF%E3%81%A6%E3%81%AA%E3%83%96%E3%83%AD%E3%82%B0%EF%BC%88%E3%83%86%E3%82%AF%E3%83%8E%E3%83%AD%E3%82%B8%E3%83%BC%EF%BC%89
- https://b.hatena.ne.jp/hotentry/it/%E3%82%BB%E3%82%AD%E3%83%A5%E3%83%AA%E3%83%86%E3%82%A3%E6%8A%80%E8%A1%93
- https://b.hatena.ne.jp/hotentry/it/%E3%82%A8%E3%83%B3%E3%82%B8%E3%83%8B%E3%82%A2

各エントリーの**タイトル、元記事URL（はてブページURLではなく）、ブックマーク数**を取得。

**グローバル（Hacker News）** — WebFetchで取得：
- https://news.ycombinator.com/
- タイトル（日本語訳）、HNコメントページURL（`https://news.ycombinator.com/item?id=XXXXX`）、ポイント数を取得

**セキュリティ（追加ソース）** — WebFetchで取得：
- https://www.aikido.dev/blog
- https://www.wiz.io/blog
- 最新1〜3記事をチェック。興味度★★★のものがあれば注目トピックに含める。

**Reddit（13サブレッド）** — **WebFetchはブロックされるためBashでcurlを使用**：

```bash
curl -s -H "User-Agent: neta-trend-collector/1.0 (trend analysis tool)" \
  "https://old.reddit.com/r/SUBREDDIT/hot.json?t=day&limit=10" | \
  jq -r '.data.children[] | "\(.data.title)|\(.data.ups)|\(.data.num_comments)|https://www.reddit.com\(.data.permalink)"'
```

対象サブレッド：
- セキュリティ系: r/netsec, r/cybersecurity
- AI系: r/OpenAI, r/LocalLLaMA, r/ClaudeCode
- コア技術系: r/programming, r/technology
- OSS/個人開発系: r/opensource, r/indiehackers, r/webdev, r/javascript
- キャリア/実践系: r/cscareerquestions, r/productivity

タイトルは日本語に翻訳。RedditコメントページのURL（`https://www.reddit.com/r/.../comments/...`）を使用。

### 2. 分析

**興味度の定義**：
- ★★★: 興味領域に直接関連（AI×セキュリティ、OSS、個人開発、キャリアなど）
- ★★: 間接的に関連（技術トレンド全般、エンジニアリング文化）
- ★: 一般的なIT/技術ニュース

### 3. 出力

**まず「ネタ収集完了。」と返してから**、`_inbox/daily/YYYYMMDD-trend.md` に保存（YYYYMMDDは実行日）。

```markdown
# トレンドネタ: YYYY-MM-DD

## はてブIT（日本市場）

### 注目トピック

| タイトル | ブクマ数 | 興味度 | カテゴリ | メモ |
|---------|---------|--------|---------|------|
| [タイトル](元記事URL) | XXX users | ★★★ | AI/開発/キャリア等 | 発信に活用できるポイント |

### 全エントリー

1. [タイトル](元記事URL) (XXX users) - 概要

## Hacker News（グローバル）

### 注目トピック

| タイトル | ポイント | 興味度 | カテゴリ | メモ |
|---------|---------|--------|---------|------|
| [タイトル](HNコメントページURL) | XXXpt | ★★★ | AI/Security/Dev等 | 発信に活用できるポイント |

### 全エントリー

1. [タイトル](HNコメントページURL) (XXXpt) - 概要

## Reddit（13サブレッド）

### 注目トピック

| タイトル | 投票数 | コメント数 | 興味度 | カテゴリ | サブレッド | メモ |
|---------|--------|-----------|--------|---------|-----------|------|
| [タイトル](RedditコメントページURL) | XXX ups | XXX | ★★★ | Security/AI/OSS等 | r/subreddit | メモ |

### カテゴリ別エントリー

#### セキュリティ系
1. [タイトル](URL) (XXX ups, XXX comments) - r/netsec - 概要

#### AI系
...

#### OSS/個人開発系
...

#### キャリア/実践系
...
```

## 注意事項

- **すべての記事にURLリンクを必ず含める**
- **はてブは元記事URLを取得**（はてブページURLではなく）
- **HNはコメントページURL（`item?id=`形式）を使用**
- **HN・Redditのタイトルは日本語に翻訳**
- **RedditはBashでcurlを使用**（WebFetchはブロックされる）
- Reddit APIレート制限に注意（1分あたり60リクエスト程度）
