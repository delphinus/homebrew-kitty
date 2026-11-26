# delphinus/homebrew-kitty

[kitty](https://github.com/kovidgoyal/kitty) を**本家に入っていない修正を当てた状態**でソースからビルドする Homebrew tap。

```sh
brew tap delphinus/kitty
brew install delphinus/kitty/kitty
ln -sfn "$(brew --prefix)/opt/kitty/kitty.app" ~/Applications/kitty.app
```

公式の cask (`brew install --cask kitty`) とは `kitty` コマンドが衝突するので、先に `brew uninstall --cask kitty` しておくこと。

## 何を直しているか

kitty は、私用領域 (PUA) の文字の後ろに空白があると、その空白を取り込んでアイコンを複数のセルに描く。このとき何セル使うかを**インクの外接矩形だけ**で決め、描く位置も**中央に寄せていない**。そのため、SF Mono Square や kitty 同梱の Symbols Nerd Font Mono のように、アイコンを正方形の advance の中央に置くフォントでは、インクの細いアイコン (`nf-md-flash` U+F0241 など) だけが 1 セルに入れられ、太いアイコンは 2 セルの左に寄る。この tap は 2 つのパッチでそれを直す。

| パッチ | 内容 |
|---|---|
| [`12ac105`](https://github.com/delphinus/kitty/commit/12ac10533d186cfaa4abb2eabaf604962b47fcdb) | 空白を取り込んで描くアイコンを、**インクの範囲で中央に置く** (`fonts.c`)。本家にも中央寄せの意図はあるが、フラグが手前の文字列のほうに渡っている |
| [`ead887c`](https://github.com/delphinus/kitty/commit/ead887c367f5c32bba7fc3bd132e4aab702d24ec) | 私用領域の文字のセル数を、インクだけでなく **advance も見て**決める (`fonts.c` / `core_text.m` / `freetype.c`) |

Nerd Font を当てた等幅フォント (`Nerd Font` と `Nerd Font Mono`) は advance が 1 セルなので、2 本目では何も変わらない (1 本目で、はみ出した太いアイコンが 2 セルの中央に寄るだけ)。Powerline のセパレータや進捗バーは kitty が自前で描くので、どちらの影響も受けない。直後に文字があって 1 セルに描くときの縮小は本家の 0.51.0 で直ったので、以前当てていた「縮めずに位置をずらす」パッチ (`1564808`) は外した。

**これは upstream の方針と衝突する類の変更ではなく、描画の正しさの修正**として上流に出すつもりのもの。マージされたらこの tap は畳む。

## 仕組み

- 本家の release tarball (`kitty-X.Y.Z.tar.xz`) を取ってきて `patch` で 2 つのコミットを当てる。fork を rebase して追従する運用にはしていないので、**バージョン上げは formula の `url` と `sha256` の 2 行だけ**で済む。
- 0.49 からシェーダのコンパイルに Slang コンパイラ (`slangc`) が要る。Homebrew に `shader-slang` の formula が無いので、上流の CI と同じく公式のビルド済みバイナリを `resource` で取って `libexec` に置き、`$SLANGC` で参照させる。カスタムシェーダは kitty の起動時にコンパイルされるので `bin/slangc` の symlink も張る (GLSL 出力に使わない 102MB の `libslang-llvm.dylib` は除いてある)。
- 上流に新しいリリースが出ると [`upstream.yml`](.github/workflows/upstream.yml) が日次で検知して PR を作る。パッチが当たらなくなった場合はその PR の CI が落ちるので、そこで気付ける。
- main に入ると [`bottle.yml`](.github/workflows/bottle.yml) が `arm64_tahoe` の bottle を焼いて release に上げ、formula に sha256 を書き戻す。2 台目以降はビルド待ちが無くなる。

## 制限

- **macOS / Apple Silicon のみ。** 同梱する Slang コンパイラが aarch64 版なので、formula 自体が `depends_on arch: :arm64` で Intel を弾く。bottle も `arm64_tahoe` だけ。
- `kitty.app` は Cellar の中に入る。Homebrew には formula から `.app` を配置する仕組みが無い (`brew linkapps` は削除済み) ので、`~/Applications` への symlink は自分で張る。`opt` パスはバージョンに依らないので一度張れば良い。
