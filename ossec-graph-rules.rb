#!/usr/bin/ruby
require 'rubygems'
require 'optparse'
require 'rgl/dot'
require 'rgl/adjacency'
require 'rexml/document'

def genGraph(options)
   rules = []
   graph = RGL::DirectedAdjacencyGraph.new
   options[:inputFilenames].each do |f|
      puts f
      doc = REXML::Document.new(open(f))
      rules += doc.elements.to_a('group/rule').collect{ |x| x.attributes['id'] }
      rules.each do |rule|
         doc.elements.to_a('group/rule[@id=' + rule + ']').collect{ |x|
            #If the rule has a parent rule
            if x.elements['if_sid'] then
               sid = x.elements['if_sid'].text.to_i
            #If the rule has a parent rule
            elsif x.elements['if_matched_sid'] then
               sid = x.elements['if_matched_sid'].text.to_i
            # No parent rule
            else
               sid = 0
            end
            graph.add_edge(sid, rule.to_i)
         }
      end
   end
   graph.write_to_graphic_file(fmt=options[:graphFormat], dotfile=options[:graphFilename])
end

if __FILE__ == $0 then
   options = {
      :graphFilename => 'graph',
      :graphFormat => 'png',
   }
   OptionParser.new { |opts|
     opts.banner = "Usage: #{File.basename($0)} [-f] [-t <filename>] <rule_file.xml>"

     opts.on('-f', '--graph-filename=FILENAME', 'Output file name for graph') do |arg|
      options[:graphFilename] = arg
     end

     opts.on('-t', '--image-format=FORMAT', 'File format of graph image. Examples: png, jpg. Default is png.') do |arg|
       options[:graphFormat] = arg
     end
   }.parse!

   if ARGV.empty? then
      raise OptionParser::MissingArgument, 'Rule file(s)'
   else
      options[:inputFilenames] = ARGV
   end
   puts "Wrote new graph: %s" % genGraph(options)
end
