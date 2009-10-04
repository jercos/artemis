import re


TOKEN_NUMBER   = "number"
TOKEN_IDENT    = "identifier"
TOKEN_COMMA    = "comma"
TOKEN_LPAREN   = "lparen"
TOKEN_RPAREN   = "rparen"
TOKEN_OP       = "operator"
TOKEN_ERROR    = "error"


ASSOC_RIGHT, ASSOC_LEFT = xrange(2)

PRECEDENCE, ASSOC = xrange(2)

OPERATORS = {

	"|": (1, ASSOC_LEFT),
	"^": (2, ASSOC_LEFT),
	"&": (3, ASSOC_LEFT),
	"+": (4, ASSOC_LEFT),
	"-": (4, ASSOC_LEFT),
	"*": (5, ASSOC_LEFT),
	"/": (5, ASSOC_LEFT),
	"%": (5, ASSOC_LEFT),
	"\\\\": (5, ASSOC_LEFT),
	"**": (6, ASSOC_RIGHT),
	"~": (7, ASSOC_RIGHT)
	

}
	
tokenizer_regex = (
	(TOKEN_NUMBER,   r"[-+]?\d+\.?\d*([eE][-+]?\d+)?"),
	(TOKEN_IDENT, r"[A-Za-z_][A-Za-z0-9_]*"),
	(TOKEN_COMMA,    r","),
	(TOKEN_LPAREN,   r"\("),
	(TOKEN_RPAREN,   r"\)"),
	(TOKEN_OP,       r"\+|-|\*\*?|/|\^|\\\\|\||%|~|&"),
	(TOKEN_ERROR,    r"\S")
)


def compile_regex(regs):
	
	reglist = []
	for reg in regs:
		reglist.append("?P<" + reg[0] + ">" + reg[1])
		
	rstr = "(" + ")|(".join(reglist) + ")"
	return re.compile(flags=re.VERBOSE, pattern=rstr).finditer



class Token(object):
	def __init__(self, toktype, contents, match):
		self.type = toktype
		self.string = contents
		
		self.start_char = match.start()
		self.end_char    = match.end()
		
		self.re_match = match
		
	def __repr__(self):
		return self.string
		return "<Token '%s', type=%s>" % (self.type, self.string)
		
	def __str__(self):
		return self.string


class InfixParser(object):
	def __init__(self):
		self.tokenizer = compile_regex(tokenizer_regex)

	def tokenize(self, string):
		match = self.tokenizer(string)
		return [Token(x.lastgroup, x.group(), x) for x in match]

	def parse(self, string):
		tokens = self.tokenize(string)
		output = self.to_rpn(tokens)
		
		return [tok.string for tok in output]
		
	def to_rpn(self, toks):	
		tokens = toks[:]
		output = []
		stack = []
		
		
		
		while len(tokens):
#			print "stack:", stack
		
			token = tokens.pop(0)
			tokentype = token.type
			if tokentype == TOKEN_NUMBER:
				output.append(token)
				continue
				
			if tokentype == TOKEN_IDENT:
				stack.append(token)
				continue
				
			if tokentype == TOKEN_COMMA:
				if len(stack) == 0: raise Exception("Syntax Error: misplaced comma or mismatched parens.")
				while stack[-1].type != TOKEN_LPAREN:
					output.append(stack.pop())
					if len(stack) == 0:
						raise Exception("Syntax Error: misplaced comma or mismatched parens.")
			
			if tokentype == TOKEN_OP:
			
				prec = OPERATORS[token.string][PRECEDENCE]
				asso = OPERATORS[token.string][ASSOC]
				
				while len(stack) and stack[-1].type == TOKEN_OP:
				
					prec2 = OPERATORS[stack[-1].string][PRECEDENCE]
					if asso == ASSOC_LEFT and prec > prec2:
						break
					if asso == ASSOC_RIGHT and prec >= prec2:
						break
						
					output.append(stack.pop())
					
				stack.append(token)
				
			if tokentype == TOKEN_LPAREN:
				stack.append(token)
				continue
				
			if tokentype == TOKEN_RPAREN:
				if len(stack) == 0: raise Exception("Syntax Error: mismatched parens.")
				
				while len(stack) and stack[-1].type != TOKEN_LPAREN:
					output.append(stack.pop())
					
				if len(stack) == 0: raise Exception("Syntax Error: mismatched parens.")
				
				stack.pop() # pop paren
				
				if len(stack) and stack[-1].type == TOKEN_IDENT:
					output.append(stack.pop())
				continue
				
			if tokentype == TOKEN_ERROR:
				output.append(token)
				continue
				
		while len(stack):
			tok = stack[-1]
			if tok.type == TOKEN_LPAREN or tok.type == TOKEN_RPAREN:
				raise Exception("Syntax Error: mismatched parens")
			output.append(stack.pop())
			
		return output
				
	
#ifp = InfixParser()

#ifp.parse("3 + 4 * 2 / (1 - 5) ** 2 ** 3")
ifp = InfixParser();
def parse(x):
	return ifp.parse(x)
