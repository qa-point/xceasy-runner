# typed: strict
# frozen_string_literal: true

# Homebrew package for the XCEasy Runner CLI.
class Xceasyctl < Formula
  desc "Runner for XCEasy-based UI tests on Apple devices"
  homepage "https://github.com/qa-point/xceasy-runner"
  url "https://github.com/qa-point/xceasy-runner/releases/download/v0.1.1/xceasy-runner-0.1.1-macos-universal.tar.gz"
  sha256 "f7538d878d4ff5b2ab4cd6c686737da204a995f4805090593420cb7f3a8d6af7"
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
