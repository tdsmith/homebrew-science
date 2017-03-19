class Plr < Formula
  desc "PL/R - R Procedural Language for PostgreSQL"
  homepage "http://www.joeconway.com/plr/"
  url "https://github.com/jconway/plr/archive/REL8_3_0_16.tar.gz"
  sha256 "57e2384f7b51328c9e6d92a40039cae7ac3e187ece03a1d33985b751f24bfe18"
  head "https://github.com/jconway/plr.git"
  revision 2

  bottle do
    sha256 "d922fd96dfd7a57f3eda499e1a7429ce3b35a181a639ccfd5b91f992c5eb1ac8" => :el_capitan
    sha256 "0cbedc73f64d238609f07859ad25c50157ccc603b597e0a2d12aca917a96e355" => :yosemite
    sha256 "c50f1945d374f35c94d832946f7a77db99de89fda1e86a81dcd4c4d91a76fe55" => :mavericks
  end

  depends_on "pkg-config" => :build
  depends_on "postgresql"
  depends_on "r"

  def install
    ENV["USE_PGXS"] = "1"
    pg_config = "#{Formula["postgresql"].opt_bin}/pg_config"
    system "make", "PG_CONFIG=#{pg_config}"
    mkdir "stage"
    system "make", "DESTDIR=#{buildpath}/stage", "PG_CONFIG=#{pg_config}", "install"
    lib.install Dir["stage/**/lib/*"]
    (doc/"postgresql/extension").install Dir["stage/**/share/doc/postgresql/extension/*"]
    (share/"postgresql/extension").install Dir["stage/**/share/postgresql/extension/*"]
  end

  test do
    pg_bin = Formula["postgresql"].opt_bin
    pg_port = "55561"
    system "#{pg_bin}/initdb", testpath/"test"
    pid = fork { exec "#{pg_bin}/postgres", "-D", testpath/"test", "-p", pg_port }

    begin
      sleep 2
      system "#{pg_bin}/createdb", "-p", pg_port
      system "#{pg_bin}/psql", "-p", pg_port, "--command", "CREATE DATABASE test;"
      system "#{pg_bin}/psql", "-p", pg_port, "-d", "test", "--command", "CREATE EXTENSION plr;"
    ensure
      Process.kill 9, pid
      Process.wait pid
    end
  end
end
