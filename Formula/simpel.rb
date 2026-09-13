class Simpel < Formula
  desc "Simple, Homebrew-style package manager"
  homepage "https://github.com/Node-Data/Simpel-CLI"
  url "https://github.com/Node-Data/Simpel-CLI/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "PASTE_SHA256_HERE"
  license "MIT"
  head "https://github.com/Node-Data/Simpel-CLI.git", branch: "main"

  def install
    # Homebrew builds from source with swiftc (it does not use the Xcode project).
    sources = Dir["Simpel/*.swift"]
    system "swiftc", "-O", "-o", "simpel", *sources
    bin.install "simpel"
  end

  test do
    assert_match "simpel #{version}", shell_output("#{bin}/simpel version")
    system bin/"simpel", "doctor"
  end
end
