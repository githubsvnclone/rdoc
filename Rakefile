require 'hoe'
$:.unshift 'lib'
require 'rdoc/rdoc'

$rdoc_rakefile = true

Hoe.spec 'rdoc' do
  developer 'Eric Hodel', 'drbrain@segment7.net'
  developer 'Dave Thomas', ''
  developer 'Phil Hagelberg', 'technomancy@gmail.com'
  developer 'Tony Strauss', 'tony.strauss@designingpatterns.com'

  self.remote_rdoc_dir = ''
  self.testlib = :minitest

  extra_dev_deps   << ['minitest', '~> 1.3']
  extra_rdoc_files << 'Rakefile'
  spec_extras['required_rubygems_version'] = '>= 1.3'
  spec_extras['homepage'] = 'http://rdoc.rubyforge.org'

  spec_extras[:post_install_message] = <<-EOF
RDoc 2.5 did not save method parameters, so you should upgrade your rdoc-data
gem to a version >= 2.5.3.

To have ri data for core and stdlib you'll need to:

  gem install rdoc-data

then run:

  rdoc-data --install

To have ri data for you gems you'll also need to run:

  gem rdoc --all --overwrite

If you don't want to rebuild the rdoc for `gem server`, add --no-rdoc.
  EOF
end

# These tasks expect to have the following directory structure:
#
#   git/git.rubini.us/code # Rubinius git HEAD checkout
#   svn/ruby/trunk         # ruby subversion HEAD checkout
#   svn/rdoc/trunk         # RDoc subversion HEAD checkout
#
# If you don't have this directory structure, set RUBY_PATH and/or
# RUBINIUS_PATH.

diff_options = "-urpN --exclude '*svn*' --exclude '*swp' --exclude '*rbc'"
rsync_options = "-avP --exclude '*svn*' --exclude '*swp' --exclude '*rbc' --exclude '*.rej' --exclude '*.orig'"

rubinius_dir = ENV['RUBINIUS_PATH'] || '../../../git/git.rubini.us/code'
ruby_dir = ENV['RUBY_PATH'] || '../../ruby/trunk'

desc "Updates Ruby HEAD with the currently checked-out copy of RDoc."
task :update_ruby do
  sh "rsync #{rsync_options} bin/rdoc #{ruby_dir}/bin/rdoc"
  sh "rsync #{rsync_options} bin/ri #{ruby_dir}/bin/ri"
  sh "rsync #{rsync_options} lib/ #{ruby_dir}/lib"
  sh "rsync #{rsync_options} test/ #{ruby_dir}/test/rdoc"
end

desc "Diffs Ruby HEAD with the currently checked-out copy of RDoc."
task :diff_ruby do
  options = "-urpN --exclude '*svn*' --exclude '*swp' --exclude '*rbc'"

  sh "diff #{diff_options} bin/rdoc #{ruby_dir}/bin/rdoc; true"
  sh "diff #{diff_options} bin/ri #{ruby_dir}/bin/ri; true"
  sh "diff #{diff_options} lib/rdoc.rb #{ruby_dir}/lib/rdoc.rb; true"
  sh "diff #{diff_options} lib/rdoc #{ruby_dir}/lib/rdoc; true"
  sh "diff #{diff_options} test #{ruby_dir}/test/rdoc; true"
end

desc "Updates Rubinius HEAD with the currently checked-out copy of RDoc."
task :update_rubinius do
  sh "rsync #{rsync_options} bin/rdoc #{rubinius_dir}/lib/bin/rdoc.rb"
  sh "rsync #{rsync_options} bin/ri #{rubinius_dir}/lib/bin/ri.rb"
  sh "rsync #{rsync_options} lib/ #{rubinius_dir}/lib"
  sh "rsync #{rsync_options} test/ #{rubinius_dir}/test/rdoc"
end

desc "Diffs Rubinius HEAD with the currently checked-out copy of RDoc."
task :diff_rubinius do
  sh "diff #{diff_options} bin/rdoc #{rubinius_dir}/lib/bin/rdoc.rb; true"
  sh "diff #{diff_options} bin/ri #{rubinius_dir}/lib/bin/ri.rb; true"
  sh "diff #{diff_options} lib/rdoc.rb #{rubinius_dir}/lib/rdoc.rb; true"
  sh "diff #{diff_options} lib/rdoc #{rubinius_dir}/lib/rdoc; true"
  sh "diff #{diff_options} test #{rubinius_dir}/test/rdoc; true"
end

