# delphinus/homebrew-kitty

[kitty](https://github.com/kovidgoyal/kitty) を**本家に入っていない修正を当てた状態**でソースからビルドする Homebrew tap。

```sh
brew tap delphinus/kitty
brew install delphinus/kitty/kitty
ln -sfn "$(brew --prefix)/opt/kitty/kitty.app" ~/Applications/kitty.app
```

公式の cask (`brew install --cask kitty`) とは `kitty` コマンドが衝突するので、先に `brew uninstall --cask kitty` しておくこと。

## 何を直しているか

**素の kitty は、SF Mono Square のような non-mono 系の Nerd Font でアイコンを描くと、インクの細いものだけを 0.67〜0.9 倍に縮小し、さらに左へ寄せてしまう。** この tap はそれを直す 2 つのパッチを当てる。

kitty は 1 つのグリフに何セル割り当てるかを**インクの外接矩形だけ**で決める。non-mono 系の Nerd Font は全グリフに 2 セルぶんの advance を与えてアートワークをその中央に置くので、インクが 1 セルに収まるグリフは 1 セル扱いになり、2 セルの中央にあるインクが 1 セルからはみ出すぶんフォントサイズを縮められる。`advance` は一切読まれない。

| パッチ | 内容 |
|---|---|
| [`b787020`](https://github.com/delphinus/kitty/commit/b787020b92e2f4ef7a7cf1147ebfd963de73637d) | セル数をインクだけでなく **advance も見て**決める (`core_text.m` / `freetype.c`) |
| [`1564808`](https://github.com/delphinus/kitty/commit/156480852c698d3bfe5950ec7cb3a632db877378) | インクがセルに収まる単一グリフは、**縮小せずに位置をずらす** (`core_text.m`) |

Powerline セパレータや進捗バーのような 1 セル advance のグリフは advance が 1 セルなので影響を受けない。パッチの由来と実測値は [delphinus/kitty](https://github.com/delphinus/kitty) の `fix/nerd-font-symbol-cell-sizing` ブランチを参照。

**これは upstream の方針と衝突する類の変更ではなく、描画の正しさの修正**として上流に出すつもりのもの。マージされたらこの tap は畳む。

## 仕組み

- 本家の release tarball (`kitty-X.Y.Z.tar.xz`) を取ってきて `patch` で 2 つのコミットを当てる。fork を rebase して追従する運用にはしていないので、**バージョン上げは formula の `url` と `sha256` の 2 行だけ**で済む。
- 0.49 からシェーダのコンパイルに Slang コンパイラ (`slangc`) が要る。Homebrew に `shader-slang` の formula が無いので、上流の CI と同じく公式のビルド済みバイナリを `resource` で取って `libexec` に置き、`$SLANGC` で参照させる。カスタムシェーダは kitty の起動時にコンパイルされるので `bin/slangc` の symlink も張る (GLSL 出力に使わない 102MB の `libslang-llvm.dylib` は除いてある)。
- 上流に新しいリリースが出ると [`upstream.yml`](.github/workflows/upstream.yml) が日次で検知して PR を作る。パッチが当たらなくなった場合はその PR の CI が落ちるので、そこで気付ける。
- main に入ると [`bottle.yml`](.github/workflows/bottle.yml) が `arm64_tahoe` の bottle を焼いて release に上げ、formula に sha256 を書き戻す。2 台目以降はビルド待ちが無くなる。

## 制限

- **macOS / Apple Silicon のみ。** 同梱する Slang コンパイラが aarch64 版なので、formula 自体が `depends_on arch: :arm64` で Intel を弾く。bottle も `arm64_tahoe` だけ。
- `kitty.app` は Cellar の中に入る。Homebrew には formula から `.app` を配置する仕組みが無い (`brew linkapps` は削除済み) ので、`~/Applications` への symlink は自分で張る。`opt` パスはバージョンに依らないので一度張れば良い。
