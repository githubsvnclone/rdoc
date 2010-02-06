require 'rubygems'
require 'minitest/autorun'
require 'rdoc/parser'
require 'rdoc/parser/ruby'

class TestRDocParser < MiniTest::Unit::TestCase

  def setup
    @RP = RDoc::Parser
    @binary_dat = File.expand_path '../binary.dat', __FILE__
  end

  def test_class_can_parse
    assert_equal @RP.can_parse(__FILE__), @RP::Ruby

    readme_file_name = File.expand_path '../README.txt', __FILE__

    unless File.exist? readme_file_name then # HACK for tests in trunk :/
      readme_file_name = File.expand_path '../../README.txt', __FILE__
    end

    assert_equal @RP.can_parse(readme_file_name), @RP::Simple

    assert_nil @RP.can_parse(@binary_dat)

    jtest_file_name = File.expand_path '../test.ja.txt', __FILE__
    assert_equal @RP::Simple, @RP.can_parse(jtest_file_name)

    jtest_rdoc_file_name = File.expand_path '../test.ja.rdoc', __FILE__
    assert_equal @RP::Simple, @RP.can_parse(jtest_rdoc_file_name)
  end

  ##
  # Selenium hides a .jar file using a .txt extension.

  def test_class_can_parse_zip
    hidden_zip = File.expand_path '../hidden.zip.txt', __FILE__
    assert_nil @RP.can_parse(hidden_zip)
  end

  def test_class_for_binary
    rp = @RP.dup

    def rp.can_parse(*args) nil end

    assert_nil @RP.for nil, @binary_dat, nil, nil, nil
  end

end

