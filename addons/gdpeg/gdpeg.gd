"""
	Parsing Expression Grammar for Godot Engine 4
		by あるる / きのもと 結衣 @arlez80

	See also:
		https://bford.info/pub/lang/peg.pdf

	MIT License
"""

class_name GDPeg

class PegResult:
	var accept:bool
	var position:int
	var length:int
	var capture:Array
	var group:bool

	func _init(_accept:bool,_p:int,_length:int = 0,_capture:Array = []):
		self.accept = _accept
		self.position = _p
		self.length = _length
		self.capture = _capture

class PegTree:
	func parse( buffer:String, p:int = 0 ) -> PegResult:
		return self._parse( buffer, p )

	func _parse( buffer:String, p:int ) -> PegResult:
		return PegResult.new( false, p )

class PegDebug extends PegTree:
	var message:String
	var accept:bool

	func _init(_message:String,_accept:bool = true):
		self.message = _message
		self.accept = _accept

	func _parse( buffer:String, p:int ) -> PegResult:
		printt( p, self.message )
		return PegResult.new( self.accept, p )

class PegCapture extends PegTree:
	var a:PegTree
	var f:Callable

	func _init(_a:PegTree,_f:Callable = Callable()):
		self.a = _a
		self.f = _f

	func _parse( buffer:String, p:int ) -> PegResult:
		var ra:PegResult = a.parse( buffer, p )
		if ra.accept:
			var s:String = buffer.substr( p, ra.length )
			if not self.f.is_null( ):
				ra.capture = [self.f.call( s )]
			else:
				ra.capture = [s]
			return ra

		return PegResult.new( false, ra.position )

class PegCaptureFolding extends PegTree:
	var a:PegTree
	var f:Callable

	func _init(_a:PegTree,_f:Callable):
		self.a = _a
		self.f = _f

	func _parse( buffer:String, p:int ) -> PegResult:
		var ra:PegResult = a.parse( buffer, p )
		if ra.accept:
			if 0 < len( ra.capture ):
				var result:Array = [ra.capture[0]]
				for i in range( 1, len( ra.capture ) ):
					result = [self.f.call( result, ra.capture[i] )]
				ra.capture = result
			return ra

		return PegResult.new( false, ra.position )

class PegCaptureGroup extends PegTree:
	var a:PegTree

	func _init(_a:PegTree):
		self.a = _a

	func _parse( buffer:String, p:int ) -> PegResult:
		var ra:PegResult = a.parse( buffer, p )
		if ra.accept:
			ra.group = true
			return ra

		return PegResult.new( false, ra.position )

class PegCaptureFunction extends PegTree:
	var a:PegTree
	var f:Callable

	func _init(_a:PegTree,_f:Callable = Callable()):
		self.a = _a
		self.f = _f

	func _parse( buffer:String, p:int ) -> PegResult:
		var ra:PegResult = a.parse( buffer, p )
		if ra.accept:
			if not self.f.is_null( ):
				ra.capture = [f.call( ra.capture )]
			return ra

		return PegResult.new( false, ra.position )

class PegCaptureRemove extends PegTree:
	var a:PegTree

	func _init(_a:PegTree):
		self.a = _a

	func _parse( buffer:String, p:int ) -> PegResult:
		var ra:PegResult = a.parse( buffer, p )
		if ra.accept:
			ra.capture = []
			return ra

		return PegResult.new( false, ra.position )

class PegCaptureState extends PegTree:
	var a:PegTree
	var f:Callable

	func _init(_a:PegTree,_f:Callable = Callable()):
		self.a = _a
		self.f = _f

	func _parse( buffer:String, p:int ) -> PegResult:
		var ra:PegResult = a.parse( buffer, p )

		if not self.f.is_null():
			f.call( buffer, p, ra.capture )

		return ra

class PegLiteral extends PegTree:
	var literal:String = ""
	var literal_length:int = 0

	func _init(s:String):
		self.literal = s
		self.literal_length = len( s )

	func _parse( buffer:String, p:int ) -> PegResult:
		if buffer.substr( p, self.literal_length ) == self.literal:
			return PegResult.new( true, p, self.literal_length )
		else:
			return PegResult.new( false, p )

class PegAny extends PegTree:
	func _init():
		pass

	func _parse( buffer:String, p:int ) -> PegResult:
		if p < buffer.length( ):
			return PegResult.new( true, p, 1 )
		else:
			return PegResult.new( false, p )

class PegRegex extends PegTree:
	var regex:RegEx

	func _init(pattern:String,param:String = ""):
		self.regex = RegEx.new( )
		self.regex.compile( pattern )

	func _parse( buffer:String, p:int ) -> PegResult:
		var result:RegExMatch = self.regex.search( buffer, p )

		if result == null:
			return PegResult.new( false, p )

		if result.get_start( ) == p:
			return PegResult.new( true, p, len( result.strings[0] ) )
		else:
			return PegResult.new( false, p )

class PegConcat extends PegTree:
	var a:Array

	func _init(_a:Array):
		self.a = _a

	func _parse( buffer:String, p:int ) -> PegResult:
		var total_length:int = 0
		var total_capture:Array = []

		for t in self.a:
			var ra:PegResult = t.parse( buffer, p )
			if not ra.accept:
				return PegResult.new( false, ra.position )
			p += ra.length
			total_length += ra.length
			if ra.group:
				total_capture.append( ra.capture )
			else:
				total_capture += ra.capture

		return PegResult.new( true, p, total_length, total_capture )

class PegSelect extends PegTree:
	var a:Array = []

	func _init(_a:Array):
		self.a = _a

	func _parse( buffer:String, p:int ) -> PegResult:
		var max_p:int = p

		for t in self.a:
			var ra:PegResult = t.parse( buffer, p )
			if max_p < ra.position:
				max_p = ra.position
			if ra.accept:
				return ra

		return PegResult.new( false, max_p )

class PegGreedy extends PegTree:
	var a:PegTree
	var least:int
	var length:int

	func _init(_a:PegTree,_least:int = 0,_length:int = -1):
		self.a = _a
		self.least = _least
		self.length = _length

	func _parse( buffer:String, p:int ) -> PegResult:
		var total_length:int = 0
		var total_capture:Array = []
		var count:int = 0

		while true:
			var ra:PegResult = a.parse( buffer, p )
			if not ra.accept:
				break

			p += ra.length
			total_length += ra.length
			if ra.group:
				total_capture.append( ra.capture )
			else:
				total_capture += ra.capture

			count += 1
			if self.length != -1 and self.length <= count:
				break

		return PegResult.new( self.least <= count, p, total_length, total_capture )

class PegEnd extends PegTree:
	func _init():
		pass

	func _parse( buffer:String, p:int ) -> PegResult:
		return PegResult.new( buffer.length( ) <= p, p )

class PegAheadAccept extends PegTree:
	var a:PegTree

	func _init(_a:PegTree):
		self.a = _a

	func _parse( buffer:String, p:int ) -> PegResult:
		return PegResult.new( self.a.parse( buffer, p ).accept, p, 0 )

class PegAheadNotAccept extends PegTree:
	var a:PegTree

	func _init(_a:PegTree):
		self.a = _a

	func _parse( buffer:String, p:int ) -> PegResult:
		return PegResult.new( not self.a.parse( buffer, p ).accept, p, 0 )

static func capture( _a:PegTree, _f:Callable = Callable() ) -> PegTree:
	return PegCapture.new( _a, _f )

static func capture_folding( _a:PegTree, _f:Callable = Callable() ) -> PegTree:
	return PegCaptureFolding.new( _a, _f )

static func capture_group( _a:PegTree ) -> PegTree:
	return PegCaptureGroup.new( _a )

static func literal( s:String ) -> PegTree:
	return PegLiteral.new( s )

static func regex( pattern:String, param:String = "" ) -> PegTree:
	return PegRegex.new( pattern, param )

static func concat( _a:Array ) -> PegTree:
	return PegConcat.new( _a )

static func select( _a:Array ) -> PegTree:
	return PegSelect.new( _a )

static func greedy( _a:PegTree, _least:int = 0, _length:int = -1 ) -> PegTree:
	return PegGreedy.new( _a, _least, _length )

static func ahead_accept( _a:PegTree ) -> PegTree:
	return PegAheadAccept.new( _a )

static func ahead_not( _a:PegTree ) -> PegTree:
	return PegAheadNotAccept.new( _a )

class PegGenerator:
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		return null

class PegGeneratorName extends PegGenerator:
	var name:String
	func _init(_name:String):
		self.name = _name
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		return labels[self.name]

class PegGeneratorLiteral extends PegGenerator:
	var literal:String
	func _init(_literal:String):
		self.literal = _literal.replace( "\\r", "\r" ).replace( "\\n", "\n" ).replace( "\\t", "\t" ).replace( "\\\"", "\"" ).replace( "\\\'", "\'" ).replace( "\\\\", "\\" )
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		return PegCapture.new( PegLiteral.new( self.literal ) )

class PegGeneratorAny extends PegGenerator:
	func _init():
		pass
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		return PegCapture.new( PegAny.new( ) )

class PegGeneratorDebug extends PegGenerator:
	var message:String
	func _init(_message:String = ""):
		self.message = _message
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		return PegDebug.new( self.message, true )

class PegGeneratorRegex extends PegGenerator:
	var pattern:String
	var param:String
	func _init(_pattern:String,_param:String):
		self.pattern = _pattern.replace( "\\r", "\r" ).replace( "\\n", "\n" ).replace( "\\t", "\t" ).replace( "\\\"", "\"" ).replace( "\\\'", "\'" ).replace( "\\\\", "\\" )
		self.param = _param
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		return PegCapture.new( PegRegex.new( self.pattern, self.param ) )

class PegGeneratorSuffix extends PegGenerator:
	var child:PegGenerator
	var suffix:String
	func _init(_child:PegGenerator,_suffix:String):
		self.child = _child
		self.suffix = _suffix
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		var p: = self.child.compile( labels )
		match self.suffix:
			"*":
				return PegGreedy.new( p )
			"+":
				return PegGreedy.new( p, 1 )
			"?":
				return PegGreedy.new( p, 0, 1 )
		return null

class PegGeneratorPrefix extends PegGenerator:
	var child:PegGenerator
	var prefix:String
	func _init(_prefix:String,_child:PegGenerator):
		self.prefix = _prefix
		self.child = _child
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		var p: = self.child.compile( labels )
		match self.prefix:
			"&":
				return PegAheadAccept.new( p )
			"!":
				return PegAheadNotAccept.new( p )
		return null

class PegGeneratorConcat extends PegGenerator:
	var childs:Array
	func _init(_childs:Array):
		self.childs = _childs
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		if 2 <= len( self.childs ):
			var v:Array = []
			for child in self.childs:
				v.append( child.compile( labels ) )
			return PegConcat.new( v )
		else:
			return self.childs[0].compile( labels )

class PegGeneratorSelect extends PegGenerator:
	var childs:Array
	func _init(_childs:Array):
		self.childs = _childs
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		if 2 <= len( self.childs ):
			var v:Array = []
			for child in self.childs:
				v.append( child.compile( labels ) )
			return PegSelect.new( v )
		else:
			return self.childs[0].compile( labels )

class PegGeneratorDefine extends PegGenerator:
	var name:String
	var arrow:String
	var expr:PegGenerator
	func _init(_name:String,_arrow:String,_expr:PegGenerator):
		self.name = _name
		self.arrow = _arrow
		self.expr = _expr
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		var tree: = self.expr.compile( labels )

		match self.arrow:
			"<","=":
				if capture_functions.has( self.name ):
					tree = PegCaptureFunction.new( tree, capture_functions[self.name] )
				else:
					pass
			"<~":
				if capture_functions.has( self.name ):
					tree = PegCapture.new( tree, capture_functions[self.name] )
				else:
					pass
			"<-":
				tree = PegCaptureRemove.new( tree )
			"<:":
				tree = PegCaptureState.new( tree, capture_functions[self.name] )

		return tree

class PegGeneratorEnd extends PegGenerator:
	func _init():
		pass
	func compile( labels:Dictionary, capture_functions:Dictionary = {} ) -> PegTree:
		return PegEnd.new( )

class PegGeneratorFuncs:
	func name( _name:String ):
		return PegGeneratorName.new( _name )
	func literal( _literal:Array ):
		return PegGeneratorLiteral.new( _literal[0] )
	func regex( group:Array ):
		return PegGeneratorRegex.new( group[0], group[1] )
	func reg_range( _pattern:Array ):
		return PegGeneratorRegex.new( "[" + _pattern[0] + "]", "" )
	func any( _param:String ):
		return PegGeneratorAny.new( )
	func debug( _param:String ):
		return PegGeneratorDebug.new( )
	func suffix( group:Array ):
		if len( group ) == 2:
			return PegGeneratorSuffix.new( group[0], group[1] )
		return group[0]
	func prefix( group:Array ):
		if len( group ) == 2:
			return PegGeneratorPrefix.new( group[0], group[1] )
		return group[0]
	func concat( group:Array ):
		return PegGeneratorConcat.new( group )
	func select( group:Array ):
		return PegGeneratorSelect.new( group )
	func define( group:Array ):
		return PegGeneratorDefine.new( group[0].name, group[1], group[2] )
	func end( _param:String ):
		return PegGeneratorEnd.new( )

static func generate( src:String, capture_functions:Dictionary = {} ) -> PegTree:
	var gen: = PegGeneratorFuncs.new( )
	# プロトタイプ宣言（p_exprは先に使う）
	var p_expr: = PegSelect.new([ null ])
	# Blanks
	var p_eol: = PegRegex.new( "[\r\n]" )
	var p_comment: = PegRegex.new( "#[^\n\r]*" )
	var p_space: = PegGreedy.new(PegSelect.new([
		PegLiteral.new( " " )
	,	PegLiteral.new( "\t" )
	,	p_eol
	,	p_comment
	]))
	# Terminators
	var p_name: = PegConcat.new([
		PegCapture.new( PegRegex.new( "[A-Za-z_][A-Za-z0-9_]*" ), gen.name )
	,	p_space
	])
	var p_literal: = PegCaptureFunction.new(
		PegConcat.new([
			PegSelect.new([
				PegConcat.new([
					PegLiteral.new( "\"" )
				,	PegCapture.new( PegRegex.new( "(\\\\.|[^\"\\\\])*" ) )
				,	PegLiteral.new( "\"" )
				])
			,	PegConcat.new([
					PegLiteral.new( "\'" )
				,	PegCapture.new( PegRegex.new( "(\\\\.|[^'\\\\])*" ) )
				,	PegLiteral.new( "\'" )
				])
			])
		,	p_space
		])
	,	gen.literal
	)
	var p_regex: = PegCaptureFunction.new(
		PegConcat.new([
			PegLiteral.new( "~" )
		,	PegSelect.new([
				PegConcat.new([
					PegLiteral.new( "\"" )
				,	PegCapture.new( PegRegex.new( "(\\\\.|[^\"\\\\])*" ) )
				,	PegLiteral.new( "\"" )
				])
			,	PegConcat.new([
					PegLiteral.new( "\'" )
				,	PegCapture.new( PegRegex.new( "(\\\\.|[^\'\\\\])*" ) )
				,	PegLiteral.new( "\'" )
				])
			])
		,	PegCapture.new( PegRegex.new( "[A-Za-z]*" ) )
		,	p_space
		])
	,	gen.regex
	)
	var p_range: = PegCaptureFunction.new(
		PegConcat.new([
			PegLiteral.new( "[" )
		,	PegCapture.new( PegRegex.new( "(\\\\.|[^\\]\\\\])*" ) )
		,	PegLiteral.new( "]" )
		,	p_space
		])
	,	gen.reg_range
	)
	var p_any: = PegCapture.new( PegConcat.new([ PegLiteral.new( "." ), p_space ]), gen.any )
	var p_debug: = PegCapture.new( PegConcat.new([ PegLiteral.new( "@" ), p_space ]), gen.debug )
	var p_end: = PegCapture.new( PegConcat.new([ PegLiteral.new( "$" ), p_space ]), gen.end )
	# Operators
	var p_arrow: = PegConcat.new([
		PegCapture.new( 
			PegSelect.new([
				PegLiteral.new( "=" )
			,	PegLiteral.new( "<~" )
			,	PegLiteral.new( "<-" )
			,	PegLiteral.new( "<:" )
			,	PegLiteral.new( "<" )
			])
		)
	,	p_space
	])
	var p_select: = PegConcat.new([ PegLiteral.new( "/" ), p_space ])
	var p_lookahead: = PegConcat.new([ PegCapture.new( PegLiteral.new( "&" ) ), p_space ])
	var p_not: = PegConcat.new([ PegCapture.new( PegLiteral.new( "!" ) ), p_space ])
	var p_option: = PegConcat.new([ PegCapture.new( PegLiteral.new( "?" ) ), p_space ])
	var p_one_or_more: = PegConcat.new([ PegCapture.new( PegLiteral.new( "+" ) ), p_space ])
	var p_zero_or_more: = PegConcat.new([ PegCapture.new( PegLiteral.new( "*" ) ), p_space ])
	var p_factor: = PegConcat.new([
		PegLiteral.new( "(" )
	,	p_space
	,	p_expr
	,	PegLiteral.new( ")" )
	,	p_space
	])
	# Syntaxes
	var p_primary: = PegSelect.new([
		PegConcat.new([ p_name, PegAheadNotAccept.new( p_arrow ) ])
	,	p_factor
	,	p_literal
	,	p_regex
	,	p_range
	,	p_any
	,	p_debug
	,	p_end
	])
	var p_suffix: = PegCaptureFunction.new(
		PegConcat.new([
			p_primary
		,	PegGreedy.new(
				PegSelect.new([
					p_option
				,	p_one_or_more
				,	p_zero_or_more
				]),
				0, 1
			)
		,	p_space
		])
	,	gen.suffix
	)
	var p_prefix: = PegCaptureFunction.new(
		PegConcat.new([
			PegGreedy.new(
				PegSelect.new([
					p_lookahead
				,	p_not
				]),
				0, 1
			),
			p_suffix
		])
	,	gen.prefix
	)
	var p_concat: = PegCaptureFunction.new(
		PegGreedy.new(
			PegConcat.new([
				PegAheadNotAccept.new( p_select )
			,	p_prefix
			])
		,	1
		)
	,	gen.concat
	)
	p_expr.a[0] = PegCaptureFunction.new(
		PegConcat.new([
			p_concat
		,	PegGreedy.new(
				PegConcat.new([
					p_select
				,	p_concat
				])
			)
		])
	,	gen.select
	)
	var p_define: = PegCaptureFunction.new(
		PegConcat.new([
			p_name
		,	p_arrow
		,	p_expr
		,	p_space
		])
	,	gen.define
	)
	var root: = PegConcat.new([
		p_space
	,	PegGreedy.new( p_define, 1 )
	,	p_space
	,	PegAheadNotAccept.new( PegAny.new( ) )
	])

	var result: = root.parse( src, 0 )
	if not result.accept:
		return null

	# すべての定義を出す
	var labels:Dictionary = {}
	for def in result.capture:
		labels[def.name] = PegSelect.new([ null ])

	# コンパイル
	for def in result.capture:
		labels[def.name].a[0] = def.compile( labels, capture_functions )
	var root_node:PegTree = labels[result.capture[0].name]

	# 後始末
	for name in labels.keys( ):
		labels.erase( name )

	return root_node
