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
