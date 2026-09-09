# typed: strict
# frozen_string_literal: true

# Homebrew package for the XCEasy Runner CLI.
class Xceasyctl < Formula
  desc "Runner for XCEasy-based UI tests on Apple devices"
  homepage "https://github.com/qa-point/xceasy-runner"
  url "https://github.com/qa-point/xceasy-runner/releases/download/v0.1.2/xceasy-runner-0.1.2-macos-universal.tar.gz"
  sha256 "cb232979942e35f7e7c6318cc2a5763e051b7a537d451b5a3b9d27a5dbd9da09"
  license "Apache-2.0"

  depends_on "jq"
  depends_on :macos
  depends_on xcode: "15.0"

  def install
    bin.install "bin/xceasyctl"
    (libexec/"xceasy-runner").install Dir["libexec/xceasy-runner/*"]
  end

  test do
    assert_match "xceasy-runner #{version}", shell_output("#{bin}/xceasyctl version")
    assert_match "--plan-only", shell_output("#{bin}/xceasyctl help")
  end
end
