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
    ].each do |f|
      (share_dir/f).write (buildpath/f).read if (buildpath/f).exist?
    end

    chmod 0755, share_dir/"brew-install.sh"
    chmod 0755, share_dir/"install.sh"
    chmod 0755, share_dir/"shell.aurora"

    # Create a setup script that runs as the user
    (bin/"aurora-shell-setup").write <<~SH
      #!/bin/bash
      export AURORA_BREW_INSTALL=1
      bash "#{share}/aurora-shell/install.sh"
    SH
    chmod 0755, bin/"aurora-shell-setup"
    bin.install_symlink share_dir/"shell.aurora"
  end

  def post_install
    # No-op: user must run aurora-shell-setup manually (post_install runs as root)
  end

  def uninstall
    # Remove user data directory
    system "rm", "-rf", "#{Dir.home}/.aurora-shell_files"
    # Remove .zshrc lines
    zshrc = "#{Dir.home}/.zshrc"
    if File.exist?(zshrc)
      lines = File.readlines(zshrc).reject { |l| l.include?("aurora-shell") }
      File.write(zshrc, lines.join)
    end
  end

  def caveats
    <<~EOS
      Aurora-Shell has been installed! 🐚

      Run the setup wizard now:
        aurora-shell-setup

      Then open a new terminal tab — Aurora-Shell will be active.

      To update:
        brew upgrade aurora-shell
        aurora-shell-setup
    EOS
  end

  test do
    assert_predicate bin/"aurora-shell-setup", :exist?
    assert_predicate bin/"shell.aurora", :exist?
  end
end
