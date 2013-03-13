require 'rubygems'
require 'tokyo_tyrant'
require 'mechanize'

def require_dir(dir)
  Dir.entries(dir).each { |file| Kernel.load(dir + '/' + file) unless (file =~ /^./) }
end


['dependencies_tokyo', 'models_tokyo', 'journal_getters', 'indexers_tokyo'].each { |d|
	require_dir(d)
}
