#!/usr/bin/ruby
require 'rubygems'
require 'rexml/document'
require 'rgl/adjacency'
require 'rgl/dot'

doc = REXML::Document.new(open(ARGV[0]))
rules = doc.elements.to_a('group/rule').collect{ |x| x.attributes['id'] }

graph = RGL::DirectedAdjacencyGraph.new

rules.each do |rule|
   sid = doc.elements.to_a('group/rule[@id=' + rule + ']').collect{ |x|
      if x.elements['if_sid'] then
         sid = x.elements['if_sid'].text.to_i
      elsif x.elements['if_matched_sid'] then
         sid = x.elements['if_matched_sid'].text.to_i
      else
         sid = 0
      end
      graph.add_edge sid, rule.to_i
   }
end

puts "Wrote new file: %s" % graph.write_to_graphic_file(fmt='png', dotfile='graphs')
