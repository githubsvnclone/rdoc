require 'rubygems'
require 'minitest/autorun'
require 'tmpdir'
require 'rdoc/ri/driver'

class TestRDocRIDriver < MiniTest::Unit::TestCase

  def setup
    @tmpdir = File.join Dir.tmpdir, "test_rdoc_ri_driver_#{$$}"
    @home_ri = File.join @tmpdir, 'dot_ri'
    @cache_dir = File.join @home_ri, 'cache'
    @class_cache = File.join @cache_dir, 'classes'

    FileUtils.mkdir_p @tmpdir
    FileUtils.mkdir_p @home_ri
    FileUtils.mkdir_p @cache_dir

    @orig_home = ENV['HOME']
    ENV['HOME'] = @tmpdir

    options = RDoc::RI::Driver.process_args []
    options[:home] = @tmpdir
    @driver = RDoc::RI::Driver.new options
  end

  def teardown
    ENV['HOME'] = @orig_home
    FileUtils.rm_rf @tmpdir
  end

  def test_parse_name
    klass, type, meth = @driver.parse_name 'Foo::Bar'

    assert_equal 'Foo::Bar', klass, 'Foo::Bar class'
    assert_equal nil,        type,  'Foo::Bar type'
    assert_equal nil,        meth,  'Foo::Bar method'

    klass, type, meth = @driver.parse_name 'Foo#Bar'

    assert_equal 'Foo', klass, 'Foo#Bar class'
    assert_equal '#',   type,  'Foo#Bar type'
    assert_equal 'Bar', meth,  'Foo#Bar method'

    klass, type, meth = @driver.parse_name 'Foo.Bar'

    assert_equal 'Foo', klass, 'Foo.Bar class'
    assert_equal '.',   type,  'Foo.Bar type'
    assert_equal 'Bar', meth,  'Foo.Bar method'

    klass, type, meth = @driver.parse_name 'Foo::bar'

    assert_equal 'Foo', klass, 'Foo::bar class'
    assert_equal '::',  type,  'Foo::bar type'
    assert_equal 'bar', meth,  'Foo::bar method'
  end

end

