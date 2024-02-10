class ComposerAT27 < Formula
  desc "Dependency Manager for PHP - Version 2.7.x"
  homepage "https://getcomposer.org/"
  url "https://getcomposer.org/installer"
  sha256 "95676541502ab5084ca5ea179059a8013a2755167a9d375feae97f333c002ecc"
  license "MIT"
  version "2.7.1"
  revision 0

  livecheck do
    url "https://getcomposer.org/versions"
    regex(/"2" \[\{[^\]\}]*"version": "([^"]+)"/i)
  end

  #bottle :unneeded

  keg_only :versioned_formula

  #deprecate! date: "2022-11-28", because: :versioned_formula

  depends_on "shivammathur/php/php" => [:build, :test]

  def install

    php_binary      = '/usr/bin/env php'
    composer_php    = "#{buildpath}/composer.php"
    composer_phar   = "#{buildpath}/composer.phar"
    composer_setup  = "#{buildpath}/composer-setup.php"

    mv "installer", composer_setup

    composer_setup_sha384 = `#{php_binary} -r 'echo hash_file("sha384", "#{composer_setup}");'`
    fail "invalid checksum for composer-installer" unless "edb40769019ccf227279e3bdd1f5b2e9950eb000c3233ee85148944e555d97be3ea4f40c3c2fe73b22f875385f6a5155" == composer_setup_sha384

    composer_setup_check = `#{php_binary} #{composer_setup} --check --no-ansi`.strip
    fail composer_setup_check unless "All settings correct for using Composer" == composer_setup_check

    system "#{php_binary} #{composer_setup} --install-dir=#{buildpath} --version=#{version} --no-ansi --quiet"

    composer_phar_sha256 = `#{php_binary} -r 'echo hash_file("sha256", "#{composer_phar}");'`
    fail "invalid checksum for composer.phar" unless "1ffd0be3f27e237b1ae47f9e8f29f96ac7f50a0bd9eef4f88cdbe94dd04bfff0" == composer_phar_sha256

    composer_version = `#{php_binary} #{composer_phar} --version --no-ansi`
    fail "invalid version for composer.phar" unless /^Composer version #{Regexp.escape(version)}( |$)/.match?(composer_version)

    system "#{php_binary} -r '\$p = new Phar(\"#{composer_phar}\", 0, \"composer.phar\"); echo \$p->getStub();' >#{composer_php}"

    inreplace composer_php do |s|
      composer_stub = <<~EOS

        if (false === getenv('COMPOSER_HOME') && !isset($_SERVER['COMPOSER_HOME'], $_ENV['COMPOSER_HOME'])) {
            putenv('COMPOSER_HOME=' . ($_SERVER['COMPOSER_HOME'] = $_ENV['COMPOSER_HOME'] = $_SERVER['HOME'] . '/.composer/composer27-php'));
        }

        if (false === getenv('COMPOSER_PHAR') && !isset($_SERVER['COMPOSER_PHAR'], $_ENV['COMPOSER_PHAR'])) {
            putenv('COMPOSER_PHAR=' . ($_SERVER['COMPOSER_PHAR'] = $_ENV['COMPOSER_PHAR'] = '#{composer_phar}'));
        }

      EOS

      if !OS.linux? then
        composer_stub += <<~EOS
          if (false === getenv('COMPOSER_CACHE_DIR') && !isset($_SERVER['COMPOSER_CACHE_DIR'], $_ENV['COMPOSER_CACHE_DIR'])) {
              # @see https://github.com/composer/composer/pull/9898
              putenv('COMPOSER_CACHE_DIR=' . ($_SERVER['COMPOSER_CACHE_DIR'] = $_ENV['COMPOSER_CACHE_DIR'] = $_SERVER['HOME'] . '/Library/Caches/composer'));
          }

        EOS
      end

      s.gsub! /^Phar::mapPhar\('composer\.phar'\);/, composer_stub
      s.gsub! /phar:\/\/composer\.phar/, "phar://#{lib}/composer.phar"
      s.gsub! /^__HALT_COMPILER.*/, ""
    end

    lib.install composer_phar
    lib.install composer_php
    lib.install composer_setup
    bin.install "#{lib}/composer.php" => "composer"
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
          "php": ">=5.3.4"
          },
        "autoload": {
          "psr-0": {
            "HelloWorld": "src/"
          }
        }
      }
    EOS

    (testpath/"src/HelloWorld/greetings.php").write <<~EOS
      <?php

      namespace HelloWorld;

      class Greetings {
        public static function sayHelloWorld() {
          return 'HelloHomebrew';
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

    system "#{bin}/composer", "install"
    assert_match /^HelloHomebrew$/, shell_output("php tests/test.php")
  end

  def caveats

    s = <<~EOS
      Hint: “#{name}” is meant to be used in conjunction with
      one or all of the sjorek/php/composer27-php* formulae.

      To install several composer formulae at once run:
        brew install sjorek/php/composer{1,22,23,24}-php{72,73,74,80,81,82}

      When running “composer” the COMPOSER_* environment-variables are
      adjusted per default:

      COMPOSER_HOME=${HOME}/.composer/composer27-php
    EOS

    if !OS.linux? then
      s += <<~EOS
          # @see https://github.com/composer/composer/pull/9898
          COMPOSER_CACHE_DIR=${HOME}/Library/Caches/composer
      EOS
    end

    s += <<~EOS

      Of course, these variables can still be overriden by you.

    EOS

    if !OS.linux? && Dir.exists?(ENV['HOME'] + "/.composer/cache") then
      s += <<~EOS
        ATTENTION: The COMPOSER_CACHE_DIR path-value has been renamed
        from ${HOME}/.composer/cache to /Library/Caches/composer.

        If you want to remove the old cache directory, run:
          rm -rf ${HOME}/.composer/cache

      EOS
    end

    s
  end

end