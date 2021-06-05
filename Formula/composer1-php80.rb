class Composer1Php80 < Formula
  desc "Dependency Manager for PHP - Version 1.x"
  homepage "https://getcomposer.org/"
  url "file:///dev/null"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  license "MIT"
  version "1.10.22"
  revision 9

  livecheck do
    url "https://github.com/composer/composer.git"
    regex(/^1\.[\d.]+$/i)
  end

  bottle :unneeded

  #keg_only :versioned_formula

  #deprecate! date: "2022-11-28", because: :versioned_formula

  depends_on "php@8.0"
  depends_on "sjorek/php/composer@1"

  def install

    php_binary      = "#{HOMEBREW_PREFIX}/opt/php@8.0/bin/php"
    composer_php    = "#{buildpath}/#{name}.php"
    composer_phar   = "#{HOMEBREW_PREFIX}/opt/composer@1/lib/composer.phar"
    composer_setup  = "#{HOMEBREW_PREFIX}/opt/composer@1/lib/composer-setup.php"

    composer_setup_sha384 = `#{php_binary} -r 'echo hash_file("sha384", "#{composer_setup}");'`
    fail "invalid checksum for composer-installer" unless "756890a4488ce9024fc62c56153228907f1545c228516cbf63f885e036d37e9a59d27d63f46af1d4d07ee0f76181c7d3" == composer_setup_sha384

    composer_setup_check = `#{php_binary} #{composer_setup} --check --no-ansi`.strip
    fail composer_setup_check unless "All settings correct for using Composer" == composer_setup_check

    composer_version = `#{php_binary} #{composer_phar} --version --no-ansi`
    fail "invalid version for composer.phar" unless /^Composer version #{Regexp.escape(version)}( |$)/.match?(composer_version)

    composer_phar_sha256 = `#{php_binary} -r 'echo hash_file("sha256", "#{composer_phar}");'`
    fail "invalid checksum for composer.phar" unless "6127ae192d3b56cd6758c7c72fe2ac6868ecc835dae1451a004aca10ab1e0700" == composer_phar_sha256

    system "#{php_binary} -r '\$p = new Phar(\"#{composer_phar}\", 0, \"composer.phar\"); echo \$p->getStub();' >#{composer_php}"

    inreplace composer_php do |s|
      s.gsub! /^#!\/usr\/bin\/env php/, "#!#{php_binary}"
      s.gsub! /^Phar::mapPhar\('composer\.phar'\);/, <<~EOS
        if (false === getenv('COMPOSER_HOME')) {
            putenv('COMPOSER_HOME=' . $_SERVER['HOME'] . '/.composer/#{name}');
        }

        if (false === getenv('COMPOSER_CACHE_DIR')) {
            # @see https://github.com/composer/composer/pull/9898
            putenv('COMPOSER_CACHE_DIR=' . $_SERVER['HOME'] . '/Library/Caches/composer');
        }
      EOS
      s.gsub! /phar:\/\/composer\.phar/, "phar://#{composer_phar}"
      s.gsub! /^__HALT_COMPILER.*/, ""
    end

    lib.install composer_php
    bin.install_symlink "#{lib}/#{name}.php" => "#{name}"
  end

  test do

    (testpath/"composer.json").write <<~EOS
      {
        "name": "homebrew/test",
        "authors": [
          {
            "name": "Homebrew"
          }
        ],
        "require": {
          "php": "~8.0.0"
        },
        "autoload": {
          "psr-0": {
            "HelloWorld": "src/"
          }
        },
        "scripts": {
          "test": "@php tests/test.php"
        }
      }
    EOS

    (testpath/"src/HelloWorld/greetings.php").write <<~EOS
      <?php

      namespace HelloWorld;

      class Greetings {
        public static function sayHelloWorld() {
          return 'HelloHomebrew from version ' . PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;
        }
      }
    EOS

    (testpath/"tests/test.php").write <<~EOS
      <?php

      // Autoload files using the Composer autoloader.
      require_once __DIR__ . '/../vendor/autoload.php';

      use HelloWorld\\Greetings;

      echo Greetings::sayHelloWorld();
    EOS

    system "#{bin}/#{name}", "install"
    assert_match /^HelloHomebrew from version #{Regexp.escape("8.0")}$/,
      shell_output("#{bin}/#{name} -v run-script test")
  end

  def caveats
    s = <<~EOS

      When running “#{name}” the COMPOSER_* environment-variables are
      adjusted per default:

        COMPOSER_HOME=~/.composer/#{name}

        # @see https://github.com/composer/composer/pull/9898
        COMPOSER_CACHE_DIR=~/Library/Caches/composer

      Of course, these variables can still be overriden by you.

    EOS

    if Dir.exists?(ENV['HOME'] + "/.composer/cache") then
      s += <<~EOS

      ATTENTION: The COMPOSER_CACHE_DIR path-value has been renamed
      from “~/.composer/cache” to “~/Library/Caches/composer”.

      If you want to remove the old cache directory, run:

          rm -rf ~/.composer/cache

      EOS
    end

    if /^composer1-/.match?(name) then
      oldname = name.gsub(/^composer1-/, 'composer-')
      if Dir.exists?(ENV['HOME'] + "/.composer/#{oldname}") then
        s += <<~EOS

        ATTENTION: The COMPOSER_HOME path-value has been renamed
        from “~/.composer/#{oldname}” to “~/.composer/#{name}”!

        Please update your composer-home path and run a diagnose afterwards:

            mv -v ~/.composer/#{oldname} ~/.composer/#{name}
            #{name} diagnose

        EOS
      end
    end
  end

end
