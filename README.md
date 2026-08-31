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
| [`6e7a72a`](https://github.com/delphinus/kitty/commit/6e7a72a02def30ff075b38688572310830e65001) | セル数をインクだけでなく **advance も見て**決める (`core_text.m` / `freetype.c`) |
| [`2d47a99`](https://github.com/delphinus/kitty/commit/2d47a99972a98a9c178e373adee58a14f124d589) | インクがセルに収まる単一グリフは、**縮小せずに位置をずらす** (`core_text.m`) |

Powerline セパレータや進捗バーのような 1 セル advance のグリフは advance が 1 セルなので影響を受けない。パッチの由来と実測値は [delphinus/kitty](https://github.com/delphinus/kitty) の `fix/nerd-font-symbol-cell-sizing` ブランチを参照。

**これは upstream の方針と衝突する類の変更ではなく、描画の正しさの修正**として上流に出すつもりのもの。マージされたらこの tap は畳む。

## 仕組み

- 本家の release tarball (`kitty-X.Y.Z.tar.xz`) を取ってきて `patch` で 2 つのコミットを当てる。fork を rebase して追従する運用にはしていないので、**バージョン上げは formula の `url` と `sha256` の 2 行だけ**で済む。
- 上流に新しいリリースが出ると [`upstream.yml`](.github/workflows/upstream.yml) が日次で検知して PR を作る。パッチが当たらなくなった場合はその PR の CI が落ちるので、そこで気付ける。
- main に入ると [`bottle.yml`](.github/workflows/bottle.yml) が `arm64_tahoe` の bottle を焼いて release に上げ、formula に sha256 を書き戻す。2 台目以降はビルド待ちが無くなる。

## 制限

- **macOS / Apple Silicon のみ。** bottle は `arm64_tahoe` だけ焼いている。他の環境ではソースビルドにフォールバックする (5 分ほど)。
- `kitty.app` は Cellar の中に入る。Homebrew には formula から `.app` を配置する仕組みが無い (`brew linkapps` は削除済み) ので、`~/Applications` への symlink は自分で張る。`opt` パスはバージョンに依らないので一度張れば良い。
