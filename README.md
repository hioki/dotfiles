# dotfiles

## Installation

```shell
$ make
```

## disk-cleanup

`.bin/disk-cleanup.bash` は再生成可能な派生物だけを削除してディスクを空ける。
ソース、設定、鍵、`~/Keep` には触れない。`target` ディレクトリは同階層に
`Cargo.toml` があるものだけを対象とし、既定では 90 日以上ビルドされて
いないものだけを消す。

```shell
$ disk-cleanup                  # dry-run。何がどれだけ消えるか表示する
$ disk-cleanup --apply          # 実行する
$ disk-cleanup --apply --age 30 # target の保持日数を変える
```

`make` を実行すると `~/.local/bin/disk-cleanup` に symlink が張られ、macOS では
毎月 1 日 12:00 に `--apply` で走る launchd エージェントが登録される。
実行ログは `~/Library/Logs/disk-cleanup.log`。

Rust のビルド成果物は `.cargo/config.toml` の `build.target-dir` で
`~/.cache/cargo-target` に集約している。集約先は `cargo-sweep` で間引かれる
ため、あらかじめ入れておく。

```shell
$ cargo install cargo-sweep
```

## shrink-recording

`.bin/shrink-recording.bash` は画面収録の `.mov` を配布用の mp4 に変換して
軽くする。macOS の画面収録や ReplayKit の録画は 4K・高ビットレートでそのままでは
共有に重いため、H.264 の CRF エンコードで再圧縮し、moov atom を先頭に置いた
（再生開始までダウンロードを待たない）mp4 を入力と同じディレクトリに出力する。
入力ファイルは書き換えない。

```shell
$ shrink-recording demo.mov              # 4K のまま crf 23 → demo.mp4
$ shrink-recording --scale 1920 demo.mov # 横 1920 に縮小 → demo-1920w.mp4
$ shrink-recording --crf 20 demo.mov     # 品質重視
$ shrink-recording -n *.mov              # 実行せず ffmpeg コマンドだけ表示
```

画面収録は静止領域が多くて元から圧縮しやすく、`-preset` を上げても縮まないので
既定は `fast` のまま。効くつまみは `--crf` と `--scale` だけ。端末や小さい UI
文字が写る録画は crf 23 前後が安全で、28 まで上げると文字にノイズが出る。

音声トラックの有無は自動判定する。`make` を実行すると
`~/.local/bin/shrink-recording` に symlink が張られる。`ffmpeg` が必要。

```shell
$ brew install ffmpeg
```
