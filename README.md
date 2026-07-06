# スリープヨガ (SleepYoga)

寝たまま聴くだけのリラクセーションiOSアプリ。「寝たまんまヨガ」風の最小構成プロトタイプ。

リポジトリ: https://github.com/a-shinji/sleep-yoga

- ヒーリングBGM（自作合成・96秒シームレスループ）の上に、筋弛緩法（PMR）の音声ガイド（約11.6分）を重ねて再生
- 画面を消しても・アプリを閉じてもバックグラウンドで再生継続
- ロック画面／コントロールセンターから再生・一時停止可能
- 電話などの割り込みで自動一時停止、終了後に自動復帰
- ガイド終了後はBGMがゆっくりフェードアウトして自動停止

## 動作確認状況（2026-07-06時点）

| 項目 | 状態 |
|---|---|
| シミュレータビルド・起動（iPhone 17 Pro / iOS 26.5, Xcode 26.6） | ✅ 確認済み |
| 実機SDK向けビルド（署名なし） | ✅ 確認済み |
| 実機iPhoneでの動作 | 未（下記手順でインストール） |

## iPhoneで動かす手順

Xcode 26.6 と iOSプラットフォーム（26.5）はこのMacにインストール済み。

1. `SleepYoga.xcodeproj` をXcodeで開く
2. プロジェクト（SleepYoga）→ TARGETS SleepYoga → **Signing & Capabilities** タブ
   - **Team** に自分のApple IDを選択（未登録なら Xcode > Settings > Accounts で Apple ID を追加。無料でOK）
   - Bundle Identifier（`dev.sasai.SleepYoga`）が衝突する場合は適当に変える
3. iPhoneをUSBで接続し、画面上部のデバイス選択でそのiPhoneを選ぶ
   - iPhone側で「このコンピュータを信頼」→ iOS 16以降は **設定 > プライバシーとセキュリティ > デベロッパモード** をON（再起動を求められる）
4. ▶ ボタン（Cmd+R）で実行
   - 初回は iPhone の **設定 > 一般 > VPNとデバイス管理** で自分のデベロッパAppを「信頼」する

> 無料Apple IDの場合、署名は**7日で失効**します（アプリが起動しなくなる）。再度XcodeからRunすれば復活します。年99ドルのApple Developer Programに入ると1年有効になります。

## 動作確認のポイント

- 再生ボタン → BGMとガイド音声が同時に流れる
- 再生中に電源ボタンで画面OFF → 音が続く
- ロック画面に「筋弛緩リラクセーション」が表示され、一時停止/再開できる
- サイレントスイッチがONでも鳴る（`.playback` カテゴリの仕様。瞑想アプリはこれが正）

## カスタマイズ

| やりたいこと | 方法 |
|---|---|
| ガイドの文言・間を変える | `tools/guide_script.txt` を編集（`[[slnc ミリ秒]]` が無音）→ `tools/make_guide.sh` を実行 |
| 声を変える | `make_guide.sh` の `VOICE`（`say -v '?'` で一覧）。品質を上げたいなら OpenAI TTS / ElevenLabs / VOICEVOX 等で生成したファイルを `SleepYoga/Resources/guide.m4a` に差し替え |
| BGMを変える | `tools/make_bgm.py` を編集して再生成、または任意の音源を `SleepYoga/Resources/bgm.m4a` に差し替え（ループ素材推奨） |
| BGM音量 | `AudioManager.swift` の `bgmVolume`（現在0.35） |

## 実装メモ

- **バックグラウンド再生**: Info.plist の `UIBackgroundModes: [audio]` + `AVAudioSession` カテゴリ `.playback` の2点で成立
- **BGM+声のミックス**: `AVAudioPlayer` 2個の同時再生（`play(atTime:)` で同期スタート）。ガイド側は無音を焼き込んだ1本モノなのでタイマー不要でバックグラウンドでも確実
- **ループ**: BGMは `numberOfLoops = -1`。AAC in m4a は priming 情報が保持されるため `AVAudioPlayer` でギャップレスループ可（Apple QA1636）
- **ロック画面**: `MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`
- プロジェクトファイルは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で生成（`project.yml` が正。`xcodegen generate` で再生成。xcodegenはbrew導入済み）

## トラブルシューティング

- **ビルドが `No available simulator runtimes` で失敗する / `simctl list runtimes` が空**
  iOSランタイムのダウンロード破損の可能性。`xcrun simctl runtime verify <UUID>` で署名検証し、失敗するなら
  `xcrun simctl runtime delete all` → `xcodebuild -downloadPlatform iOS` でクリーンに入れ直す（2026-07-06に実績あり）
- **`say` で長い音声の書き出しが失敗する** → `make_guide.sh` は2分割生成+WAV連結で対策済み
- **`afconvert` が `'!dat'` エラー** → 22.05kHzモノラルにビットレート指定(`-b`)は不可。`-q 127` を使う（対策済み）

## 素材の権利

- BGM: `tools/make_bgm.py` によるプログラム合成（自作、権利問題なし）
- ガイド音声: macOS標準TTS（Kyoko）で生成。**個人利用は問題ないが、App Store配布などの商用利用はAppleのTTS利用条件に抵触しうる**ので、公開するなら商用可のTTS（OpenAI TTS等）か肉声で録り直すこと
- 「寝たまんまヨガ」は登録商標。公開時は名称に注意（本アプリは「スリープヨガ」）
