# typed: false
# frozen_string_literal: true

# kitty, built from source with a Nerd Font cell sizing fix that upstream does
# not carry. See the README of this tap for what the patches do and why.
class Kitty < Formula
  desc "GPU-based terminal emulator, patched for non-mono Nerd Fonts"
  homepage "https://github.com/kovidgoyal/kitty"
  url "https://github.com/kovidgoyal/kitty/releases/download/v0.49.0/kitty-0.49.0.tar.xz"
  sha256 "b8b51901a4a5545a3b49241b6ea2050dbae509dfabd60ffcdb598a3a1344ec9a"
  license "GPL-3.0-only"

  livecheck do
    url "https://github.com/kovidgoyal/kitty/releases/latest"
    strategy :header_match
    regex(%r{tag/v?(\d+(?:\.\d+)+)}i)
  end

  depends_on "go" => :build
  depends_on "pkgconf" => :build
  depends_on "simde" => :build
  depends_on "harfbuzz"
  depends_on "libpng"
  depends_on "little-cms2"
  depends_on :macos
  depends_on "openssl@3"
  depends_on "python@3.14"
  depends_on "xxhash"

  # setup.py bundles this font into the app and refuses to build without it.
  resource "symbols-nerd-font" do
    url "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/NerdFontsSymbolsOnly.zip"
    sha256 "fdca3682534f6f65e1ccb2345b0362ccf67d9b8eca7c8025330946e93e2473bc"
  end

  # Decide the number of cells a symbol needs from its advance as well as its
  # ink, so that non-mono Nerd Font glyphs are not shrunk into one cell.
  patch do
    url "https://github.com/delphinus/kitty/commit/6e7a72a02def30ff075b38688572310830e65001.patch?full_index=1"
    sha256 "08880ee151bc529b1f4483043355fb5d6fcecd8a8e269cb4a1961ac72c5e16c7"
  end

  # Move rather than shrink a glyph whose ink already fits the cells available.
  patch do
    url "https://github.com/delphinus/kitty/commit/2d47a99972a98a9c178e373adee58a14f124d589.patch?full_index=1"
    sha256 "1bda71d82852ae49f4c3d5ce7d95756cce9191de1239e325564e03e5dd97abce"
  end

  def install
    resource("symbols-nerd-font").stage do
      (buildpath/"fonts").install "SymbolsNerdFontMono-Regular.ttf"
    end

    system formula_opt_bin("python@3.14")/"python3.14", "setup.py", "kitty.app"

    prefix.install "kitty.app"
    bin.install_symlink prefix/"kitty.app/Contents/MacOS/kitty"
    bin.install_symlink prefix/"kitty.app/Contents/MacOS/kitten"
    man1.install Dir["docs/_build/man/*.1"]
    (share/"terminfo").install Dir["terminfo/*"]
  end

  def caveats
    <<~EOS
      Homebrew does not link .app bundles, so kitty.app lives in the Cellar:
        #{opt_prefix}/kitty.app

      To make it visible to Spotlight, Launchpad and the Dock:
        ln -sfn #{opt_prefix}/kitty.app ~/Applications/kitty.app

      The opt path above is stable across upgrades, so the symlink only has to
      be made once.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/kitty --version")
    assert_match version.to_s, shell_output("#{bin}/kitten --version")
  end
end
