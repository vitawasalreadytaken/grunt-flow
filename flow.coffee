_ = require 'underscore'
c = console.log
s = (o) -> JSON.stringify o, null, 4

class File
	constructor: (@path, @original = null) ->
		@original ?= @path


class MergedFile extends File


class TemporaryFile extends File




class Node
	name: null
	evaluation: null
	getOutput: () ->
	evaluate: (inputNode, outputNode) -> []


class Reader extends Node
	constructor: (paths) ->
		@name = 'reader'
		@input = ((new File path) for path in paths)

	getOutput: () -> @input

	evaluate: (inputNode, outputNode) ->
		@evaluation = [ new FileSpec @name, {src: [], dest: (file for file in @input)} ]


class Writer extends Node
	constructor: (@outputPaths) -> @name = 'writer'

	getFinalOutput: (input) ->
		if @outputPaths.length not in [1, input.length]
			throw "Writer input has #{input.length} nodes but Writer is configured to output #{@outputPaths.length} nodes."

		if @outputPaths.length is 1
			[ new MergedFile @outputPaths[0], input ]
		else
			(new File output, input) for [output, input] in _.zip @outputPaths, input


class Task extends Node
	constructor: (@name) ->

	getTemporaryFiles: (inputFiles) ->
		(new TemporaryFile input.path + '.tmp', input) for input in inputFiles

	evaluate: (inputNode, outputNode) ->
		input = inputNode.getOutput()
		@output = if outputNode.constructor is Writer then outputNode.getFinalOutput input else @getTemporaryFiles input
		@evaluation = if input and @output then [ new FileSpec @name, {src: input, dest: @output} ] else []
		#c "task #{@name} ev", s r
		@evaluation

	getOutput: () ->
		@output



class Merger extends Node
	constructor: (@nodes) -> @name = 'merger'

	evaluate: (inputNode, outputNode) ->
		@evaluation = []
		for node in @nodes
			@evaluation.push.apply @evaluation, node.evaluate inputNode, outputNode # FIXME Writer will not work well with Merger
		@evaluation

	getOutput: () ->
		#for node in @nodes
		#	c 'merger node out', node.name, node.getOutput()
		_.flatten (node.getOutput() for node in @nodes), true



class Flow extends Node
	constructor: (@nodes) -> @name = 'flow'

	evaluate: (inputNode, outputNode) ->
		#zip = (xs...) ->
		#	for i in [0...Math.min.apply(null, x.length for x in xs)]
		#		(x[i] for x in xs)

		partitions = _.zip ([inputNode].concat _.initial @nodes), @nodes, (_.tail(@nodes).concat [outputNode])
		#c 'flow', @nodes, inputNode, outputNode, s partitions
		@evaluation = _.flatten (node.evaluate prev, next for [prev, node, next] in partitions), true

	getOutput: () ->
		#c 'flow output node', @nodes[1]
		(_.last @nodes).getOutput()



class FileSpec
	constructor: (@nodeName, @evaluated) ->

	generateConfig: () ->
		if @evaluated.src.length and @evaluated.dest.length
			embed = (hash, ks, data) ->
				if ks[1] then (embed (hash[ks[0]] = {}), ks[1..], data) else hash[ks[0]] = data
				hash

			data =
				files:
					if @evaluated.dest.length is 1
						[ {src: (file.path for file in @evaluated.src), dest: @evaluated.dest[0].path} ]
					else
						#c 'FS', @evaluated
						{src: src.path, dest: dest.path} for [src, dest] in _.zip @evaluated.src, @evaluated.dest

			embed {}, (@nodeName.split ':'), data




run = (nodes) -> new Flow nodes
read = (paths) -> new Reader paths
task = (name) -> new Task name
write = (paths) -> new Writer paths
merge = (flows) -> new Merger flows



COFFEE = ['assets/coffee/main.coffee', 'assets/coffee/cms.coffee']
JS = ['jquery.js', 'another.js']

dev = run [
	(read COFFEE),
	(task 'coffee:target'),
	(write ['main.js', 'cms.js'])
]

production = run [
	(merge [
		(run [(read COFFEE), (task 'coffee')]),
		(run [(read JS), (task 'test:target')])
	]),
	(task 'jslint'),
	(task 'uglify'),
	(write ['test.js'])
]

for spec in production.evaluate()
	config = spec.generateConfig()
	if config
		console.log JSON.stringify config, null, 2
