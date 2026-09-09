# typed: strict
# frozen_string_literal: true

# Homebrew package for the XCEasy Runner CLI.
class Xceasyctl < Formula
  desc "Runner for XCEasy-based UI tests on Apple devices"
  homepage "https://github.com/qa-point/xceasy-runner"
  url "https://github.com/qa-point/xceasy-runner/releases/download/v0.1.3/xceasy-runner-0.1.3-macos-universal.tar.gz"
  sha256 "6478aee982cf2086b97a1f2b84cb04c73cc96d28c48674f82f719fd4bc5c6dd5"
  license "Apache-2.0"

  depends_on "jq"
  depends_on :macos
  depends_on xcode: "15.0"

  def install
    bin.install "bin/xceasyctl"
    (libexec/"xceasy-runner").install Dir["libexec/xceasy-runner/*"]
  end

  test do
    ENV.prepend_path "PATH", bin
    assert_match "xceasy-runner #{version}", shell_output("/bin/zsh -f -c 'xceasyctl version'")
    assert_match "xceasy-runner #{version}", shell_output("#{bin}/xceasyctl version")
    assert_match "--plan-only", shell_output("#{bin}/xceasyctl help")
  end
end
