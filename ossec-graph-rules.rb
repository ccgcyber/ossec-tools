#!/usr/bin/ruby
require 'rubygems'
require 'optparse'
require 'rexml/document'
require 'rgl/adjacency'

DontCare = 0
SelfText = 1
ChildText = 2

Constraints = {
   "same_source_ip" => SelfText,
   "same_hostname" => SelfText,

   "action" => ChildText,
   "status" => ChildText,
   "hostname" => ChildText,
   "srcip" => ChildText,
   "dstip" => ChildText,
   "srcport" => ChildText,
   "dstport" => ChildText,
   "match" => ChildText,
   "regex" => ChildText,
   "user" => ChildText,
   "decoded_as" => ChildText,
   "extra_data" => ChildText,
   "list" => ChildText,
   "description" => ChildText,
}
FrequencyConstraints = {
   "frequency" => nil,
   "timeframe" => nil,
}

ExcludeParentConstraints = [
   "description",
]

class NinjaDirectedAdjacencyGraph < RGL::DirectedAdjacencyGraph
   def parent_vertex(vertex)
      ret = nil
      @vertice_dict.each_pair do |k,v|
         if v.include?(vertex) then
            ret = k
            break
         end
      end
      ret
   end

   def all_parent_vertices(vertex)
      parents = []
      curParent = vertex
      while curParent != nil do
         curParent = parent_vertex(curParent)
         parents << curParent if curParent and curParent != 0
      end
      parents
   end
end

def getGroupsFromFile(filename)
   if block_given?
      doc = ""
      yieldDoc = ""
      fd = open(filename)
      gStart = gEnd = false #group tag
      cStart = cEnd = false #comment tag
      fd.readlines.each do |line|
         gStart = true if line.match(/^<group.*>$/)
         gEnd = true if line.match(/^<\/group>/)
         cStart = true if line.match(/\s*<!--/)
         cStart = false if line.match(/\s*-->/)

         if gStart and not cStart
            doc += line
         end 
         if gStart and gEnd
            gStart = gEnd = cStart = false
            yieldDoc = doc 
            doc = ""
            yield yieldDoc
         end 
      end 
   end 
end

def printError(msg)
   $stderr.write("[Error]: #{msg}\n")
end

def outputConstraints(constraints, fd)
   constraints.sort.to_a.each do |rule, constraints|
      fd.write("Rule: #{rule}\n")
      constraints.each do |c|
         fd.write("\t")
         fd.write("(#{c['parent']}) ") if c['parent']
         fd.write("#{c['name']}")
         fd.write(" #{c['operator']} #{c['value']}") if c['operator']
         fd.write("\n")
      end
   end
end

def addConstraint(name, options={})
   {
      "name" => name,
      "value" => options[:value],
      "operator" => options[:operator],
      "parent" => options[:parent],
   }
end

def getRuleConstraint(node, options={})
   constraints = []

   raise Exception if not node
   node.attributes.each do |attr, value|
      if FrequencyConstraints.include?(attr) then
         constraints << addConstraint(attr, :value=>value, :operator=>'=')
      end
   end

   node.elements.each do |elem|
      text = nil
      if elem.name == "list" then
         constraintName = elem.attributes['field']
         operator = elem.attributes["lookup"]
      else
         constraintName = elem.name
         operator = "="
      end
      case Constraints[constraintName]
         when SelfText
            constraintValue = elem.name
            operator = nil
         when ChildText
            constraintValue = elem.text
         else
            next
      end
      constraints << addConstraint(constraintName, :value=>constraintValue, :operator=>operator, :parent=>options[:parent]) unless options[:parent] and ExcludeParentConstraints.include?(constraintName)
   end
   constraints
end

def getConstraints(graph, graphNodes)
   constraints = {}
   graph.to_a.each do |rule|
      #0 is the psuedo parent of all rules. It has no constraints or parents.
      next if rule == 0
      constraints[rule] = []
      begin
         #Add constraints from all parents
         graph.all_parent_vertices(rule).each do |parent|
            constraints[rule] += getRuleConstraint(graphNodes[parent], :parent=>parent)
         end
         #Add constraints from this rule
         constraints[rule] += getRuleConstraint(graphNodes[rule])
      rescue Exception
         printError("Rule node not found within specified rule files: #{rule}")
      end
   end
   constraints
end

def getGraph(filenames, options={})
   rules = []
   graph = NinjaDirectedAdjacencyGraph.new
   graphNodes = {}
   #Iterate over all rule files
   filenames.each do |f|
      puts f if options[:verbose]
      getGroupsFromFile(f) do |groupDoc|
         doc = REXML::Document.new(groupDoc)
         rules = doc.elements.to_a('group/rule').collect{ |x| x.attributes['id'] }
         #Iterate over all rules in this file
         rules.each do |rule|
            doc.elements.to_a("group/rule[@id='#{rule}']").collect{ |x|
               #If the rule has a parent rule
               if x.elements['if_sid'] then
                  sid = x.elements['if_sid'].text.to_i
               #If the rule has a previously matched parent rule
               elsif x.elements['if_matched_sid'] then
                  sid = x.elements['if_matched_sid'].text.to_i
               #If the rule has no parent rule, make its parent 0
               else
                  sid = 0
               end
               graphNodes[rule.to_i] = x
               graph.add_edge(sid, rule.to_i)
#            graph.add_edge(rule.to_i, sid) #Swap this line with the previous line to invert graph direction
            }
         end
      end
   end
   [graph, graphNodes]
end

def writeGraphic(graph, format='png', dotfile='graph')
   graph.write_to_graphic_file(fmt=format, dotfile=dotfile)
end


###main()
if __FILE__ == $0 then
   options = {
      :graphFormat => 'png',
      :graphFilename => 'graph',
      :constraintsFilename => 'constraints.txt',
   }

   begin 
      OptionParser.new { |opts|
        opts.banner = "Usage: #{File.basename($0)} [-f <graphic_filename>] [-t <image_format>] [-T] <rule_file.xml> [rule_file2.xml rule_file3.xml ...]"

        opts.on('-f', '--graph-filename=FILENAME', 'Output file name for graph') do |arg|
         options[:graphFilename] = arg
        end

        opts.on('-t', '--image-format=FORMAT', 'File format of graph image. Examples: png, jpg. Default is png.') do |arg|
          options[:graphFormat] = arg
        end

        opts.on('-g', '--write-graphic', 'Write out graphic image to file.') do
          options[:writeGraphic] = true
        end

        opts.on('-c', '--write-constraints', 'Write out a textual representation of all rule constraints to a file. Default is "constraints.txt"') do
          options[:printConstraints] = true
        end

        opts.on('-C', '--print-constraints', 'Print out a textual representation of all rule constraints to the terminal.') do
          options[:writeConstraints] = true
        end

        opts.on('-F', '--constraints-filename=FILENAME', 'Filename to use for the textual representation of all rule constraints.') do |arg|
          options[:constraintsFilename] = arg
        end

        opts.on('-v', '--verbose', 'Print extra stuff.') do
          options[:verbose] = true
        end
      }.parse!
   rescue OptionParser::MissingArgument => e
      puts e
      exit 1
   end

   if ARGV.empty? then
      raise OptionParser::MissingArgument, 'Rule file(s)'
   else
      options[:inputFilenames] = ARGV
   end

   graph, graphNodes = getGraph(options[:inputFilenames], options=options)
   if options[:writeGraphic] then
      require 'rgl/dot'
      graphic = writeGraphic(graph, format=options[:graphFormat], dotfile=options[:graphFilename]) if options[:writeGraphic]
      if options[:verbose] then
         puts "Wrote new graph: %s" % graphic if options[:writeGraphic]
      end
   end

   if options[:printConstraints] or options[:writeConstraints] then
      constraints = getConstraints(graph, graphNodes)
      if options[:printConstraints] then
         outputConstraints(constraints, $stdout)
      end
      if options[:writeConstraints] then
         fdObj = File.new(options[:constraintsFilename], "w")
         outputConstraints(constraints, fdObj)
      end
   end
end
###End main()
