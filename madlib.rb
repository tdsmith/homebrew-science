class Madlib < Formula
  desc "Library for scalable in-database analytics."
  homepage "http://madlib.net"
  url "https://github.com/madlib/madlib/archive/v1.8.tar.gz"
  sha256 "15d8ee925866f477f4fb62964a1ea6a15796e9c7db676d786928495249078df3"
  revision 1

  head "https://github.com/madlib/madlib.git"

  bottle do
    sha256 "946c93f1a6026985583fbd40dc5282c16755ca933c4565cb204b591a0df4006d" => :yosemite
    sha256 "9d0fe84684da54b840e0d89729935f501901d4b2537066017ac4ca5953414f2f" => :mavericks
    sha256 "200cf3d8190878226a7a1ce6fb632250039b29b1217d4de3c6f08fb3c508e04e" => :mountain_lion
  end

  boost_opts = []
  boost_opts << "c++11" if MacOS.version < :mavericks
  depends_on "boost" => boost_opts
  depends_on "boost-python" => boost_opts if build.with? "python"
  depends_on "cmake" => :build
  depends_on "postgresql" => ["with-python"]
  depends_on :python => :optional

  resource "pyxb" do
    url "https://downloads.sourceforge.net/project/pyxb/pyxb/1.2.4/PyXB-1.2.4.tar.gz"
    sha256 "024f9d4740fde187cde469dbe8e3c277fe522a3420458c4ba428085c090afa69"
  end

  resource "eigen" do
    url "https://bitbucket.org/eigen/eigen/get/3.2.2.tar.gz"
    sha256 "318d68c5a9c20ec20d08f1a50a10fb4991a25fd5474a969e771cd9f2a79c9e5f"
  end

  fails_with :clang do
    build 503
    cause "See http://jira.madlib.net/browse/MADLIB-865"
  end

  fails_with :gcc do
    build 5666
    cause "See http://jira.madlib.net/browse/MADLIB-865"
  end

  fails_with :llvm do
    build 5666
    cause "See http://jira.madlib.net/browse/MADLIB-865"
  end

  def install
    # http://jira.madlib.net/browse/MADLIB-913
    ENV.libstdcxx if ENV.compiler == :clang

    resource("pyxb").fetch
    resource("eigen").fetch

    args = %W[
      -DCMAKE_INSTALL_PREFIX=#{prefix}
      -DCMAKE_BUILD_TYPE=Release
      -DPYXB_TAR_SOURCE=#{resource("pyxb").cached_download}
      -DEIGEN_TAR_SOURCE=#{resource("eigen").cached_download}
    ]
    system "./configure", *args
    system "make", "install"

    # Replace symlink with real directory
    bin.delete
    bin.mkdir
    # MADlib has an unusual directory structure: bin is a symlink
    # to Current/bin, which in turn is a symlink to
    # Versions/<current version>/bin. Homebrew won't link
    # bin/madpack and, even if it did, madpack would not find
    # its dependencies. Hence, we create a shim script.
    (bin/"madpack").write <<-EOS.undent
      #!/bin/bash
      exec "#{prefix}/Current/bin/madpack" "$@"
    EOS
  end

  def caveats; <<-EOS.undent
    MADlib must be rebuilt if you upgrade PostgreSQL:

      brew reinstall madlib
    EOS
  end

  test do
    # The following fails if madpack cannot find its dependencies.
    system "#{bin}/madpack", "-h"
    pg_bin = Formula["postgresql"].bin
    # Start PostgreSQL server if it is not already running
    if File.exist? "#{var}/postgres/postmaster.pid"
      pg_running = true
    else
      pg_running = false
      system "launchctl", "load", Formula["postgresql"].opt_prefix/"homebrew.mxcl.postgresql.plist"
      sleep(5) # Wait for the server to start
    end
    system "#{pg_bin}/createdb", "-w", "-U", "#{ENV["USER"]}", "test_madpack"
    begin
      system "#{bin}/madpack", "-p", "postgres", "-c", "#{ENV["USER"]}/@localhost/test_madpack", "install"
      system "#{bin}/madpack", "-p", "postgres", "-c", "#{ENV["USER"]}/@localhost/test_madpack", "install-check"
    ensure # clean up
      system "#{pg_bin}/dropdb", "-w", "-U", "#{ENV["USER"]}", "test_madpack"
      system "launchctl", "unload", Formula["postgresql"].opt_prefix/"homebrew.mxcl.postgresql.plist" unless pg_running
    end
  end
end
