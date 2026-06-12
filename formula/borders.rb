# Omacase's borders formula — JankyBorders built from the splaice fork, which
# adds `square_apps=` (per-app square borders for square-cornered windows like
# undecorated Ghostty). Synced into the local tap splaice/formulae by
# `omacase install`; drop back to FelixKratz/formulae/borders in the Brewfile
# if the feature ever lands upstream.
class Borders < Formula
  env :std
  desc "Window border system for macOS (square_apps fork)"
  homepage "https://github.com/splaice/JankyBorders"
  url "https://github.com/splaice/JankyBorders/archive/refs/tags/v1.9.0-square.1.tar.gz"
  version "1.9.0-square.1"
  sha256 "b7aa2f1165fb7c4430c1ea32907c9a0c42abbe83429ed68d8bebac29d06049d2"
  license "GPL-3.0-only"
  head "https://github.com/splaice/JankyBorders.git", branch: "square-apps"

  def clear_env
    ENV.delete("CFLAGS")
    ENV.delete("LDFLAGS")
    ENV.delete("CXXFLAGS")
  end

  def install
    clear_env
    (var/"log/jankyborders").mkpath
    system "make"

    system "codesign", "--force", "-s", "-", "#{buildpath}/bin/borders"
    bin.install "#{buildpath}/bin/borders"

    man.mkpath
    man1.install "#{buildpath}/docs/borders.1"
  end

  service do
    run "#{opt_bin}/borders"
    environment_variables PATH: std_service_path_env, LANG: "en_US.UTF-8"
    keep_alive true
    process_type :interactive
    log_path "#{var}/log/borders/borders.out.log"
    error_log_path "#{var}/log/borders/borders.err.log"
  end

  test do
    system "#{bin}/borders", "--version"
  end
end
