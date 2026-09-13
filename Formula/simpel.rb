class Simpel < Formula
  desc "Simple, Homebrew-style package manager"
  homepage "https://github.com/Node-Data/Simpel-CLI"
  url "https://github.com/Node-Data/Simpel-CLI/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "cd0a70b5a61aac89bde4d03691e6966df7327b5f79c163c1369ebd830299e0c9"
  license "MIT"
  head "https://github.com/Node-Data/Simpel-CLI.git", branch: "main"

  def install
    # Homebrew builds from source with swiftc (it does not use the Xcode project).
    # Build to a distinct name: on case-insensitive macOS filesystems an output
    # named "simpel" collides with the "Simpel" source directory.
    sources = Dir["Simpel/*.swift"]
    system "swiftc", "-O", "-o", "simpel-cli", *sources
    bin.install "simpel-cli" => "simpel"
  end

  test do
    assert_match "simpel #{version}", shell_output("#{bin}/simpel version")
    system bin/"simpel", "doctor"
  end
end
