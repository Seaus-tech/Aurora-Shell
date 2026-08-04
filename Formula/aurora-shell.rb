class AuroraShell < Formula
  desc "Aurora-Shell — a personalized terminal environment for macOS"
  homepage "https://github.com/Seaus-tech/Aurora-Shell"
  url "https://github.com/Seaus-tech/Aurora-Shell/archive/refs/tags/v5.9.0.tar.gz"
  sha256 "fac9fe94f10195659228ace3e325dfada16ae8617b546ab1355c8cb4df4e3a63" # filled in after: shasum -a 256 v5.8.5.tar.gz
  license "MIT"
  version "5.9.0"

  depends_on "figlet"
  depends_on "lolcat"
  depends_on "jq"
  depends_on "fzf"
  depends_on "terminal-notifier" if OS.mac?

  def install
    # Install shared assets
    share_dir = share/"aurora-shell"
    share_dir.mkpath

    %w[
      brew-install.sh
      install.sh
      shell.aurora
      brew-progress.py
      spinner.js
      wx.js
      aurora_theme.sh
      cli-packages.json
    ].each do |f|
      (share_dir/f).write (buildpath/f).read if (buildpath/f).exist?
    end

    # Make shell.aurora executable and link to bin
    chmod 0755, share_dir/"brew-install.sh"
    chmod 0755, share_dir/"shell.aurora"
    bin.install_symlink share_dir/"shell.aurora"
  end

  def post_install
    # Run the silent installer
    system "bash", "#{share}/aurora-shell/brew-install.sh"
  end

  def caveats
    <<~EOS
      Aurora-Shell has been installed! 🐚

      Open a new terminal tab to complete setup.
      The configuration wizard will run automatically.

      To manually run the wizard:
        shell.aurora --config

      To update Aurora-Shell:
        shell.aurora --update
        or: brew upgrade aurora-shell
    EOS
  end

  test do
    assert_predicate share/"aurora-shell/brew-install.sh", :exist?
    assert_predicate bin/"shell.aurora", :exist?
  end
end
