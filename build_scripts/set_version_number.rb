#!/usr/bin/env ruby

require 'find'

dir = ENV['PROJECT_DIR']
if (dir)
  Dir.chdir dir
end

if (File.exists?('.git') && File.directory?('.git') && File.exists?('/usr/bin/git'))
	newversion = `/usr/bin/git describe --tags`.match(/(([0-9]+)(\.([0-9]+)){1,})(-([0-9]+))?(-g([0-9a-f]+))?/).to_s	# 
	['SPARQLKit/SPARQLKit.h'].each{|filename|
		buffer = File.new(filename,'r').read
		if !buffer.match(/#{Regexp.quote(newversion)}/)
			buffer = buffer.sub(/(#define SPARQLKIT_VERSION @\")(.*)(")/, '\1'+newversion+'\3');
			File.open(filename,'w') {|fw| fw.write(buffer)}
		end
	}
end
