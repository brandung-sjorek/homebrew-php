class ComposerAT2 < Formula
  desc "Dependency Manager for PHP - Version 2.x"
  homepage "https://getcomposer.org/"
  url "https://getcomposer.org/download/2.0.8/composer.phar"
  sha256 "2021f0d52b446e0efe3c548cc058ab5671fa38cdbcf814e7911c7e9d71d61538"
  license "MIT"
  revision 2

  livecheck do
    url "https://github.com/composer/composer.git"
    regex(/^#{Regexp.escape(composer_version_from_formula_name)}\.[\d.]+$/i)
  end

  bottle :unneeded

  keg_only :versioned_formula

  #deprecate! date: "2022-11-28", because: :versioned_formula

  def composer_version_from_formula_name
    "#{name}".split("@", 2).last
  end

  def install
    lib.install "composer.phar"
    bin.install_symlink "#{lib}/composer.phar" => "composer"
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
end
