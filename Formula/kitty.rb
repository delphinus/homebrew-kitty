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

  bottle do
    root_url "https://github.com/delphinus/homebrew-kitty/releases/download/kitty-0.49.0"
    sha256 cellar: :any, arm64_tahoe: "8308125d78590fc3f0bc33266485ed60aa61c16073af3dd09b4462ab0a8a7b35"
  end

  depends_on "go" => :build
  depends_on "pkgconf" => :build
  depends_on "simde" => :build
  # The slang resource below is the aarch64 build.
  depends_on arch: :arm64
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

  # 0.49 compiles kitty's shaders with the Slang compiler, and needs it again at
  # runtime for custom shaders. Homebrew has no shader-slang formula, so take
  # the upstream binary release, as kitty's own CI does. The version is the one
  # pinned in kitty's bypy/sources.json.
  resource "slang" do
    url "https://github.com/shader-slang/slang/releases/download/v2026.14.1/slang-2026.14.1-macos-aarch64.tar.gz"
    sha256 "92da7ab6226dd951037cd85397f830ae78fe40fbbb8928882e0b2654e468fdd4"
  end

  # Decide the number of cells a symbol needs from its advance as well as its
  # ink, so that non-mono Nerd Font glyphs are not shrunk into one cell.
  patch do
    url "https://github.com/delphinus/kitty/commit/b787020b92e2f4ef7a7cf1147ebfd963de73637d.patch?full_index=1"
    sha256 "729b97f0522c60103f753d8915f266047882d121151d3ed0a0715373b9339f44"
  end

  # Move rather than shrink a glyph whose ink already fits the cells available.
  patch do
    url "https://github.com/delphinus/kitty/commit/156480852c698d3bfe5950ec7cb3a632db877378.patch?full_index=1"
    sha256 "b958b8c3a21d922572c6760dfd83dbd89b7feb0037d0ad79403131eb12fbb7b9"
  end

  def install
    resource("symbols-nerd-font").stage do
      (buildpath/"fonts").install "SymbolsNerdFontMono-Regular.ttf"
    end

    # slangc finds its dylibs through @loader_path/../lib, so keep the layout.
    # libslang-llvm.dylib is 102MB and only serves the CPU and host targets,
    # which kitty never asks for: it compiles to GLSL.
    resource("slang").stage do
      libexec.install "bin"
      (libexec/"lib").install Dir["lib/*.dylib"] - ["lib/libslang-llvm.dylib"]
      (libexec/"lib").install Dir["lib/slang-standard-module-*"]
    end
    # Homebrew rewrites the install names in the dylibs, which invalidates their
    # signatures, so it signs them ad-hoc again. The binaries keep the vendor
    # signature, and dyld refuses to map an ad-hoc dylib into a process with a
    # Team ID. Sign the binaries ad-hoc too, so that the whole set agrees.
    libexec.glob("bin/*").each do |f|
      system "codesign", "--force", "--sign", "-", f if f.mach_o_executable?
    end
    ENV["SLANGC"] = libexec/"bin/slangc"

    # NOTE: setup.py copies the compiled shaders into the bundle before the
    # step that compiles them (package() copies, then create_macos_bundle_gunk
    # -> build_static_kittens -> build_shaders compiles), so on a clean tree the
    # copy dies with FileNotFoundError. Hand it an empty directory and install
    # the real shaders afterwards.
    (buildpath/"shaders").mkpath

    system formula_opt_bin("python@3.14")/"python3.14", "setup.py", "kitty.app"

    (buildpath/"kitty.app/Contents/Resources/kitty/shaders").install Dir["shaders/*"]
    prefix.install "kitty.app"
    # Custom shaders are compiled when kitty starts, so slangc has to stay
    # reachable. kitty looks it up in PATH unless $SLANGC says otherwise.
    bin.install_symlink libexec/"bin/slangc"
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
