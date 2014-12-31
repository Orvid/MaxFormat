module main;

import std.algorithm;
import std.ascii : isDigit;
import std.datetime : msecs, StopWatch;
import std.file;
import std.getopt;
import std.regex;
import std.stdio;
import std.string;
import std.typecons;

__gshared bool enableConsecutiveSpaceFilter = false;
__gshared bool enableIdentifierCasing = false;
__gshared bool enableRegexTransforms = false;

__gshared string fileToProcess;
__gshared string outputFile;

void main(string[] args)
{
	getopt(
		args,
		"space-filter", &enableConsecutiveSpaceFilter,
		"identifier-casing", &enableIdentifierCasing,
		"regex-transforms", &enableRegexTransforms,
		"out", &outputFile
	);
	fileToProcess = args[1];

	if (!outputFile)
		outputFile = fileToProcess;

	auto txt = readText(fileToProcess);

	if (enableRegexTransforms)
	{
		StopWatch regexStopwatch = StopWatch();
		regexStopwatch.start();

		__gshared regexTransforms = [
			// Style Regexes (These transform some code into a more uniform style)
			tuple(regex(`^(\s*)if(?:\s+|(\())(.+?)do\s*\(\s*$`, "gm"), `$1if $2$3then (`),

			// Performance Regexes (These transform code into a faster form)
			tuple(regex(`((?:is|has)Property|(?:get|set)UserProp)\s+([a-zA-Z0-9_.]+?)\s+"([a-zA-Z0-9_]+?)"`, "g"), `$1 $2 #$3`),
			tuple(regex(`((?:is|has)Property|(?:get|set)UserProp)\s+([a-zA-Z0-9_.]+?)\s+"([a-zA-Z0-9_ -]+?)"`, "g"), `$1 $2 #'$3'`),
			tuple(regex(`([a-zA-Z0-9_]+)\s*!=\s*undefined\s+AND\s+isDeleted\s+\1\s*==\s*false`, "g"), `isValidNode $1`),
			tuple(regex(`([a-zA-Z0-9_]+)\s*==\s*undefined\s+OR\s+isDeleted\s+\1\s*==\s*true`, "g"), `NOT isValidNode $1`),
			tuple(regex(`(\s*)([a-zA-Z0-9_]+)\s*=\s*("[^+]+?")\s*?$\s*format\s+\2 to:([a-zA-Z0-9_]+)`, "gm"), `$1format $3 to:$4`),
			//tuple(regex(`isProperty ([a-zA-Z0-9_.]+)\s*#wallworm\s+(?:==\s*true)?\s*AND\s+isProperty\s+\1\s+#([a-zA-Z0-9_]+)(?:\s*==\s*true)?(\s+AND\s+\1\.\2\s*[!=]=\s*(?:".+?"|[a-zA-Z0-9_]+))?`, "g"), `isProperty $1 #$2$3 AND isProperty $1 #wallworm`),

			// Removal Regexes (These remove useless pieces of code)
			tuple(regex(`\)\s*else\s*\(\s*\)`, "g"), `)`),
			tuple(regex(`if(?:\s+|\().+?then\s*\(\s*\)(?!\s*else)`, "gm"), ``),

			// Alas, empty block comment removal is dangerous :(
			//tuple(regex(`/\*\s*\*/`, "gm"), ``),
		];

		foreach (tup; regexTransforms)
			txt = txt.replace(tup[0], tup[1]);
		regexStopwatch.stop();

		writefln("Took %s ms to run %s regex transforms", regexStopwatch.peek().msecs, regexTransforms.length);
	}

	auto fmt = Formatter(txt, outputFile);

	string[string] explicitIdentifierMap = [
		// Keywords
		"and": "AND",
		"as": "as",
		"case": "case",
		"catch": "catch",
		"collect": "collect",
		"coordsys": "coordsys",
		"default": "default",
		"do": "do",
		"dotnetclass": "dotNetClass",
		"dotnetobject": "dotNetObject",
		"else": "else",
		"false": "false",
		"filein": "fileIn",
		"for": "for",
		"function": "function",
		"global": "global",
		"if": "if",
		"in": "in",
		"local": "local",
		"not": "NOT",
		"of": "of",
		"off": "off",
		"on": "on",
		"or": "OR",
		"return": "return",
		"struct": "struct",
		"then": "then",
		"true": "true",
		"try": "try",
		"undefined": "undefined",
		"where": "WHERE",
		"while": "while",
		"with": "with",

		// Types
		"angleaxis": "AngleAxis",
		"array": "Array",
		"bigmatrix": "BigMatrix",
		"bigmatrixrowarray": "BigMatrixRowArray",
		"bitarray": "BitArray",
		"box2": "Box2",
		"camera": "Camera",
		"color": "Color",
		"directx_9_shader": "DirectX_9_Shader",
		"double": "Double",
		"editable_mesh": "Editable_Mesh",
		"editable_poly": "Editable_Poly",
		"eulerangles": "EulerAngles",
		"float": "Float",
		"geometryclass": "GeometryClass",
		"helper": "Helper",
		"integer": "Integer",
		"integer64": "Integer64",
		"integerptr": "IntegerPtr",
		"light": "Light",
		"matrix3": "Matrix3",
		"mesh": "Mesh",
		"multimaterial": "MultiMaterial",
		"plane": "Plane",
		"point2": "Point2",
		"point3": "Point3",
		"point4": "Point4",
		"quat": "Quat",
		"ray": "Ray",
		"shape": "Shape",
		"string": "String",
		"stringstream": "StringStream",
		"xrefmaterial": "XRefMaterial",

		// Modifiers
		"turn_to_poly": "Turn_To_Poly",

		// Functions
		"addbone": "addBone",
		"addmodifier": "addModifier",
		"animateall": "animateAll",
		"classof": "classOf",
		"convertto": "convertTo",
		"createfile": "createFile",
		"disablesceneredraw": "disableSceneRedraw",
		"dotnetclass": "dotNetClass",
		"dotnetobject": "dotNetObject",
		"enablesceneredraw": "enableSceneRedraw",
		"filein": "fileIn",
		"finditem": "findItem",
		"format": "format",
		"formattedprint": "formattedPrint",
		"getdef": "getDef",
		"getdefsource": "getDefSource",
		"getfacenormal": "getFaceNormal",
		"getfaceverts": "getFaceVerts",
		"getinisetting": "getINISetting",
		"getsafefacecenter": "getSafeFaceCenter",
		"getvert": "getVert",
		"getuserprop": "getUserProp",
		"iskindof": "isKindOf",
		"isproperty": "isProperty",
		"isvalidnode": "isValidNode",
		"matchpattern": "matchPattern",
		"messagebox": "messageBox",
		"openfile": "openFile",
		"print": "print",
		"redrawviews": "redrawViews",
		"replacevertexweights": "replaceVertexWeights",
		"setcurrentobject": "setCurrentObject",
		"setinisetting": "setINISetting",
		"setvertexweights": "setVertexWeights",
		"superclassof": "superClassOf",
		"trimleft": "trimLeft",
		"trimright": "trimRight",
		"uniquename": "uniqueName",

		// Function Containers
		"custattributes": "custAttributes",

		// Special Rules
		"fn": "function",
		"polyop": "polyop",
		"skinops": "skinOps",
	];

	foreach (k, v; explicitIdentifierMap)
	{
		// fn is a very special case.
		if (k != v.toLower() && k != "fn")
			throw new Exception("You misspelled '" ~ k ~ "' as '" ~ v ~ "' in the explicit identifier map!");
	}

	bool lastWasWhitespace = false;
	bool lastWasOperator = false;
	bool lastWasGrouping = false;
	bool lastWasDot = false;

	@property void lastWas(string type)()
	{
		lastWasWhitespace = false;
		lastWasOperator = false;
		lastWasGrouping = false;
		lastWasDot = false;
		static if (type == "whitespace")
			lastWasWhitespace = true;
		else static if (type == "operator")
			lastWasOperator = true;
		else static if (type == "grouping")
			lastWasGrouping = true;
		else static if (type == "dot")
			lastWasDot = true;
		else
			static assert(0, "Expected whitespace, operator, grouping, or dot!");
	}


	auto mainStopwatch = StopWatch();
	mainStopwatch.start();

	while (!fmt.EOF)
	{
		auto c = fmt.get();

		switch(c)
		{
			case '_':
			case 'a': .. case 'z':
			case 'A': .. case 'Z':
			case '0': .. case '9':
			{
				if (enableIdentifierCasing)
				{
					auto ident = c ~ fmt.nextIdentNum();
					if (ident == "bit" && fmt.peek() == '.')
					{
						// We have to have a special case for bit.and, bit.or, etc.
						// otherwise we end up uppercasing them.
						fmt.put(ident);
						fmt.put(fmt.get());
						fmt.put(fmt.nextIdentNum().toLower());
					}
					else if (fmt.peek() == ':')
						fmt.put(ident); // It's a parameter name, ignore it's casing.
					else if (auto a = (ident.toLower() in explicitIdentifierMap))
					{
						if (*a != "Color" || !lastWasDot)
							fmt.put(*a);
						else
							fmt.put(ident);
					}
					else
						fmt.put(ident);
					break;
				}
				else
					goto default;
			}
			
			case '#':
				fmt.put(c);
				fmt.put(fmt.nextIdentNum());
				break;

			case ';':
				goto case '\n';

			case '\t':
			case ' ':
				if (fmt.peek() != ')')
				{
					if (!enableConsecutiveSpaceFilter)
						fmt.put(c);
					else if (!lastWasWhitespace)
						fmt.put(' ');
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
				break;

			case '+':
			case '*':
			case '<':
			case '>':
			case '=':
			case '!':
			{
				if (!lastWasWhitespace && !lastWasGrouping)
					fmt.put(' ');
				fmt.put(c);

				if (fmt.peek() == '=')
					fmt.put(fmt.get());

				fmt.trimInlineWhitespace();
				if (c != '-' || lastWasOperator)
				{
					fmt.wantWhitespaceNext = true;
					lastWas!"whitespace";
					continue;
				}
				lastWas!"operator";
				continue;
			}

			case ',':
				fmt.put(c);
				fmt.trimInlineWhitespace();
				fmt.put(' ');
				lastWas!"whitespace";
				continue;

			case '-':
				if (fmt.peek() == '-')
				{
					fmt.put(c);
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
					lastWas!"whitespace";
					continue;
				}
				else
					goto case '+';

			case '/':
				if (fmt.peek() == '*')
				{
					auto beginIndent = fmt.currentIndent;
					fmt.put(c);
					fmt.put(fmt.get());

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
					break;
				}
				else
					goto default;

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
					lastWas!"grouping";
					continue;
				}

			case ')':
				fmt.currentIndent--;
				fmt.put(c);
				lastWas!"grouping";
				continue;

			case '\n':
				if (fmt.trimWhitespace())
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
			case ']':
			case '{':
			case '}':
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
	mainStopwatch.stop();

	writefln("Took %s ms to perform main formatting of file.", mainStopwatch.peek().msecs);
	fmt.close();
}

struct Formatter
{
	bool needsIndent = true;
	int currentIndent;
	private string buf;
	private File outputFile;
	bool wantWhitespaceNext = false;

	this(string str, string outputFileName)
	{
		buf = str;
		outputFile = File(outputFileName, "wb");
	}

	void close()
	{
		put('\0');
		outputFile.close();
	}

	@property bool EOF() { return buf.length == 0; }

	string nextIdentNum()
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

	bool trimWhitespace()
	{
		int newLineCount = 0;
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
		return newLineCount != 0;
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

	void put(char c)
	{
		if (wantWhitespaceNext)
		{
			wantWhitespaceNext = false;

			if (c != '\n' && c != '\r' && c != ' ' && c != '\t')
			{
				char[1] b2 = [' '];
				outputFile.rawWrite(b2[]);
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
			needsIndent = true;

		// A null is output at the very end to ensure any final things required are output already.
		if (c != '\0')
		{
			char[1] b = [c];
			outputFile.rawWrite(b[]);
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
		foreach (i; 0..currentIndent)
			put('\t');
	}
}