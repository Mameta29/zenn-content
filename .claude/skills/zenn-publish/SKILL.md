---
name: zenn-publish
description: Zenn記事公開スキル。_inbox/drafts/ にある下書きMarkdownをZennフォーマットに整形し、articles/ へ移動してGit pushで公開する。「Zennに公開」「記事を出す」「公開して」「zenn-publish」などと言われたときに使用する。引数として下書きファイルパスまたはファイル名を受け取る。
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Glob
---

# Zenn記事公開

`_inbox/drafts/` の下書きをZennフォーマットに整形し、`articles/` へ移動してGit pushで公開する。

## 引数

```
/zenn-publish $ARGUMENTS
```

`$ARGUMENTS` は下書きファイルのパスまたはファイル名（例: `20260223-ai-security.md`）。
省略された場合は `_inbox/drafts/` の一覧を表示してユーザーに選ばせる。

## 実行手順

### 1. 下書きファイルの特定

- `$ARGUMENTS` が指定されている場合: `_inbox/drafts/$ARGUMENTS` を読み込む
- 指定がない場合: `_inbox/drafts/` のファイル一覧を表示してユーザーに確認

### 2. Zenn frontmatterの生成

下書きの内容を分析し、以下のfrontmatterを生成してユーザーに確認を取る：

```yaml
---
title: "記事タイトル"         # 下書きから生成（60文字以内推奨）
emoji: "🔐"                  # 内容に合った絵文字1つ
type: "tech"                  # tech（技術記事）or idea（アイデア）
topics: ["security", "ai"]    # 関連トピック（最大5つ、Zennに存在するもの）
published: false              # 最初はfalseで確認後にtrueに変更
---
```

**topicsの選び方**:
- Zennの既存トピックに合わせる
- 技術系: `typescript`, `javascript`, `python`, `security`, `ai`, `openai`, `aws`, `docker`, `nextjs`, `react` など
- 概念系: `oss`, `career`, `productivity`, `github` など

### 3. スラグ（ファイル名）の決定

- `articles/YYYYMMDD-{slug}.md` の形式
- slugは英数字とハイフンのみ（例: `ai-security-2026`）
- ユーザーに確認してから確定

### 4. 記事内容の整形

下書きをZenn記事として整形：
- frontmatterを先頭に追加
- 見出し構造を確認（h1は使わずh2から始める）
- コードブロックの言語指定を確認
- 外部URLはそのままリンクとして残す
- `_inbox/daily/` や `_inbox/digest/` への参照がある場合は削除またはインライン化

### 5. ファイル移動と確認

1. `articles/YYYYMMDD-{slug}.md` に保存
2. 内容をユーザーに確認してもらう
3. `published: false` のまま一時コミットするか確認

### 6. 公開

ユーザーが「公開する」と確認した後のみ実行：

```bash
# frontmatterのpublishedをtrueに変更
# git操作
cd ~/dev/blog/zenn-content
git add articles/YYYYMMDD-{slug}.md
git commit -m "feat: add article - {title}"
git push origin main
```

**重要**: `git push` はユーザーの明示的な確認後のみ実行する。

### 7. 完了報告

```
公開完了！

記事: articles/YYYYMMDD-{slug}.md
タイトル: {title}
URL: https://zenn.dev/{username}/articles/YYYYMMDD-{slug}

_inbox/drafts/{original}.md は残しておきます（削除する場合はお知らせください）。
```

## 注意事項

- **`git push` は必ずユーザー確認後に実行**
- `published: false` のドラフト公開も可能（Zennでプレビュー確認後に `published: true` へ）
- 画像ファイルは `images/` ディレクトリに配置し、`/images/filename.png` の形式でパスを指定
- Zennのtopicsは存在するものを使う（存在しないと公開エラーになる）
