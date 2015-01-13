module main;

import std.algorithm;
import std.array : Appender;
import std.ascii : isDigit;
import std.conv : to;
import std.datetime : msecs, StopWatch;
import std.file : dirEntries, readText, SpanMode, write;
import std.getopt;
import std.regex;
import std.stdio : writeln, writefln;
import std.string;
import std.typecons;

__gshared bool enableBinaryUnaryOperatorSpacing = false;
__gshared bool enableConsecutiveSpaceFilter = false;
__gshared bool enableIdentifierCasing = false;
__gshared bool enableOperatorSpacing = false;
__gshared bool enableRegexTransforms = false;

__gshared string fileToProcess = `F:\Autodesk\3ds Max Design 2014\scripts\WallWorm.com\common\mse\wallwormSMD.ms`;
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
	if (args.length > 1)
		fileToProcess = args[1];

	if (!outputFile)
		outputFile = fileToProcess;

	/*
	foreach (ent; dirEntries(`F:\Autodesk\3ds Max Design 2014\scripts\WallWorm.com`, SpanMode.breadth))
	{
		if (ent.isFile && ent.name.endsWith(".ms"))
		{
			writefln("Formatting %s", ent.name);
			StopWatch sw = StopWatch();
			sw.start();

			formatFile(ent.name, ent.name);

			sw.stop();
			writefln("Done in %s ms", sw.peek().msecs);
		}
	}
	*/

	formatFile(fileToProcess, outputFile);

	writefln("Total of %s lines", Formatter.totalLines);
	writefln("Total of %s returns", casedIdentifierUseCount["return"]);
	writefln("Total of %s functions", casedIdentifierUseCount["function"]);
	//writeln(casedIdentifierUseCount);
}

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

__gshared immutable string[string] explicitIdentifierMap;
__gshared immutable bool[string] groupingIdentifierMap;

shared static this()
{
	groupingIdentifierMap = [
		"AngleAxis": true,
		"by": true,
		"else": true,
		"return": true,
		"rotateXMatrix": true,
		"rotateYMatrix": true,
		"rotateZMatrix": true,
		"then": true,
	];

	explicitIdentifierMap = [
		// Keywords
		"and": "AND",
		"as": "as",
		"by": "by",
		"case": "case",
		"catch": "catch",
		"collect": "collect",
		"coordsys": "coordsys",
		"default": "default",
		"do": "do",
		"else": "else",
		"false": "false",
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
		"checker": "Checker",
		"color": "Color",
		"directx_9_shader": "DirectX_9_Shader",
		"dotnetclass": "DotNetClass",
		"dotnetobject": "DotNetObject",
		"donut": "Donut",
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
		"line": "Line",
		"matrix3": "Matrix3",
		"mesh": "Mesh",
		"multimaterial": "MultiMaterial",
		"plane": "Plane",
		"point2": "Point2",
		"point3": "Point3",
		"point4": "Point4",
		"quat": "Quat",
		"ray": "Ray",
		"rectangle": "Rectangle",
		"shape": "Shape",
		"splineshape": "SplineShape",
		"star": "Star",
		"string": "String",
		"stringstream": "StringStream",
		"xrefmaterial": "XRefMaterial",

		// Controls
		"angle": "Angle",
		"bitmap": "Bitmap",
		"button": "Button",
		"checkbox": "CheckBox",
		"checkbutton": "CheckButton",
		"colorpicker": "ColorPicker",
		"combobox": "ComboBox",
		"curvecontrol": "CurveControl",
		"dropdownlist": "DropDownList",
		"dotnetcontrol": "DotNetControl",
		"edittext": "EditText",
		"group": "Group",
		"groupbox": "GroupBox",
		"hyperlink": "Hyperlink",
		"imgtag": "ImgTag",
		"label": "Label",
		"listbox": "ListBox",
		"mapbutton": "MapButton",
		"materialbutton": "MaterialButton",
		"multilistbox": "MultiListBox",
		"pickbutton": "PickButton",
		"progressbar": "ProgressBar",
		"radiobuttons": "RadioButtons",
		"slider": "Slider",
		"spinner": "Spinner",
		"subrollout": "SubRollout",
		
		// Modifiers
		"turn_to_poly": "Turn_To_Poly",
		
		// Functions
		"addbone": "addBone",
		"addmodifier": "addModifier",
		"addnode": "addNode",
		"animateall": "animateAll",
		"classof": "classOf",
		"convertto": "convertTo",
		"createfile": "createFile",
		"disablesceneredraw": "disableSceneRedraw",
		"enablesceneredraw": "enableSceneRedraw",
		"filein": "fileIn",
		"filterstring": "filterString",
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
		"numsplines": "numSplines",
		"openfile": "openFile",
		"print": "print",
		"querybox": "queryBox",
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
		"layermanager": "LayerManager",
		"polyop": "polyop",
		"skinops": "skinOps",
		"subobjectlevel": "subObjectLevel",
	];

	bool[string] arr2;
	foreach (k, v; explicitIdentifierMap)
	{
		// fn is a very special case.
		if (k != v.toLower() && k != "fn")
			throw new Exception("You misspelled '" ~ k ~ "' as '" ~ v ~ "' in the explicit identifier map!");

		if (k != k.toLower())
			throw new Exception("The key '" ~ k ~ "' was not all lowercase!");

		if (k in arr2)
			throw new Exception("The key '" ~ k ~ "' was already added!");

		arr2[k] = true;
	}
}

__gshared size_t[string] casedIdentifierUseCount;

void formatFile(string fileName, string outputFileName)
{
	auto txt = readText(fileName);

	__gshared ignoreRegionRegex = regex(`--BEGIN IGNORE FORMAT(.|\s)*?--END IGNORE FORMAT`, "g");
	__gshared ignoreRegexOutputMatch = regex(`/\*#!@#IGNORED REGION ([0-9]+) REPLACEMENT HERE\*/`, "g");

	size_t currentIgnoreFormatID = 0;
	string[] ignoreFormatRegions;
	txt = txt.replaceAll!((match) {
		ignoreFormatRegions ~= match[0];
		return `/*#!@#IGNORED REGION ` ~ (currentIgnoreFormatID++).to!string() ~ ` REPLACEMENT HERE*/`;
	})(ignoreRegionRegex);

	if (enableRegexTransforms)
	{
		StopWatch regexStopwatch = StopWatch();
		regexStopwatch.start();

		foreach (tup; regexTransforms)
			txt = txt.replaceAll(tup[0], tup[1]);

		regexStopwatch.stop();
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
			case '_':
			case 'a': .. case 'z':
			case 'A': .. case 'Z':
			case '0': .. case '9':
			{
				auto ident = c ~ fmt.nextIdentNum();

				if (enableIdentifierCasing)
				{
					if (ident == "bit" && fmt.peek() == '.')
					{
						// We have to have a special case for bit.and, bit.or, etc.
						// otherwise we end up uppercasing them.
						fmt.put(ident);
						fmt.put(fmt.get());
						fmt.put(fmt.nextIdentNum().toLower());
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

				casedIdentifierUseCount[ident.toLower()]++;

				if (ident in groupingIdentifierMap)
				{
					// By means we are expecting an unary expression.
					lastWas!"grouping";
					continue;
				}

				break;
			}
				
			case '#':
				fmt.put(c);
				fmt.put(fmt.nextIdentNum());
				break;
				
			case '\t':
			case ' ':
				if (fmt.peek() != ')' && fmt.peek() != ']')
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

					fmt.trimInlineWhitespace();
					bool doWhitespace = !lastWasGrouping;
					if (c == '-')
					{
						if (neededIndent)
							doWhitespace = currentLineBinaryUnary;
						else if (lastWasGrouping)
							doWhitespace = currentLineBinaryUnary;
						else if (!isDigit(fmt.peek()))
							doWhitespace = !currentLineUnaryBinary;
						else if (lastWasOperator)
							doWhitespace = currentLineBinaryUnary;
						else
							doWhitespace = !currentLineUnaryBinary;
					}

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
	
	writefln("\tTook %s ms to perform main formatting of file.", mainStopwatch.peek().msecs);
}

struct Formatter
{
	bool needsIndent = true;
	int currentIndent;
	private string buf;
	private Appender!string outputBuffer;
	bool wantWhitespaceNext = false;
	bool inIgnoreIndent = false;
	public void delegate() onEndOfLine;

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

	__gshared size_t totalLines = 0;
	void put(char c)
	{
		if (wantWhitespaceNext)
		{
			wantWhitespaceNext = false;

			if (c != '\n' && c != '\r' && c != ' ' && c != '\t' && c != ',')
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