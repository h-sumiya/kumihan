# v1 Development Strategy

## Goal

- `lib/src/engine` を現在の正とする
- 振る舞いを保ったまま責務を小さく分割する
- v0 相当の出力を保ちながら、テストしやすい構造に寄せる

## Rules

- いきなり全面刷新しない
- 1 回の変更で 1 つの責務だけを切り出す
- 切り出し前後でテストを追加または更新する
- public API は必要になるまで広げない
- ファイルが肥大化する前に分割する

## Extraction Order

1. `document_compiler.dart` 周辺のデータ変換を分離する
2. `line_breaker.dart` の改行判定を独立させる
3. `table_renderer.dart` の表描画ロジックを独立させる
4. `kumihan_engine.dart` には orchestration だけを残していく

## Working Style

- まず engine 内の既存コードを移動せずに薄い helper や service を追加する
- 呼び出し側を差し替えて挙動を固定する
- 安定した単位ごとにファイルを移し、責務名を見直す

## First Slice Candidates

- 文字種判定や禁則処理の pure function 化
- レイアウト計算の入力値を value object として切り出す
- 描画コマンド生成と canvas 反映の境界整理

## Notes

- 旧試作は `v1-abandoned` ブランチと `kumihan-v1-abandoned` worktree に退避してある
- 比較アプリ `kumihan_compare` は撤去済み
