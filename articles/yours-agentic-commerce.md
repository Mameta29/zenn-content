---
title: "AIに買い物を任せるのは怖い。使える権限を自分で決める「yours」を作った"
emoji: "🛒"
type: "tech"
topics: ["googlecloud", "gemini", "ucp", "blockchain", "aiagent"]
published: false
---

## はじめに

AIに「条件に合う商品を探して、そのまま買っておいて」と頼めたら便利ですよね。商品を探し、比べ、注文するところまで任せる **エージェンティックコマース（Agentic Commerce）** の実装が、GoogleやStripeなどから相次いで公開されています。[GoogleのUCP発表](https://developers.googleblog.com/under-the-hood-universal-commerce-protocol-ucp/)や[StripeとOpenAIのACP発表](https://stripe.com/newsroom/news/stripe-openai-instant-checkout)は、その具体例です。

ただ、自分のお金までAIに使わせるとなると、結構怖いです。「予算を守ってね」と伝えて、本当にそれだけで大丈夫なのか。複数のAIに任せたら、合計でいくら使うのか。途中で止めたいとき、自分で止められるのか。

そこで作ったのが **yours** です。資産を本人のウォレットに置いたまま、**どのAIに、どの店舗で、いくらまで、いつまで購入を任せるか**を管理します。Google Cloud上のGeminiが購入処理を進め、本人が署名した支出条件をスマートコントラクトで強制する仕組みです。

この記事では、[第5回 Agentic AI Hackathon with Google Cloud](https://zenn.dev/hackathons/google-cloud-japan-ai-hackathon-vol5)に向けて開発したyoursを、実際にできることと、その権限をどう守っているかに分けて紹介します。AIエージェントへ決済機能を組み込みたい方や、AIに資産を任せる設計に関心がある方に、具体的な実装イメージを持ってもらえればと思います！

- [公開アプリを試す](https://yours-api-110852561536.asia-northeast1.run.app) — 商品検索はウォレット接続なしで利用できます。
- [GitHub](https://github.com/Mameta29/yours) / [試用ガイド](https://github.com/Mameta29/yours/blob/main/docs/TRY-IT.md)
- [公開テストネットで成立した購入の記録](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/docs/evidence/public-owner-purchase.json)

<!-- デモ動画が公開されたら、この位置にZennのYouTube埋め込みを追加する。 -->

:::message
この記事は2026年10月15日時点の実装に基づきます。公開環境はPolygon Amoyとtest JPYCを使っています。実際の署名・オンチェーン送金を行いますが、実通貨による購入ではありません。
:::

仕組みを先に知りたい方は[5章の権限制御](#5.-aiへの権限を、どこで守っているのか)へ、検証結果を見たい方は[9章](#9.-「買える」と「勝手に買えない」を、どう確認したか)へ進んでください。

## 1. yoursでできること

yoursは、AIへの依頼と、自分が許可した範囲を同じ画面で確認できる購入ワークスペースです。最初の購入エージェントとして、Geminiを接続しています。

![yoursの公開画面。Geminiによる商品検索と、予算・権限を確認する領域](/images/yours-agentic-commerce/workspace.png)
*公開環境でGeminiが実カタログを検索した画面。未接続時は検索のみ利用できます。在庫表示は撮影時点のものです。*

利用者が行う操作は、大きく次の流れです。

1. 自分のウォレットを接続し、購入を任せるAIを追加する。
2. 店舗、1回の上限、24時間ごとの予算、有効期限を指定し、ウォレットで承認する。
3. Geminiに商品を探してもらい、購入する商品・数量・金額を確認して署名する。
4. AIが会計と支払いを進める。条件を超える場合は、本人の追加確認へ戻る。
5. 支払履歴から取引を確認する。yours Marketのデジタル商品は、確定後にダウンロードできる。

現在は、**注文ごとに商品と金額への本人同意を取り、その後の購入処理をAIへ任せる**構成です。初回に予算だけ渡して、任意の商品を無期限に買い続ける実装にはしていません。

### 公開環境で、購入から受け取りまで成立しました

2026年10月15日、yours Marketの「週次ふりかえりテンプレート」を **300 test JPYC** で購入しました。

Cloud Run上のGeminiによる実行から、会計、同意証明、支払い、商品ダウンロードまでを確認しています。送金は本人のウォレットから店舗へ直接行われ、AI用ウォレットへの事前入金はありません。

取引の成功、注文との対応、300 test JPYCの移動は、独立した2つのRPCで照合しました。RPCは、ブロックチェーンの状態を読み取るための接続先です。[取引を見る](https://amoy.polygonscan.com/tx/0x158888ac528cd1e78ccba9696e44fa54665ab9a1ac3efefeb99a7b66071f7ce9) / [検証記録](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/docs/evidence/public-owner-purchase.json)

また、独立した既存ECの2店舗にも接続し、お米の商品・価格・在庫を公開APIから取得しています。こちらは公開環境での検索を確認済みで、外部ECへの購入完了は検証を進めている段階です。

## 2. エージェンティックコマースは、どこまで来ているのか

AIが商品をおすすめするだけでなく、購入を成立させるための共通仕様や決済基盤が整いつつあります。関連する動きを、発表時点を添えて並べてみます。

| 発表日 | 動き | 注目している点 |
| --- | --- | --- |
| 2025年9月16日 | Googleが**AP2（Agent Payments Protocol）**を発表 | AIが行う支払いについて、本人の意図・権限・取引の証拠を扱う共通基盤。[公式発表](https://cloud.google.com/blog/products/ai-machine-learning/announcing-agents-to-payments-ap2-protocol?hl=en) |
| 2025年9月29日 | StripeとOpenAIが**ACP（Agentic Commerce Protocol）**とInstant Checkoutを発表 | 会話内で商品を見つけ、購入へ進む商取引の接続仕様。[公式発表](https://stripe.com/newsroom/news/stripe-openai-instant-checkout) |
| 2026年1月11日 | Googleなどが**UCP（Universal Commerce Protocol）**を発表 | 商品の発見、会計、購入後まで、AI・店舗・決済事業者がやり取りするための共通仕様。[技術解説](https://developers.googleblog.com/under-the-hood-universal-commerce-protocol-ucp/) |
| 2026年8月18日 | AWSがAgentCore paymentsの一般提供を発表 | Coinbase・Stripe Privyのウォレットと連携し、エージェントの支払い・支出制御・観測を基盤として提供。[公式発表](https://aws.amazon.com/blogs/machine-learning/amazon-bedrock-agentcore-payments-is-now-generally-available-enabling-agents-to-transact-safely-and-autonomously-at-scale/) |
| 2026年9月16日 | GoogleがUCPの加盟店向け接続機能を拡張 | Merchant Centerからの導入、カート引き継ぎ、会計フローのテストなど、店舗が運用するための整備が進む。[公式発表](https://blog.google/products-and-platforms/products/shopping/google-shopping-updates-holiday-shopping/) |

この流れを見ると、**AIが買える商品を増やすことと、AIへ任せるための信頼を作ることが、並行して進んでいる**と感じます。発表が増えたことを、そのまま全利用者への普及と捉えるつもりはありません。ただ、店舗や開発者が接続できる基盤が実装されてきた点は、大きな変化だと思います。

その中で私が取り組みたいのは、購入者側のコントロールです。使うAIや購入先が増えても、「自分が何を許可し、合計でいくら使われ、どこで止められるか」を把握できるようにしたいと考えています。

## 3. ステーブルコインとAIは、なぜ相性がいいのか

ここでステーブルコインが登場します。法定通貨に連動する価値の維持を目指したトークンを使うと、日常の価格感覚と、プログラムによる送金処理をつなぎやすくなります。

例えばCircleは、USDCについて米ドルとの1対1の償還、24時間の送金、プログラム可能な決済を説明しています。こうした性質は、必要なタイミングでAPIや商品へ支払うAIと相性がよいと考えています。[CircleのUSDC解説](https://www.circle.com/usdc)

私が特に注目しているのは、次の3点です。

- **価格と予算を結び付けやすい**: 商品価格と同じ通貨に連動する資産なら、「1回2,000円まで」という条件を扱いやすくなります。
- **ソフトウェアから支払いを進められる**: HTTP上の支払要求と署名を組み合わせ、エージェントの処理の途中に決済を組み込めます。
- **条件の検証と送金をつなげられる**: スマートコントラクトに支出条件を実装し、その検証を通った取引だけを成立させられます。

**x402**は、この2つ目を実現するための仕様です。HTTPの`402 Payment Required`を使って支払条件を示し、支払情報を付けた再要求へつなげます。GoogleもAP2の発表で、CoinbaseやMetaMaskなどと連携したx402拡張とステーブルコインへの対応を紹介しています。[GoogleのAP2・x402に関する説明](https://cloud.google.com/blog/products/ai-machine-learning/announcing-agents-to-payments-ap2-protocol?hl=en)

ただし、**ステーブルコインを使えば自動的に支出が制限されるわけではありません**。予算や送金先の制御は別途実装する必要があります。また、送金手数料や確定待ち、発行者への依存は残ります。市場価格が常に基準通貨と一致する保証もなく、Circle自身も価格変動や送金の不可逆性を説明しています。[USDCのリスク説明](https://www.circle.com/es/legal/usdc-risk-factors)

yoursでは、この「プログラムから動かせるお金」に、**本人が与えた権限を強制する仕組み**を組み合わせました。

## 4. AIに「やらないで」と伝えるだけでは怖い

AIの能力が上がるほど、任せられる作業は増えます。一方で、実際の失敗事例を見ると、実行できる範囲をどう設計するかは避けて通れないと感じます。

### 売店を任せたAIが、損をする売り方をしてしまった

Anthropicの**Project Vend**では、AIに小さな売店の運営を任せています。初期の実験では、従業員に誘導されて商品を大きな損失が出る価格で販売するなどの問題がありました。2025年12月の続報では、モデルと道具の改善により業績が向上した一方、対話による誘導への弱さが残ったと報告されています。[Project Vend: Phase two](https://www.anthropic.com/research/project-vend-2)

> But the gap between “capable” and “completely robust” remains wide.

「できること」と「十分に堅牢であること」には、まだ隔たりがあるという指摘です。[引用元: Anthropic](https://www.anthropic.com/research/project-vend-2)

これは意図的な誘導も含む実験であり、一般の購入AIの事故率を示すものではありません。それでも、会話の流れが金銭的な判断に影響する例として考えさせられます。

### 変更しないよう頼んだAIが、本番DBを削除した

もう一つは、2025年7月に起きたReplitの事例です。SaaStrのJason Lemkin氏は、コード変更を止めるよう指示していたにもかかわらず、AIエージェントが本番データベースを削除したと報告しています。同氏の振り返りでは、開発時のAIが本番DBへアクセスできた構成を問題として挙げ、その後の開発・本番DBの分離などの改善も紹介しています。[当事者による報告](https://www.saastr.com/replits-new-release-address-most-of-the-challenges-we-hit-vibe-coding-but-is-prosumer-vibe-coding-really-ready-for-commercial-apps-yet/)

これは決済の事故ではありません。ただ、自然言語の指示と、システム上の実行権限の違いが表れた例だと思います。

購入エージェントなら、同じ問いはもっと具体的です。商品説明に不正な指示が含まれていたら、AIが別の送金先を指定したら、通信エラーのあとにもう一度払おうとしたら、どこで止まるのか。

**AIの判断が誤っても、本人が許可していない支払いは成立させない。** yoursでは、その境界をAPI・署名・スマートコントラクトの各層に置いています。

## 5. AIへの権限を、どこで守っているのか

yoursでは、AIが行う判断と、支払いを許可する判定を分けています。ここからは、何をどの層で検証しているかを見ていきます。

### 5-1. AIへ渡す道具と鍵を限定する

Geminiの実行には、Googleのエージェント開発フレームワーク **ADK（Agent Development Kit）** とVertex AIを使っています。利用する主な道具は、商品検索、本人が同意したタスクの取得、そのタスクの購入処理です。

検索では、依頼に合わせて実カタログを取得します。結果に続きがあれば次のページを取得でき、会話だけで価格や在庫を作らないようにしています。購入時は、本人の署名から作られたタスクを取得して進めます。

ここで、Geminiを動かすサービスには **Cloud KMSの署名権限と、DBの認証情報を与えていません**。予算の変更や任意の送金先への送金を行う道具も公開していません。接続用の認証情報があっても、注文や利用できるAPIを限定しています。[エージェント実装](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/services/agent/yours_agent/service.py) / [IAM設計](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/infra/IAM.md)

自然言語の依頼を理解して道具を選ぶ部分にはAIを使い、金額・署名・期限の一致確認には通常のコードを使います。支払いの可否は、モデルの回答内容に依存させません。

### 5-2. 本人の資産を置いたまま、限定した権限を委任する

本人の秘密鍵は取得・保存しません。資産は本人のウォレットに残り、支払い時に店舗へ移動します。

実行には、通常のEthereumアカウントへスマートアカウントの機能を持たせる **EIP-7702** と、委任された権限を実行するための **ERC-7710** を利用しています。本人がウォレット上で許可した委任を、yoursのGateコントラクトを通して使う構成です。[ウォレット設定の設計](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/docs/design/WALLET-ONBOARDING.md)

この経路で守る対象は、本人が設定した店舗・送金先・資産・金額・期限です。ウォレットに別のアプリへの権限がある場合、その経路までyoursが制御するわけではありません。

### 5-3. AI別の上限と、全AIの共有予算を同時に検証する

AIを複数使うと、個別の上限だけでは足りなくなります。

例えば、AI AにもAI Bにも1,000円ずつ許可していて、本人の残りの共有予算が1,200円だったとします。両方が800円を使おうとすると、個別上限は守っていても、合計は1,600円になります。

yoursでは、`YoursPurchaseGate`が全体の支出条件を、`AgentPermissionRegistry`がAIごとの支出条件を検証します。**共有予算とAI別予算を、同じオンチェーン取引の中で消費する**ため、両方が古い残予算を見てそのまま支払うことを防ぎます。

前述の例では、1件目が800円を使うと残りは400円です。2件目は追加承認なしには成立しません。送金が失敗した場合は、その取引で行った予算の更新も巻き戻ります。

さらに、AIの実行鍵を交換したり、権限を更新したりしても、同じ期間の使用済み予算を保持します。別のAIを追加したときも、本人全体の共有消費は引き継ぎます。[AI別予算の実装](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/packages/contracts/src/AgentPermissionRegistry.sol#L44-L77) / [共有予算を含む決済処理](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/packages/contracts/src/PurchaseGateV1.sol#L26-L69)

### 5-4. 例外を認めるときも、その注文だけにする

上限を超えた注文でも、内容を確認して「今回は買ってよい」と思うことはあります。そのため、金額や許可店舗の条件を超えた場合は、本人へ追加確認を戻せるようにしています。

この追加承認は、**新しい本人の署名と、その注文だけに対応する同意**を検証して発行します。注文、金額、送金先などを変えた承認の流用や、使用済み承認の再利用を拒否します。例外として使った金額も共有予算の消費へ加算します。

一方、失効した権限や古い実行鍵、不正な署名は、追加承認で復活させません。条件を超えた買い物を本人が認めることと、失効した権限を再利用することは、処理として分けています。[権限モデル](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/docs/design/ONCHAIN-PERMISSIONS.md)

利用者はAIの接続を停止することもできます。サービス上で新しい支払いの受け付けを止める操作と、オンチェーンの権限失効を用意しています。ただし、すでに送信された取引が止まる保証や、確定済み送金の取り消しを意味するものではありません。処理中の取引は追跡を続けます。

## 6. UCP・AP2・x402を、一つの注文としてつなぐ

規格名が増えてきたので、いったん整理します。それぞれが答える問いは違います。

| 層 | 答える問い | yoursで扱う内容 |
| --- | --- | --- |
| **UCP** | 何を、どの条件で買うのか | 商品検索、カート、会計、注文、購入後の情報 |
| **AP2** | 本人は何に同意したのか | 署名付きの委任情報、商品・数量・金額などの制約、支払いの証跡 |
| **x402** | HTTP上で支払いをどう要求・受理するか | 支払要求、支払情報を付けた再要求、決済結果 |
| **GateとRegistry** | その資産を、この条件で動かしてよいか | 本人の権限、AI別上限、共有予算、店舗、期限、一件承認 |

yoursでは、本人の同意から作られた **mandate（委任を示す署名付きデータ）** を、特定の会計と支払いに結び付けています。AP2の検証サービスが、署名、期限、金額、店舗、商品数量、一回限りの使用条件などを検証します。

その後、x402で示した支払条件と、送金する取引を照合します。送金後は、注文と実際の取引ハッシュを結び付けます。本人が許可した内容、店舗の会計、資産の移動を、一つの注文として辿れるようにするためです。

UCPは`2026-08-25`、AP2はv0.2の公式SDKを固定して検証しています。組み合わせる中では、UCP側のスキーマとAP2 SDKが生成する委任トークンの表現に不一致がありました。そこで、UCP本体の構造検証と、AP2 SDKによる署名・制約の検証を分けています。[相互運用の記録](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/docs/design/INTEROPERABILITY.md)

このため、全仕様への完全準拠とは表現していません。また、ステーブルコインの支払いにはyours独自のhandlerを使います。一般向けGeminiアプリの標準決済機能や、すべてのx402決済代行サービスに接続済みという意味ではありません。[対応する支払い仕様](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/docs/design/PAYMENT-HANDLER.md)

## 7. 通信が切れたときに、もう一度払わない

購入処理で地味に厄介なのが、「支払いは送信されたのに、成功の応答だけが届かなかった」という状態です。

ここでAIが「失敗したようなので、もう一度支払います」と判断すると、二重払いにつながります。そこでyoursでは、**署名済みの取引データと取引ハッシュをDBへ永続保存してから、チェーンへ送信**します。

```text
取引内容を確定する
  → 署名する
  → 署名済みデータと取引ハッシュをDBへ保存する
  → チェーンへ送信する
  → 同じ取引ハッシュで確定を確認する
```

応答が消えた場合も、保存した同じ取引を再照会します。再送が必要なら同じ署名済みデータを使います。復旧処理が、新しい支払いを作り直すことはありません。[送信前の永続化](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/packages/storage/src/journal.ts) / [同一取引での復旧処理](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/services/worker/src/settlement.ts#L75-L130)

外部ECへの通知が失敗した場合も、同じ予約と取引ハッシュを使って注文を照合します。画面上でも「送金の確定」と「ECでの注文受付」を別々に扱い、注文受付を商品の受け取り完了とは表示しません。

購入状況の表示も、Geminiの「支払いました」という文章だけでは変わりません。DB上の確定状態と実際の取引ハッシュを根拠に、支払いの完了を表示します。

## 8. Google Cloudの構成と、役割を分けた理由

Google Cloudは、AIの実行に加え、署名権限の分離、状態の永続化、処理中断からの復旧にも使っています。

![yoursの構成。Google Cloud上のAPI・Gemini・AP2・決済workerと、既存EC・Polygon Amoyの接続](/images/yours-agentic-commerce/architecture.png)

| サービス | 役割と選定理由 |
| --- | --- |
| **Cloud Run** | API／画面、Gemini、AP2検証、決済workerを別サービスに分離。内部サービスはIAM認証を要求し、呼び出せる相手を限定 |
| **Vertex AI + ADK** | 自然言語の依頼を受け、実カタログと承認済みタスクを道具として使う購入エージェントを実行 |
| **Cloud SQL / PostgreSQL** | 本人同意、予算予約、注文、署名済み取引、監査履歴を永続化。処理が重なっても一貫した状態を保つ |
| **Cloud KMS / HSM** | サービス側の署名鍵を、鍵そのものを取り出せない形で管理。署名できるサービスと用途を限定 |
| **Cloud Scheduler** | 非公開workerを定期的に呼び出し、処理中の取引や未完了の通知を再照合 |

Cloud KMSで保持するのはサービス側の鍵です。本人のウォレットの秘密鍵をCloud KMSへ預ける構成ではありません。また、鍵を取り出せなくても署名権限の悪用は別の問題なので、worker側の検証とオンチェーンの制約も必要です。

推論と署名を分けることで、モデルを変更したときも、支出制約を毎回プロンプトへ書き直して担保する必要がありません。ADK側で扱う道具を限定し、APIとコントラクトが同じ注文を検証します。

費用面では、リクエストごとのツール呼び出し回数・モデル呼び出し回数・実行時間に上限を設けています。一方、Cloud SQLやHSMを含む構成なので、小規模利用時の固定費もあります。購入1件あたりの総費用や、多人数で使った場合の性能は今後の計測項目です。

## 9. 「買える」と「勝手に買えない」を、どう確認したか

成功した購入だけでは、資産を任せられるかは判断しにくいと思います。そのため、拒否されるべき処理と、途中で止まった場合の復旧も検証しました。

| 確認したこと | 検証した環境と範囲 |
| --- | --- |
| 本人から店舗への300 test JPYC送金と商品ダウンロード | 公開Google Cloud・実MetaMask・Polygon Amoy。yours Marketでの購入 |
| 実店舗の商品・価格・在庫の検索 | 公開Google CloudのGeminiと、既存ECの2店舗。外部ECへの公開購入成功とは区別 |
| 支払額の改変、別の本人による追加承認、承認の再利用を拒否 | ローカルの実HTTP・PostgreSQL・AP2・テストチェーンを通す**68項目の結合検証**に含む |
| 複数AIの共有予算、外部AI自身の署名、送信応答消失からの同一取引復旧 | 同じ68項目に含む。外部ECのHTTP境界には試験用の応答を使用 |
| 鍵交換・再有効化・送金失敗時にも予算の扱いが崩れない | Solidityの**36テスト**。ランダムな入力を使うfuzz testを含む |
| ウォレット承認の中断、通信失敗、再接続からの復旧 | 実Chromeと試験用ウォレット接続機構による**22項目**。実MetaMaskの公開登録確認は別途実施 |

[公開購入の証拠](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/docs/evidence/public-owner-purchase.json) / [結合検証の項目](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/docs/evidence/payment-pipeline.json) / [検証記録の一覧](https://github.com/Mameta29/yours/blob/16b69535f420fce8ee34b5b14c7c8199d7c0bece/docs/evidence/README.md)

これらは個別の制約と復旧処理の検証です。あらゆるプロンプトインジェクションへの耐性や、商用運用の安全性を証明したものではありません。本人が署名した範囲内でも、商品の品質や購入判断の妥当性は別に考える必要があります。

## 10. 既存の決済基盤がある中で、yoursで作りたいもの

支出上限や認証の仕組み自体は、既存サービスにもあります。例えばAWSのAgentCore paymentsも、支出制御や決済の観測を提供しています。[AWSの説明](https://aws.amazon.com/blogs/machine-learning/amazon-bedrock-agentcore-payments-is-now-generally-available-enabling-agents-to-transact-safely-and-autonomously-at-scale/)

yoursで形にしたいのは、**本人のウォレットにある資産について、複数AIへの権限と共有予算を管理し、同意・注文・支払い・受け取りまでを一つにつなぐ体験**です。

AIサービスを使う本人には、共通の権限管理画面を提供します。AIを開発する側には、API／SDKから購入へ接続する経路を用意します。店舗にはUCPの接続口を用意し、既存ECのように別のAPIを持つ場合はadapterで接続します。

外部AI向けには、自身の署名鍵を登録して購入を進めるclient例も実装しています。ローカルでは、Gemini用の署名処理に依存せず、外部AI自身の署名で送金まで進むことを確認しました。[外部AI client](https://github.com/Mameta29/yours/tree/16b69535f420fce8ee34b5b14c7c8199d7c0bece/examples/external-agent)

将来的には、複数の業務エージェントへ備品購入などを任せる企業や、購入機能を組み込むAIサービスにも広げたいと考えています。現時点で全AIサービス・全店舗へ接続できるわけではなく、接続先を明示的に登録して検証する構成です。

### 次に改善したいこと

初回のウォレット設定と権限登録には、複数の承認操作が必要です。ここは、何を許可するかの確認を残したまま、操作数と分かりにくさを減らしたい部分です。

外部ECと外部AI client単体での公開購入確認、返金処理、配送先や商品オプションを伴う注文も残っています。また、現状は本人が個々の商品を選んで同意するため、日用品の補充など継続的な依頼を扱うには、許可する商品の範囲と再同意の条件をさらに設計する必要があります。

## まとめ

yoursでは、本人が決めた購入権限を、署名・API・スマートコントラクトで検証し、Geminiによる会計からtest JPYCの送金、商品の受け取りまでをつなぎました。複数AIの共有予算や、一件だけの例外承認、通信が途切れた場合の復旧も、その権限を維持するための仕組みです。

AIに任せる作業が増えるほど、**自分が何を許可しているか分かり、必要なら止められ、起きたことを後から確かめられること**が大事になると思います。その状態を作ることが、AIに安心して任せる範囲を広げることにもつながるのではないでしょうか。

まずは[公開アプリ](https://yours-api-110852561536.asia-northeast1.run.app)で、Geminiにカタログの商品を尋ねてみてください。実装の詳細は[GitHub](https://github.com/Mameta29/yours)から確認できます！
