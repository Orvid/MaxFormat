module main;

import std.algorithm;
import std.array : Appender, array;
import std.ascii : isDigit;
import std.conv : to;
import std.datetime : msecs, StopWatch;
import std.file : dirEntries, readText, SpanMode, write;
import std.getopt;
import std.regex;
import std.stdio : writeln, writefln;
import std.string;
import std.typecons;

__gshared bool enableBinaryUnaryOperatorSpacing = true;
__gshared bool enableConsecutiveSpaceFilter = true;
__gshared bool enableExplicitlyGlobalTransforms = true;
__gshared bool enableIdentifierCasing = true;
__gshared bool enableOperatorSpacing = true;
__gshared bool enableRegexTransforms = true;

__gshared bool enableStats = true;
__gshared bool enableStats_ExplicitlyGlobalTransforms = true;
__gshared bool enableStats_FullGlobalsList = false;
__gshared bool enableStats_FullIdentifierUseCount = false;
__gshared bool enableStats_Functions = true;
__gshared bool enableStats_Lines = true;
__gshared bool enableStats_Returns = true;
__gshared bool enableStats_RegexTransforms = true;
__gshared bool enableStats_RegexTransforms_Detailed = false;
__gshared bool enableStats_Timing = true;

__gshared string directoryToProcess = `F:\Autodesk\3ds Max Design 2014\scripts\WallWorm.com`;
__gshared string fileToProcess = `F:\Autodesk\3ds Max Design 2014\scripts\WallWorm.com\common\mse\wallwormVMF.ms`;
__gshared string outputFile;

void main(string[] args)
{
	getopt(
		args,
		"binary-unary-operator-spacing", &enableBinaryUnaryOperatorSpacing,
		"space-filter", &enableConsecutiveSpaceFilter,
		"identifier-casing", &enableIdentifierCasing,
		"operator-spacing", &enableOperatorSpacing,
		"regex-transforms", &enableRegexTransforms,
		"explicit-globals", &enableExplicitlyGlobalTransforms,
		"directory", &directoryToProcess,
		"stats", &enableStats,
		"stats-explicit-globals", &enableStats_ExplicitlyGlobalTransforms,
		"stats-full", &enableStats_FullIdentifierUseCount,
		"stats-functions", &enableStats_Functions,
		"stats-globals-list", &enableStats_FullGlobalsList,
		"stats-lines", &enableStats_Lines,
		"stats-returns", &enableStats_Returns,
		"stats-regex-transforms", &enableStats_RegexTransforms,
		"stats-regex-transforms-detailed", &enableStats_RegexTransforms_Detailed,
		"stats-timing", &enableStats_Timing,
		"out", &outputFile
	);

	if (args.length > 1)
		fileToProcess = args[1];

	if (!outputFile)
		outputFile = fileToProcess;

	if (directoryToProcess)
	{
		foreach (ent; dirEntries(directoryToProcess, SpanMode.breadth))
		{
			if (ent.isFile && ent.name.endsWith(".ms"))
			{
				writefln("Formatting %s", ent.name);
				StopWatch sw = StopWatch();
				sw.start();

				formatFile(ent.name, ent.name);

				sw.stop();
				if (enableStats_Timing)
					writefln("Done in %s ms", sw.peek().msecs);
			}
		}
	}
	else
	{
		formatFile(fileToProcess, outputFile);
	}

	if (enableStats)
	{
		if (enableStats_Lines)
		{
			writefln("Total of %s lines", Formatter.totalLines);
			writefln("Total of %s lines in comments", Formatter.totalLinesInComments);
		}
		if (enableStats_Returns && "return" in casedIdentifierUseCounts)
			writefln("Total of %s returns", casedIdentifierUseCounts["return"]);
		if (enableStats_Functions && "function" in casedIdentifierUseCounts)
			writefln("Total of %s functions", casedIdentifierUseCounts["function"]);
		if (enableStats_FullIdentifierUseCount)
			writeln(casedIdentifierUseCounts);

		if (enableStats_RegexTransforms)
			writefln("Took a total of %s ms to run %s regexes", regexTimingMap.byValue.sum(), regexTransforms.length);

		if (enableStats_RegexTransforms_Detailed)
		{
			foreach (k, v; regexTimingMap)
				writefln("Regex %s took %s ms", k, v);
		}

		if (enableStats_ExplicitlyGlobalTransforms)
		{
			writefln("Took %s ms to force %s explicit globals", explicitlyGlobalIdentifierSearchMapTime, explicitlyGlobalIdentifiers.length);
			writefln("Took %s ms to remove references to those explicit globals", explicitlyGlobalIdentifierGlobalRemovalTime);
		}

		if (enableStats_FullGlobalsList)
		{
			writefln("Total of %s globals", globalDeclarationMap.length);
			writeln(globalDeclarationMap);
		}
	}
}

@property auto cRegex(string pattern, string flags)()
{
	debug
		auto re = regex(pattern, flags);
	else
		alias re = ctRegex!(pattern, flags);
	return re;
}

__gshared Tuple!(typeof(cRegex!(`""`, "g")), string)[] regexTransforms;

string generateRegexTree(string[] str)
{
	static class Node
	{
		char leaf;
		Node[] children;

		this() { this.leaf = '\0'; }

		this(char c)
		{
			this.leaf = c;
		}

		static Node buildNode(string child, Node parent)
		{
			if (child == "")
			{
				auto n = new Node('\0');
				parent.children ~= n;
				return n;
			}
			foreach (c; parent.children)
			{
				if (c.leaf == child[0])
					return buildNode(child[1..$], c);
			}
			auto n = new Node(child[0]);
			parent.children ~= n;
			return buildNode(child[1..$], n);
		}

		string build()
		{
			string ret = "";
			if (leaf != '\0')
				ret ~= leaf;
			bool hasEndNode = children.any!(c => c.leaf == '\0');
			if (children.length == 1 && hasEndNode)
				hasEndNode = false;
			bool addGrouping = children.length > 1 || hasEndNode;

			if (addGrouping)
				ret ~= "(?:";
			ret ~= children.filter!(c => c.leaf != '\0').map!(c => c.build()).join('|');
			if (addGrouping)
				ret ~= ')';
			if (hasEndNode)
				ret ~= "?";

			return ret;
		}
	}

	Node root = new Node();
	foreach (c; str)
		root.buildNode(c, root);
	return root.build();
}

enum explicitlyGlobalIdentifiers = import("explicitlyGlobalIdentifiers.txt").split('\n').map!(i => i.strip()).array;
enum explicitlyGlobalIdentifiersRegexTree = generateRegexTree(explicitlyGlobalIdentifiers);
__gshared explicitlyGlobalRegexes = [
	cRegex!(`(?<!::|global |[a-zA-Z0-9_#"'.])(` ~ explicitlyGlobalIdentifiersRegexTree ~ `)(?!\.ms|[a-zA-Z0-9_])`, "gi"),
	cRegex!(`global (?:` ~ explicitlyGlobalIdentifiersRegexTree ~ `)\s*$`, "gim"),
];
__gshared immutable string[string] explicitlyGlobalIdentifierMap;
__gshared size_t explicitlyGlobalIdentifierSearchMapTime;
__gshared size_t explicitlyGlobalIdentifierGlobalRemovalTime;

__gshared immutable string[string] explicitIdentifierMap;
__gshared immutable bool[string] groupingIdentifierMap;

shared static this()
{
	regexTransforms = [
		// Style Regexes (These transform some code into a more uniform style)
		tuple(cRegex!(`^(\s*)if(?:\s+|(\())(.+?)do\s*\(\s*$`, "gm"), `$1if $2$3then (`),
		tuple(cRegex!(`((?:is|has)Property)\s+([a-zA-Z0-9_.]+)\s*#([a-zA-Z0-9_]+)\s*==\s*true`, "g"), `$1 $2 #$3`),
		tuple(cRegex!(`((?:is|has)Property)\s+([a-zA-Z0-9_.]+)\s*#([a-zA-Z0-9_]+)\s*==\s*false`, "g"), `NOT $1 $2 #$3`),
		
		// Performance Regexes (These transform code into a faster form)
		tuple(cRegex!(`((?:is|has)Property|(?:get|set)UserProp)\s+([a-zA-Z0-9_.]+?)\s+"([a-zA-Z0-9_]+?)"`, "g"), `$1 $2 #$3`),
		tuple(cRegex!(`((?:is|has)Property|(?:get|set)UserProp)\s+([a-zA-Z0-9_.]+?)\s+"([a-zA-Z0-9_ -]+?)"`, "g"), `$1 $2 #'$3'`),
		tuple(cRegex!(`([a-zA-Z0-9_]+)\s*!=\s*undefined\s+AND\s+isDeleted\s+\1\s*==\s*false`, "g"), `isValidNode $1`),
		tuple(cRegex!(`([a-zA-Z0-9_]+)\s*==\s*undefined\s+OR\s+isDeleted\s+\1\s*==\s*true`, "g"), `NOT isValidNode $1`),
		tuple(cRegex!(`^(\s*)(?:local\s+)?([a-zA-Z0-9_]+)\s*=\s*("[^+]+?")\s*?$^\s*format\s+\2 to:([a-zA-Z0-9_]+)$`, "gm"), `$1format $3 to:$4`),
		
		// Correctness Regexes (These help to ensure the correctness of code)
		tuple(cRegex!(`(?<!\.inode)\.handle`, "g"), `.inode.handle`),
		
		// WallWorm Specific Performance Regexes (These are performance regexes that are specific to WallWorm,
		// and while they may be possible to adapt to other projects, are not usefull to other projects in their
		// current form.)
		tuple(cRegex!(`isProperty ([a-zA-Z0-9_.]+)\s*#wallworm\s+(?:==\s*true)?\s*AND\s+isProperty\s+\1\s+#([a-zA-Z0-9_]+)(?:\s*==\s*true)?(\s+AND\s+\1\.\2\s*[!=]=\s*(?:".+?"|[a-zA-Z0-9_]+))?`, "g"), `isProperty $1 #$2$3 AND isProperty $1 #wallworm`),
		
		// Removal Regexes (These remove useless pieces of code)
		tuple(cRegex!(`\)\s*else\s*\(\s*\)`, "g"), `)`),
		tuple(cRegex!(`if(?:\s+|\().+?then\s*\(\s*\)(?!\s*else)`, "gm"), ``),
		
		// Dangerous Regexes (Any run with these enabled should be reviewed CAREFULLY)
		
		// Empty block comment removal
		//tuple(regex(`/\*\s*\*/`, "gm"), ``),
		// Dissallow single-line if-then statements.
		//tuple(cRegex!(`^\s*if\s*(.+?)\s*then\s*([^(]+?)$(?!\s*\()`, "gm"), "if $1 then (\n$2\n)"),
	];

	string[string] explicitGlobals;
	foreach (str; explicitlyGlobalIdentifiers)
		explicitGlobals[str.toLower()] = str;
	explicitlyGlobalIdentifierMap = cast(immutable)explicitGlobals;

	bool[string] groupingMap;
	string[string] explicitIdentifiers = [
		// fn is special, and is replaced by "function" for style reasons.
		"fn": "function",
	];
	foreach (str; import("explicitlyCasedIdentifiers.txt").split('\n').map!(i => i.strip()).filter!(l => !l.startsWith("//") && l.length))
	{
		if (str[0] == '&')
		{
			str = str[1..$];
			// We can let a duplicate slide here, because the
			// check for explicit identifiers will catch it.
			groupingMap[str.toLower()] = true;
		}

		if (str in explicitIdentifiers)
			throw new Exception("The identifier '" ~ str ~ "' was already added!");
		explicitIdentifiers[str.toLower()] = str;
	}
	explicitIdentifierMap = cast(immutable)explicitIdentifiers;
	groupingIdentifierMap = cast(immutable)groupingMap;
}

__gshared size_t[string] casedIdentifierUseCounts;
__gshared size_t[size_t] regexTimingMap;
__gshared size_t[string] globalDeclarationMap;

void formatFile(string fileName, string outputFileName)
{
	auto txt = readText(fileName);

	__gshared ignoreRegionRegex = cRegex!(`--BEGIN IGNORE FORMAT(.|\s)*?--END IGNORE FORMAT`, "g");
	__gshared ignoreRegexOutputMatch = cRegex!(`/\*#!@#IGNORED REGION ([0-9]+) REPLACEMENT HERE\*/`, "g");
	__gshared globalDeclarationRegex = cRegex!(`global\s+([a-zA-Z0-9_]+)\s*$`, "gm");

	size_t currentIgnoreFormatID = 0;
	string[] ignoreFormatRegions;
	txt = txt.replaceAll!((match) {
		ignoreFormatRegions ~= match[0];
		return `/*#!@#IGNORED REGION ` ~ (currentIgnoreFormatID++).to!string() ~ ` REPLACEMENT HERE*/`;
	})(ignoreRegionRegex);
		
	if (enableStats_FullGlobalsList)
	{
		txt = txt.replaceAll!((match) {
			globalDeclarationMap[match[1].toLower()]++;
			return match[0];
		})(globalDeclarationRegex);
	}

	if (enableExplicitlyGlobalTransforms)
	{
		StopWatch sw = StopWatch();
		sw.start();

		txt = txt.replaceAll!((match) {
			return "::" ~ explicitlyGlobalIdentifierMap[match[1].toLower()];
		})(explicitlyGlobalRegexes[0]);

		sw.stop();
		explicitlyGlobalIdentifierSearchMapTime += sw.peek().msecs;
		sw.reset();

		sw.start();
		txt = txt.replaceAll(explicitlyGlobalRegexes[1], "");
		sw.stop();
		explicitlyGlobalIdentifierGlobalRemovalTime += sw.peek().msecs;
	}

	if (enableRegexTransforms)
	{
		StopWatch regexStopwatch = StopWatch();
		regexStopwatch.start();

		StopWatch sw2 = StopWatch();
		foreach (i, tup; regexTransforms)
		{
			sw2.start();
			txt = txt.replaceAll(tup[0], tup[1]);
			sw2.stop();
			regexTimingMap[i] += sw2.peek().msecs;
			sw2.reset();
		}

		regexStopwatch.stop();
		if (enableStats_Timing)
			writefln("\tTook %s ms to run %s regex transforms", regexStopwatch.peek().msecs, regexTransforms.length);
	}
	
	auto fmt = Formatter(txt);

	// Deal with any initial indentation.
	fmt.trimInlineWhitespace();

	bool currentLineUnaryBinary = false;
	bool currentLineBinaryUnary = false;
	bool nextLineUnaryBinary = false;
	bool nextLineBinaryUnary = false;
	fmt.onEndOfLine = () {
		currentLineUnaryBinary = nextLineUnaryBinary;
		nextLineUnaryBinary = false;

		currentLineBinaryUnary = nextLineBinaryUnary;
		nextLineBinaryUnary = false;
	};

	bool lastWasWhitespace = false;
	bool lastWasOperator = false;
	bool lastWasGrouping = false;
	bool lastWasDot = false;
	
	@property void lastWas(string type)()
	{
		/++
		 + This may not be clear what is happening at
		 + first glance, but it does have to be this
		 + way to handle certain cases.
		 + 
		 + Everything will always reset the "whitespace"
		 + and "dot" flags.
		 + 
		 + "operator" will always reset the "grouping" flag.
		 + 
		 + "grouping" will always reset the "operator" flag.
		 + 
		 + "whitespace" will never reset the "operator" or
		 + "grouping" flags.
		 +/

		lastWasWhitespace = false;
		lastWasDot = false;
		
		static if (type == "whitespace")
			lastWasWhitespace = true;
		else static if (type == "operator")
		{
			lastWasGrouping = false;
			lastWasOperator = true;
		}
		else static if (type == "grouping")
		{
			lastWasGrouping = true;
			lastWasOperator = false;
		}
		else
		{
			lastWasGrouping = false;
			lastWasOperator = false;
		}
		
		static if (type == "dot")
			lastWasDot = true;
		
		static if (type != "whitespace" && type != "operator" && type != "grouping" && type != "dot")
			static assert(0, "Expected whitespace, operator, grouping, or dot!");
	}
	
	
	auto mainStopwatch = StopWatch();
	mainStopwatch.start();
	
	while (!fmt.EOF)
	{
		auto c = fmt.get();
		
		switch(c)
		{
			case '0': .. case '9':
			{
				auto num = c ~ fmt.nextNumber();
				fmt.put(num);
				break;
			}

			case '_':
			case 'a': .. case 'z':
			case 'A': .. case 'Z':
			{
				auto ident = c ~ fmt.nextIdentifier();

				if (enableIdentifierCasing)
				{
					if (ident == "bit" && fmt.peek() == '.')
					{
						// We have to have a special case for bit.and, bit.or, etc.
						// otherwise we end up uppercasing them.
						fmt.put(ident);
						fmt.put(fmt.get());
						fmt.put(fmt.nextIdentifier().toLower());
					}
					else if (fmt.peek() == ':')
					{
						// It's a parameter name, ignore it's casing.
						fmt.put(ident);
					}
					// Because an annoying number of places don't
					// add a space after the format keyword -_-...
					else if (ident == "format")
					{
						fmt.put(ident);
						fmt.wantWhitespaceNext = true;
						lastWas!"whitespace";
						continue;
					}
					// Don't case group when used as a function.
					else if (ident == "group" && fmt.peekAfterWhitespace() != '"')
					{
						fmt.put(ident);
					}
					else if (auto a = (ident.toLower() in explicitIdentifierMap))
					{
						if (*a != "Color" || !lastWasDot)
							fmt.put(*a);
						else
							fmt.put(ident);
					}
					else
						fmt.put(ident);
				}
				else
					fmt.put(ident);

				casedIdentifierUseCounts[ident.toLower()]++;

				if (ident.toLower() in groupingIdentifierMap)
				{
					// A grouping identifier means we are expecting an unary expression.
					lastWas!"grouping";
					continue;
				}

				break;
			}
				
			case '#':
				fmt.put(c);
				fmt.put(fmt.nextIdentifier());
				break;
				
			case '\t':
			case ' ':
				if (fmt.peekAfterWhitespace() != ')' && fmt.peekAfterWhitespace() != ']')
				{
					if (!enableConsecutiveSpaceFilter)
						fmt.put(c);
					else if (!lastWasWhitespace)
						fmt.wantWhitespaceNext = true;
					lastWas!"whitespace";
					continue;
				}
				break;
				
			case '\'':
				fmt.put(c);
				while (!fmt.EOF)
				{
					c = fmt.get();
					fmt.put(c);
					if (c == '\\')
					{
						fmt.put(fmt.get());
					}
					else if (c == '\'')
					{
						break;
					}
				}
				break;
				
			case '"':
				fmt.put(c);
				fmt.inIgnoreIndent = true;
				while (!fmt.EOF)
				{
					c = fmt.get();
					fmt.put(c);
					if (c == '\\')
					{
						fmt.put(fmt.get());
					}
					else if (c == '"')
					{
						break;
					}
				}
				// Ensure there is a whitespace after the end of a string in most cases.
				if (fmt.peek() != ')' && fmt.peek() != ':' && fmt.peek() != ']' && fmt.peek() != '-' && fmt.peek() != '/')
					fmt.wantWhitespaceNext = true;
				fmt.inIgnoreIndent = false;
				break;
				
			case '+':
			case '*':
			case '<':
			case '>':
			case '=':
			case '!':
			{
				if (enableOperatorSpacing)
				{
					if ((c == '-' || c == '*') && fmt.peek() != '=' && !enableBinaryUnaryOperatorSpacing)
						goto default;

					bool neededIndent = fmt.needsIndent;
					if (!lastWasWhitespace && !lastWasGrouping)
						fmt.put(' ');
					fmt.put(c);

					bool wasEq = fmt.peek() == '=';
					if (wasEq)
						fmt.put(fmt.get());
					wasEq |= c == '=';

					bool doWhitespace = !lastWasGrouping;
					if (c == '-')
					{
						bool curLineUnary = false;

						if (neededIndent || lastWasGrouping || lastWasOperator || fmt.peek() != ' ')
							doWhitespace = currentLineBinaryUnary;
						else
							doWhitespace = !currentLineUnaryBinary;
					}
					else if (c == '*')
					{
						if (neededIndent || lastWasGrouping || lastWasOperator || fmt.peek() != ' ')
							doWhitespace = currentLineBinaryUnary;
						else
							doWhitespace = !currentLineUnaryBinary;
					}
					fmt.trimInlineWhitespace();

					if (doWhitespace)
					{
						fmt.wantWhitespaceNext = true;
						lastWas!"operator";
						if (wasEq)
							lastWas!"grouping";
						lastWas!"whitespace";
						continue;
					}
					lastWas!"operator";
					if (wasEq)
						lastWas!"grouping";
					continue;
				}
				else
					goto default;
			}
				
			case ',':
				fmt.put(c);
				fmt.trimInlineWhitespace();
				fmt.wantWhitespaceNext = true;
				lastWas!"grouping";
				lastWas!"whitespace";
				continue;
				
			case '-':
				if (fmt.peek() == '-')
				{
					fmt.inComment = true;
					fmt.put(c);
					switch (fmt.restOfLine().strip())
					{
						case "-BINARY":
							nextLineBinaryUnary = true;
							break;
						case "-UNARY":
							nextLineUnaryBinary = true;
							break;
						default:
							break;
					}

					while (!fmt.EOF)
					{
						c = fmt.get();
						if (c == '\n')
						{
							if (fmt.trimWhitespace())
								fmt.put('\n');
							fmt.put('\n');
							break;
						}
						else
							fmt.put(c);
					}

					fmt.inComment = false;

					lastWas!"whitespace";
					continue;
				}
				else
					goto case '+';
				
			case '/':
				if (fmt.peek() == '*')
				{
					fmt.inComment = true;
					auto beginIndent = fmt.currentIndent;
					fmt.put(c);
					fmt.put(fmt.get());

					bool effectIndent = fmt.peek() != '!';
					
					while (!fmt.EOF)
					{
						c = fmt.get();
						
						switch (c)
						{
							case '\n':
								if (fmt.trimWhitespace())
									fmt.put('\n');
								fmt.put('\n');
								break;
								
							case '(':
								if (effectIndent)
									fmt.currentIndent++;
								if (fmt.restOfLine().strip() == "")
								{
									fmt.put('(');
									if (fmt.trimWhitespace())
										fmt.put('\n');
									break;
								}
								goto default;
								
							case ')':
								if (effectIndent)
									fmt.currentIndent--;
								goto default;
								
							case '*':
								if (fmt.peek() == '/')
								{
									fmt.put(c);
									fmt.put(fmt.get());
									goto EndComment;
								}
								goto default;
								
							default:
								fmt.put(c);
								break;
						}
					}
					
				EndComment:
					fmt.currentIndent = beginIndent;
					fmt.inComment = false;
					break;
				}
				else
					goto case '+';
				
			case '(':
				fmt.currentIndent++;
				if (fmt.restOfLine().strip() == "")
				{
					fmt.put('(');
					if (fmt.trimWhitespace())
						fmt.put('\n');
					// Last was actually whitespace....
					lastWas!"whitespace";
					continue;
				}
				else
				{
					fmt.put(c);
					fmt.trimInlineWhitespace();
					lastWas!"grouping";
					continue;
				}
				
			case ')':
				fmt.currentIndent--;
				fmt.put(c);
				break;

			case ';':
			case '\n':
				if (fmt.trimWhitespace(c == ';' ? -1 : 0))
					fmt.put('\n');
				fmt.put('\n');
				lastWas!"whitespace";
				continue;
				
			case '.':
				fmt.put(c);
				lastWas!"dot";
				continue;
				
			// These characters don't get a space after them if followed by an operator.
			case ':':
			case '[':
			case '{':
				fmt.put(c);
				lastWas!"grouping";
				continue;
				
			default:
				fmt.put(c);
				break;
		}
		lastWasDot = false;
		lastWasGrouping = false;
		lastWasOperator = false;
		lastWasWhitespace = false;
	}
	fmt.close();

	txt = fmt.getBuffer();
	txt = txt.replaceAll!((match) {
		return ignoreFormatRegions[match[1].to!size_t()];
	})(ignoreRegexOutputMatch);

	write(outputFileName, txt);

	mainStopwatch.stop();

	if (enableStats_Timing)
		writefln("\tTook %s ms to perform main formatting of file.", mainStopwatch.peek().msecs);
}

struct Formatter
{
	private bool needsIndent = true;
	private int currentIndent;
	private string buf;
	private Appender!string outputBuffer;
	public bool wantWhitespaceNext = false;
	public bool inIgnoreIndent = false;
	public void delegate() onEndOfLine;
	public bool inComment = false;

	this(string str)
	{
		buf = str;
		outputBuffer = Appender!string();
		onEndOfLine = () { };
	}

	string getBuffer()
	{
		return outputBuffer.data;
	}

	void close()
	{
		put('\0');
	}

	@property bool EOF() { return buf.length == 0; }

	string nextNumber()
	{
		int i = 0;
		while (i < buf.length)
		{
			switch (buf[i])
			{
				case 'e', 'E':
					if (i + 2 < buf.length && (buf[i + 1] == '+' || buf[i + 1] == '-') && isDigit(buf[i + 2]))
					{
						i += 3;
						break;
					}
					goto default;

				case '.':
				case '0': .. case '9':
					i++;
					break;
				default:
					goto Return;
			}
		}
	Return:
		auto ret = buf[0..i];
		buf = buf[i..$];
		return ret;
	}

	string nextIdentifier()
	{
		int i = 0;
		while (i < buf.length)
		{
			switch (buf[i])
			{
				case '_':
				case 'a': .. case 'z':
				case 'A': .. case 'Z':
				case '0': .. case '9':
					i++;
					break;
				default:
					goto Return;
			}
		}
	Return:
		auto ret = buf[0..i];
		buf = buf[i..$];
		return ret;
	}

	string restOfLine()
	{
		auto i = buf.countUntil("\n");
		if (i == -1)
			return buf;
		return buf[0..i];
	}

	void trimInlineWhitespace()
	{
		static bool shouldTrimChar(immutable char c)
		{
			if (c == ' ' || c == '\t')
				return true;
			return false;
		}
		buf = buf.stripLeft!(c => shouldTrimChar(cast(char)c))();
	}

	bool trimWhitespace(int initialNewLineCount = 0)
	{
		int newLineCount = initialNewLineCount;
		bool inRN = false;
		bool shouldTrimChar(immutable char c)
		{
			if (c == ' ' || c == '\t')
				return true;
			if (inRN)
			{
				if (c == '\n')
				{
					newLineCount++;
					inRN = false;
					return true;
				}
				newLineCount++;
				inRN = false;
				return false;
			}

			if (c == '\r')
			{
				inRN = true;
				return true;
			}
			if (c == '\n')
			{
				newLineCount++;
				return true;
			}
			return false;
		}
		buf = buf.stripLeft!(c => shouldTrimChar(cast(char)c))();
		return newLineCount > 0;
	}

	char get()
	{
		auto b = buf[0];
		buf = buf[1..$];
		return b;
	}

	char peek()
	{
		if (buf.length)
			return buf[0];
		return '\0';
	}

	char peekAfterWhitespace()
	{
		foreach (i; 0..buf.length)
		{
			if (buf[i] != ' ' && buf[i] != '\t')
				return buf[i];
		}
		return '\0';
	}

	__gshared size_t totalLines = 0;
	__gshared size_t totalLinesInComments = 0;
	void put(char c)
	{
		if (wantWhitespaceNext)
		{
			wantWhitespaceNext = false;

			if (c != '\n' && c != '\r' && c != ' ' && c != '\t' && c != ',' && c != '\0')
			{
				outputBuffer.put(' ');
			}
		}

		if (needsIndent && c != '\n' && c != '\r')
		{
			// If the first character on a line is an LParen,
			// we would end up putting an extra indent level
			// if we didn't do this.
			if (c == '(')
			{
				currentIndent--;
				putIndent();
				currentIndent++;
			}
			else
				putIndent();
		}
		else if (c == '\n')
		{
			onEndOfLine();
			totalLines++;
			if (inComment)
				totalLinesInComments++;
			needsIndent = true;
		}

		// A null is output at the very end to ensure any final things required are output already.
		if (c != '\0')
		{
			outputBuffer.put(c);
		}
	}

	void put(string str)
	{
		foreach (char c; str)
			put(c);
	}

	void putIndent()
	{
		needsIndent = false;
		if (!inIgnoreIndent)
		{
			foreach (i; 0..currentIndent)
				put('\t');
		}
	}
}