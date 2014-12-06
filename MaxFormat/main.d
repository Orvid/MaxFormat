module main;

import std.algorithm;
import std.file;
import std.stdio;
import std.string;

void main(string[] args)
{
	auto fmt = Formatter(readText(`F:\Autodesk\3ds Max Design 2014\scripts\WallWorm.com\common\mse\wallwormVMF.ms`), `F:\Autodesk\3ds Max Design 2014\scripts\tmp.formatted.ms`);

	bool lastWasWhitespace = false;
	while (!fmt.EOF)
	{
		auto c = fmt.get();

		switch(c)
		{
			case '\t':
			case ' ':
				lastWasWhitespace = true;
				fmt.put(c);
				continue;

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
					break;
				}
				else
					goto default;

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
					break;
				}
				else
					goto default;

			case ')':
				fmt.currentIndent--;
				goto default;

			case '\n':
				if (fmt.trimWhitespace())
					fmt.put('\n');
				fmt.put('\n');
				break;

			default:
				fmt.put(c);
				break;
		}
		lastWasWhitespace = false;
	}

	fmt.close();
}

struct Formatter
{
	bool needsIndent = true;
	int currentIndent;
	private string buf;
	private File outputFile;

	this(string str, string outputFileName)
	{
		buf = str;
		outputFile = File(outputFileName, "wb");
	}

	void close()
	{
		outputFile.close();
	}

	@property bool EOF() { return buf.length == 0; }

	string restOfLine()
	{
		auto i = buf.countUntil("\n");
		if (i == -1)
			return buf;
		return buf[0..i];
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
		if (needsIndent && c != '\n')
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
		char[1] b = [c];
		outputFile.rawWrite(b[]);
	}

	void putIndent()
	{
		needsIndent = false;
		foreach (i; 0..currentIndent)
			put('\t');
	}
}