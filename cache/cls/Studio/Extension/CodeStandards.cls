Include (Studio.Extension.CodeStandards, %occErrors)

/// Example of automating code standards
Class %Studio.Extension.CodeStandards Extends %Studio.SourceControl.ISC
{

/// Indentation
/// Format code based on the surrounding structures.
/// In Object Script code inside braces is indented.
/// In SQL code inside parenthesis is indented.
/// In JavaScript code inside either braces or parenthesis is indented.
Parameter INDENTATION = 1;

/// Code Expansion
/// Many Object Script commands and variables have short alternative syntax.
/// When <PARAMETER>CODEEXPANSION</PARAMETER> is true these will be converted 
/// to use the full text.
Parameter CODEEXPANSION = 1;

/// Object Script Case Conversion
/// <PARAMETER>COSCASE</PARAMETER> controls the case which is used for Object
/// Script functions, commands and special variables.
Parameter COSCASE = "L";

/// Object Script Comment
/// <PARAMETER>COSCOMMENT</PARAMETER> controls the comment style used.
/// Options are ;, //, or #;.
Parameter COSCOMMENT = "//";

/// Object Script White Space
/// When <PARAMETER>COSWHITESPACE</PARAMETER> is true white space will be 
/// inserted either side of operators and after each argument.
Parameter COSWHITESPACE = 1;

/// SQL Case Conversion
/// <PARAMETER>SQLCASE</PARAMETER> controls the case which is used for SQL
/// keywords and operators.
Parameter SQLCASE = "U";

/// Open Whitespace Character
/// Used as first character for lines beginning with white space.
Parameter OPENWHITESPACE = "	";

/// Change Get methods 
/// Objects such as %ResultSet, %CSP.Session, %CSP.Request provide
/// <method>Get</method> methods for backwards compatibility.
/// There is performance gain by using $get(object.Data("...")) instead of object.Get("...")
/// When <parameter>CHANGEGET</parameter> is enabled these constructs are automatically applied.
Parameter CHANGEGET = 0;

/// CHANGEGET functionality is restricted to variable matching this pattern.
Parameter CHANGEGETVARIABLE = "1(1""rs"",1""resultSet"",1""%request"",1""%session"")";

/// Brace Postion
/// Adjust brace usage to end the line with opening brace and start new lines for closing brace.
Parameter BRACEPOSITION = 1;

/// When enabled the system will debug output to current device during execution.
Parameter DEBUG = 0;

Method OnAfterSave(InternalName As %String, Object As %RegisteredObject) As %Status
{
	try {	
		// Execute code standards checks
		set status = ..ParseDocument(InternalName, .Object)
		if $$$ISERR(status) quit 
		
		// Execute source control hook
		set status = ##super(InternalName, .Object) 
		
	} catch ex { 
		set status = ex.AsStatus()
		do $system.OBJ.DisplayError(status)
	} 
	quit status
}

ClassMethod ParseDocument(InternalName As %String, Object As %RegisteredObject) As %Status
{
	set status = $$$OK
	
	set type = ..GetDocumentType(InternalName) 
	set name = $piece(InternalName, ".", 1, $length(InternalName, ".") - 1) 
	
	if type = "class" { 
		quit ..ParseClass(name, 1) 
	} 
	
	if type = "routine" { 
		quit ..ParseRoutine(name, 1) 
	} 
	
	if type = "csp" { 
		quit ..ParseCSP(InternalName, 1) 
	}	
	
	if type = "html" { 
		quit ..ParseHTML(InternalName, 1) 
	}	
	
	quit status
}

/// Helper function to determine document type
ClassMethod GetDocumentType(InternalName As %String) As %String
{
	set extension = $zconvert($piece(InternalName, ".", * ) , "U") 
	quit $case(extension, 
		"CLS":"class", 
		"CSP":"csp", 
		"CSR":"csp", 
		"PRJ":"project", 
		"INC":"routine", 
		"INT":"routine", 
		"MAC":"routine", 
		"BAS":"routine", 
		"JS":"javascript", 
		"CSS":"javascript", 
		"HTML":"html", 
		"HTM":"html", 
		:"other")
}

/// Process all code for a class
ClassMethod ParseClass(ClassName As %String, SaveChanges = 0) As %Status
{
	set classDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(ClassName, , .status) 
	if $$$ISERR(status) quit status
	
	for j = 1:1:classDefinition.Methods.Count() { 
		set methodDefinition = classDefinition.Methods.GetAt(j) 
		
		if methodDefinition.CodeMode = "expression" continue
		if methodDefinition.ClientMethod { 
			do ..ParseStream(methodDefinition.Implementation, methodDefinition.Language, "Method:" _ ClassName _ ":" _ methodDefinition.Name) 
		} else { 
			do ..ParseStream(methodDefinition.Implementation, , "Method:" _ ClassName _ ":" _ methodDefinition.Name) 
		} 
	} 
	for j = 1:1:classDefinition.Queries.Count() { 
		set queryDefinition = classDefinition.Queries.GetAt(j) 
		
		// copy to a stream
		set queryStream = ##class(%Stream.TmpCharacter).%New() 
		do queryStream.Rewind() 
		
		set lineCount = $length(queryDefinition.SqlQuery, $char(13, 10) ) 
		for lineNumber = 1:1:lineCount {
			do queryStream.WriteLine($piece(queryDefinition.SqlQuery, $char(13, 10) , lineNumber) ) 
		} 
		// process the stream
		do ..ParseStream(queryStream, "SQL", "Query:" _ ClassName _ ":" _ queryDefinition.Name) 
		// and copy from stream back to string
		do queryStream.Rewind() 
		set queryString = ""
		while 'queryStream.AtEnd { 
			set line = queryStream.ReadLine() 
			set queryString = queryString _ $select(queryString '= "":$char(13, 10) , 1:"") _ line
		} 
		set queryDefinition.SqlQuery = queryString
	} 
	for j = 1:1:classDefinition.Triggers.Count() { 
		set triggerDefinition = classDefinition.Triggers.GetAt(j) 
		
		// Copy to a stream
		set triggerStream = ##class(%Stream.TmpCharacter).%New() 
		do triggerStream.Rewind() 
		
		set lineCount = $length(triggerDefinition.Code, $char(13, 10)) 
		for lineNumber = 1:1:lineCount {
			do triggerStream.WriteLine($piece(triggerDefinition.Code, $char(13, 10) , lineNumber) ) 
		} 
		// Process the stream
		do ..ParseStream(triggerStream, triggerDefinition.Language, "Trigger:" _ ClassName _ ":" _ triggerDefinition.Name) 
		// and copy from stream back to string
		do triggerStream.Rewind() 
		set triggerString = ""
		while 'triggerStream.AtEnd { 
			set line = triggerStream.ReadLine() 
			set triggerString = triggerString _ $select(triggerString '= "":$char(13, 10) , 1:"") _ line
		} 
		set triggerDefinition.Code = triggerString
	} 
	if SaveChanges { 
		set status = classDefinition.%Save()
		quit status
	} 
	quit $$$OK
}

/// Process a routine
ClassMethod ParseRoutine(RoutineName As %String, SaveChanges = 0) As %Status
{
	set routine = ##class(%Library.Routine).%OpenId(RoutineName, .status) 
	do ..ParseStream(routine, , "Routine:" _ RoutineName) 
	
	if SaveChanges { 
		set status = routine.%Save() 
		quit status
	} 
	quit $$$OK
}

/// Process a CSP file
ClassMethod ParseCSP(CSPName As %String, SaveChanges = 0) As %Status
{
	set cspFilename = $system.CSP.GetFileName(CSPName) 
	if '##class(%File).Exists(cspFilename) quit $$$FileNotFound
	
	set file = ##class(%File).%New(cspFilename) 
	set status = file.Open("RS") 
	if $$$ISERR(status) do $system.OBJ.DisplayError(status) quit status
	
	do file.Close() 
	// copy from file to stream
	set streamout = ##class(%Stream.FileCharacter).%New() 
	set streamout.Filename = cspFilename
	
	// replace the stream was HTML
	do ..ParseStream(streamout, "CSP", "CSP:" _ CSPName) 
	
	if SaveChanges { 
		// write stream back to file
		do streamout.Rewind() 
		set status = streamout.%Save() 
		if $$$ISERR(status) do $system.OBJ.DisplayError(status) quit status
	} 
	
	quit $$$OK
}

/// Process a HTML file
ClassMethod ParseHTML(CSPName As %String, SaveChanges = 0) As %Status
{
	#define FormatHTML(%inputFilename, %outputFilename) "C:\WorkArea\Perforce\Users\nkeast\Utils\Tidy\tidy -asxml -indent -output """ _ %outputFilename _ """ --wrap 0 """ _ %inputFilename _ """"
	
	set cspFilename = $system.CSP.GetFileName(CSPName) 
	if '##class(%File).Exists(cspFilename) quit $$$FileNotFound
	
	set file = ##class(%File).%New(cspFilename) 
	set status = file.Open("RS") 
	if $$$ISERR(status) do $system.OBJ.DisplayError(status) quit status
	do file.Close() 
	
	set outputFilename = ##class(%File).TempFilename("html")
	set logFilename = ##class(%File).TempFilename("log")
	set cmd = $$$FormatHTML(cspFilename, outputFilename)
	set exitStatus = $zf(-1, cmd)
	if exitStatus < 1  { 
		// Show details in output window.
		set logStream = ##class(%Stream.FileCharacter).%New() 
		set logStream.Filename = cspFilename
		do logFilename.OutputToDevice()
		kill logFilename
		quit $$$ERROR($$$UnableToExecuteZF, -100, cmd)
	}	
	
	if SaveChanges { 
		set success = ##class(%File).CopyFile(outputFilename, cspFilename, , .message) 
		if 'success { 
			write !, logFilename
			write !, outputFilename
			write !, message
			quit $$$ERROR($$$FileCanNotCopy, outputFilename, cspFilename)
		} 
	} 
	
	set status = ##class(%File).Delete(outputFilename)
	quit status
}

/// Process a stream
ClassMethod ParseStream(ByRef CodeStream, Language = "COS", Info)
{
	if Language = "" set Language = "COS"
	
	set syntaxStream = ##class(%Stream.TmpCharacter).%New() 
	do syntaxStream.Rewind() 
	
	set syntaxColor = ##class(%SyntaxColor).%New() 
	set flags = "PFCE"
	set returnValue = syntaxColor.Color(CodeStream, .syntaxStream, Language, flags, , , .langs, .syntaxErrors) 
	if 'returnValue { 
		write "Fatal error: ", Info, " ", syntaxColor.DLLResultCode, ! 
		quit
	} 
	if syntaxErrors { 
		write "Syntax error(s): ", Info, !
		quit
	} 
	
	if ..#DEBUG write !, Info
	
	if ..#CODEEXPANSION { 
		// Build local cache of mapped commands
		if '$$$MappedValuesExist do ..InitialiseMap()
	} 
	
	do syntaxStream.Rewind() 
	
	// Each line of syntax stream is broken down into Language, Type, and Fragment.
	// We will keep track of the last, current (this) and next values.
	set (last("Lang"), last("Type"), last("Frag")) = ""
	set (last("NonSpaceLang"), last("NonSpaceType"), last("NonSpaceFrag")) = ""
	set (this("Lang"), this("Type"), this("Frag")) = ""
	set (next("Lang"), next("Type"), next("Frag")) = ""
	// Manipulations are temporarily kept as converted fragment and built up into a converted line of code.
	set (last("Line"), conv("Frag"), conv("Line")) = ""
	set this("Indent") = 0, next("Indent") = 0
	set this("SyntaxStream") = syntaxStream, this("AtEnd") = 0
	set conv("PostConditional") = 0, conv("JSSwitch") = 0, conv("PatternMatch") = 0
	set conv("CodeStream") = CodeStream
	
	set newLineCount = 0, atEnd = 0
	for { 
		// All syntax data processed
		if this("AtEnd") quit
		do ..ReadFragment(.last, .this, .next)
		
		if this("Lang") = "\n" { 
			// Count consecutive new lines
			// if more than 3 (i.e. 2 blank lines in a row) then ignore any subsequent ones
			// seems to add extra blank lines around the 32K mark for large methods - so this stops the proliferation
			set newLineCount = newLineCount + 1
			
			if newLineCount > 3 continue 
			
			do ..ParseLine(.last, .this, .next, .conv)
			continue
			
		} else { 
			// Reset count of consecutive new lines
			set newLineCount = 0
		} 
		
		do ..ParseFragment(.last, .this, .next, .conv)
	}
}

/// Output line to converted stream.
ClassMethod WriteLine(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	do conv("CodeStream").WriteLine(conv("Line")) 
	set last("Line") = conv("Line")
	set conv("Line") = ""
	quit
}

ClassMethod ParseLine(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	if ..#INDENTATION { 
		set multiLineCommand = 0
		
		// Ignore comments
		if '$case(last("Lang"), 
			"COS":$case(last("Type"), $$$COSComment:1, :0), 
			"CSS":$case(last("Type"), $$$CSSCstyleComment:1, :0), 
			"HTML":$case(last("Type"), $$$HTMLComment:1, :0), 
			"JAVASCRIPT":$case(last("Type"), $$$JAVASCRIPTComment:1, :0), 
			"SQL":$case(last("Type"), $$$SQLComment:1, :0), 
			:0) { 
			// Use an extra indent for multi-line commands 
			if last("Lang") = "COS" { 
				set firstChar = $extract(conv("Line"), 2)
				set multiLineCommand = (firstChar '= "") && ($case(last("Lang"), "COS":",_", :",") [ firstChar)
			} elseif last("Lang") = "SQL" { 
				set firstWord = $piece($extract(conv("Line"), 2, *), " ")
				set multiLineCommand = $case(firstWord, "AND":1, "OR":1, :0)
			} 
			if $extract($zstrip(last("Line"), ">W"), *) = "," set multiLineCommand = 1
		} 
		
		if $extract(conv("Line")) = ..#OPENWHITESPACE { 
			// Indentation
			set conv("Frag") = ..#OPENWHITESPACE _ $translate($justify("", this("Indent") + multiLineCommand), $char(32), $char(9))
			if ..#DEBUG write !, this("Indent"), ":", next("Indent"), ":", multiLineCommand, ":", conv("Line")
			set conv("Line") = conv("Frag") _ $extract(conv("Line"), 2, *)
		} else { 
			if ..#DEBUG write !, this("Indent"), ":", next("Indent"), ":", multiLineCommand, ":", conv("Line")
		} 
	} 
	if ..#CHANGEGET { 
		// rs.GetDataByName( -> $Get(rs.Data(
		for method = "Get", "GetDataByName" { 
			set charIndex = $find(conv("Line"), "." _ method _ "(")
			if charIndex { 
				set endIndex = $find(conv("Line"), ")", charIndex)
				set args = $extract(conv("Line"), charIndex, endIndex - 2)
				// Get the object variable
				set var = ""
				for charIndex = charIndex - ($length(method) + 3):-1:0 {
					set varChar=$extract(conv("Line"), charIndex)
					if varChar '? 1(1A,1N,1"%") quit
					set var = varChar _ var
				} 
				if (var ? @..#CHANGEGETVARIABLE) { 
					if endIndex { 
						set conv("Line") = $extract(conv("Line"), 1, charIndex)
							_ $$$MappedValue("COS", $$$COSFunction, "$get")
							_ "(" _ var _ ".Data(" _ args _ "))" _ $extract(conv("Line"), endIndex, *)
					} 
				} 
			} 
		} 
	} 	 

	if ..#INDENTATION { 
		set this("Indent") = this("Indent") + next("Indent")
		set next("Indent") = 0
	} 
	
	do ..WriteLine(.last, .this, .next, .conv)
}

/// newLine is an optional parameter which can be used to insert fragements 
ClassMethod InsertFragment(ByRef last, ByRef this)
{
	set last("Lang") = this("Lang")
	set last("Type") = this("Type")
	set last("Frag") = this("Frag")
	if this("Type") '= $$$COSWhiteSpace { 
		set last("NonSpaceLang") = this("Lang")
		set last("NonSpaceType") = this("Type")
		set last("NonSpaceFrag") = this("Frag")
	}
}

ClassMethod ReadFragment(ByRef last, ByRef this, ByRef next)
{
	set last("Lang") = this("Lang")
	set last("Type") = this("Type")
	set last("Frag") = this("Frag")
	if this("Type") '= $$$COSWhiteSpace { 
		set last("NonSpaceLang") = this("Lang")
		set last("NonSpaceType") = this("Type")
		set last("NonSpaceFrag") = this("Frag")
	} 
	
	set this("Lang") = next("Lang")
	set this("Type") = next("Type")
	set this("Frag") = next("Frag")
	
	if 'this("SyntaxStream").AtEnd { 
		set nextLine = this("SyntaxStream").ReadLine() 
		set next("Lang") = $piece(nextLine, ",", 1) 
		set next("Type") = $piece(nextLine, ",", 2) 
		set next("Frag") = $piece(nextLine, ",", 3, *) 
	} else { 
		set this("AtEnd") = 1
	} 
	
	if ..#DEBUG write !, nextLine
}

ClassMethod ParseFragment(ByRef last, ByRef this, ByRef next, ByRef conv)
{
	// Indentation
	if $case(this("Lang"), 
		"COS":$case(this("Type"), $$$COSWhiteSpace:1, $$$COSComment:1, :0), 
		"CSS":$case(this("Type"), $$$CSSWhiteSpace:1, $$$CSSCstyleComment:1, :0), 
		"HTML":$case(this("Type"), $$$HTMLWhiteSpace:1, $$$HTMLComment:1, :0), 
		"JAVASCRIPT":$case(this("Type"), $$$JAVASCRIPTWhiteSpace:1, $$$JAVASCRIPTComment:1, :0), 
		"SQL":$case(this("Type"), $$$SQLWhiteSpace:1, $$$SQLComment:1, :0), 
		:0)
	&& (conv("Line") = "") { 
		// Whitespace
		if ..#INDENTATION { 
			// Indentation applied with the line
			set conv("Line") = conv("Line") _ ..#OPENWHITESPACE
		} else { 
			set conv("Line") = conv("Line") _ this("Frag")
		} 
		quit
	} 
	
	if this("Lang") = "COS" {		
		if ..#INDENTATION { 
			// Indentation Adjustments
			if (this("Type") = $$$COSBrace) { 
				if "{" = this("Frag")  { 
					set next("Indent") = next("Indent") + 1
				} elseif "}" = this("Frag") { 
					if conv("Line") = ..#OPENWHITESPACE { 
						set this("Indent") = this("Indent") - 1
					} else { 
						set next("Indent") = next("Indent") - 1
					} 
				} 
			}	
		} 
		// ##class
		if this("Type") = $$$COSObjectClass { 
			set conv("Frag") = this("Frag")
			if ..#COSCASE '= "" { 
				set conv("Frag") = $zconvert(conv("Frag"), ..#COSCASE) 
			} 
			set conv("Line") = conv("Line") _ "##class"
			quit
		} 
		// &sql
		if this("Type") = $$$COSSQL { 
			set conv("Frag") = this("Frag")
			if ..#SQLCASE '= "" { 
				set conv("Frag") = $zconvert(conv("Frag"), ..#SQLCASE) 
			} 
			if ..#INDENTATION { 
				if "(" = this("Frag")  { 
					set next("Indent") = next("Indent") + 1
				} elseif ")" = this("Frag") { 
					if conv("Line") = ..#OPENWHITESPACE { 
						set this("Indent") = this("Indent") - 1
					} else { 
						set next("Indent") = next("Indent") - 1
					} 
				} 
			} 
			set conv("Line") = conv("Line") _ conv("Frag") 
			quit
		} 
		// &javascript
		if this("Type") = $$$COSJavascript { 
			set conv("Frag") = this("Frag")
			if ..#CODEEXPANSION { 
				if $zconvert(conv("Frag"), "L") = "js" set conv("Frag") = "javascript"
			} 
			if ..#COSCASE '= "" { 
				set conv("Frag") = $zconvert(conv("Frag"), ..#COSCASE) 
			} 
			if ..#INDENTATION { 
				if "<" = this("Frag")  { 
					set next("Indent") = next("Indent") + 1
				} elseif ">" = this("Frag") { 
					if conv("Line") = ..#OPENWHITESPACE { 
						set this("Indent") = this("Indent") - 1
					} else { 
						set next("Indent") = next("Indent") - 1
					} 
				} 
			} 
			set conv("Line") = conv("Line") _ conv("Frag") 
			quit
		} 
		// &html
		if this("Type") = $$$COSHTML { 
			set conv("Frag") = $zconvert(this("Frag"), "L") 
			set conv("Line") = conv("Line") _ conv("Frag") 
			quit
		} 
		if this("Type") = $$$COSPreProcessorCommand { 
			set conv("Frag") = $zconvert(this("Frag"), "L") 
			set conv("Line") = conv("Line") _ conv("Frag") 
			if ..#INDENTATION { 
				if $case(this("Frag"), "if":1, "ifdef":1, "ifndef":1, :0)  { 
					set next("Indent") = next("Indent") + 1
				} elseif $case(this("Frag"), "else":1, "elseif":1, :0) { 
					set this("Indent") = this("Indent") - 1
					set next("Indent") = next("Indent") + 1
				} elseif $case(this("Frag"), "endif":1, :0) { 
					set this("Indent") = this("Indent") - 1
				} 
			} 
			quit
		} 
		if this("Type") = $$$COSComment { 
			set conv("Frag") = this("Frag")
			
			if ..#COSCOMMENT '= "" { 
				set cosComment = ..#COSCOMMENT
				if (..#COSCOMMENT = "#;") && (last("NonSpaceType") '= "") { 
					// Comment is after the start of the line
					set cosComment = "##;"
				} 
				
				// Convert single line comment style
				// Leave the double semi-colon as this acts differently to other styles.
				// Double semi-colon retains the comment in depolyed output.
				if $extract(this("Frag"), 1) = ";", $extract(this("Frag"), 1, 2) '= ";;" set conv("Frag") = ..#COSCOMMENT _ $extract(conv("Frag"), 2, *) 
				if $extract(this("Frag"), 1, 2) = "#;" set conv("Frag") = ..#COSCOMMENT _ $extract(conv("Frag"), 3, *) 
				if $extract(this("Frag"), 1, 3) = "##;" set conv("Frag") = ..#COSCOMMENT _ $extract(conv("Frag"), 4, *) 
				if ..#COSWHITESPACE { 
					if $extract(conv("Frag"), 1, 2) = "//", $extract(conv("Frag"), 3) '= " " set conv("Frag") = ..#COSCOMMENT _ " " _ $extract(conv("Frag"), 3, *) 
				} 
			} 
			set conv("Line") = conv("Line") _ conv("Frag") 
			quit
		} 
		
		// Function or Command or Special Variables
		if (this("Type") = $$$COSFunction) || (this("Type") = $$$COSCommand) || (this("Type") = $$$COSSystemvariable) { 
			set conv("Frag") = this("Frag")
			
			if (this("Type") = $$$COSCommand) {
				set conv("PostConditional") = 0
			}
			
			if ..#CODEEXPANSION { 
				set conv("Frag") = $get($$$MappedValue(this("Lang"), this("Type"), $zconvert(conv("Frag"), "L")), conv("Frag")) 
			} 
			
			if ..#COSCASE '= "" { 
				// Change case of functions, commands, and special variables
				set conv("Frag") = $zconvert(conv("Frag"), ..#COSCASE) 
			} 
			set conv("Line") = conv("Line") _ conv("Frag")
			quit
		} 
		
		// Operators and Braces
		if (this("Type") = $$$COSOperator) || (this("Type") = $$$COSBrace) { 
			set conv("Frag") = $zconvert(this("Frag"), "L") 
			
			if ..#COSWHITESPACE { 
				// Recognise pattern match operators
				set conv("PatternMatch") = ((conv("Frag") = "?") || (conv("Frag") = "'?"))
				
				// Include whitespace either side of operators except for 
				//  by reference, not, and post conditions.
				// Post conditional expressions can only use spaces inside parenthesis.
				// Pattern match cannot be broken up with spaces.
				if ('conv("PostConditional")) && (".'" '[ conv("Frag")) && (((conv("Frag") '= "+") && (conv("Frag") '= "-")) || $case(last("NonSpaceType"), $$$COSLocalvariable:1, $$$COSNumber:1, :0)) { 
					if $case(last("Type"),$$$COSWhiteSpace:0,"":0,:1) set conv("Frag") = " " _ conv("Frag")
					if $case(next("Type"),$$$COSWhiteSpace:0,"":0,:1) set conv("Frag") = conv("Frag") _ " "
				} 
			} 
			
			if ..#BRACEPOSITION { 
				if (this("Frag") = "}") { 
					
					if (last("NonSpaceLang") '= "\n") { 
						// Note existing values
						set temp("This", "Lang") = this("Lang")
						set temp("This", "Type") = this("Type")
						set temp("This", "Frag") = this("Frag")
						set temp("Conv", "Frag") = conv("Frag")
						
						// Insert new line and opening whitespace
						set this("Lang") = "\n"
						set this("Type") = ""
						set this("Frag") = ""
						do ..InsertFragment(.last, .this)
						do ..ParseLine(.last, .this, .next, .conv)
						
						set this("Lang") = this("Lang")
						set this("Type") = $case(this("Lang"), 
							"COS":$$$COSWhiteSpace, 
							"CSS":$$$CSSWhiteSpace, 
							"HTML":$$$HTMLWhiteSpace, 
							"JAVASCRIPT":$$$JAVASCRIPTWhiteSpace, 
							"SQL":$$$SQLWhiteSpace, 
							:"")
						set this("Frag") = ..#OPENWHITESPACE
						do ..InsertFragment(.last, .this)
						do ..ParseFragment(.last, .this, .next, .conv)
						
						// Restore Frag to be appended to conv("Line")
						// Strip leading white space as the fragment will start on a new line.
						set conv("Frag") = $zstrip(temp("Conv", "Frag"), "<W")
						// Restore this values to reflect sequence
						set this("Lang") = temp("This", "Lang")
						set this("Type") = temp("This", "Type")
						set this("Frag") = temp("This", "Frag")
					} 
				} 
			} 
			
			set conv("Line") = conv("Line") _ conv("Frag") 
			
			if (..#BRACEPOSITION) && (this("Type") = $$$COSBrace) { 
				// Ignore subsequent whitespace 
				set currentWhiteSpace = ""
				while $case(next("Lang"), 
					"COS":next("Type") = $$$COSWhiteSpace, 
					"CSS":next("Type") = $$$CSSWhiteSpace, 
					"HTML":next("Type") = $$$HTMLWhiteSpace, 
					"JAVASCRIPT":next("Type") = $$$JAVASCRIPTWhiteSpace, 
					"SQL":next("Type") = $$$SQLWhiteSpace, 
					:"") {  
					do ..ReadFragment(.last, .this, .next)
					set currentWhiteSpace = currentWhiteSpace _ this("Frag")
				} 
				
				if (next("Lang") '= "\n") 
				&& (next("Frag") '= "else")
				&& (next("Frag") '= "elseif")
				&& (next("Frag") '= "catch")
				&& (next("Frag") '= "while") { 
					// Insert new line and opening whitespace
					set this("Lang") = "\n"
					set this("Type") = ""
					set this("Frag") = ""
					do ..InsertFragment(.last, .this)
					do ..ParseLine(.last, .this, .next, .conv)
					
					set this("Lang") = this("Lang")
					set this("Type") = $case(this("Lang"), 
						"COS":$$$COSWhiteSpace, 
						"CSS":$$$CSSWhiteSpace, 
						"HTML":$$$HTMLWhiteSpace, 
						"JAVASCRIPT":$$$JAVASCRIPTWhiteSpace, 
						"SQL":$$$SQLWhiteSpace, 
						:"")
					set this("Frag") = ..#OPENWHITESPACE
					do ..InsertFragment(.last, .this)
					do ..ParseFragment(.last, .this, .next, .conv)					
				} else { 
					set conv("Line") = conv("Line") _ currentWhiteSpace 
				} 
			} 
			quit
		} 
		// Delimiter
		if this("Type") = $$$COSDelimiter { 
			set conv("Frag") = $zconvert(this("Frag"), "L") 
			
			if ..#COSWHITESPACE { 
				if ('conv("PatternMatch")) && (conv("Frag") = ",") { 
					// Include whitespace before the next parameter.
					if next("Type") '= $$$COSWhiteSpace set conv("Frag") = conv("Frag") _ " "
				}	
				// Post Conditional code may include all types of code.
				// Incorrect spacing will invalidate Post Conditional code.
				// Retain the setting for the rest of the line.
				if 'conv("PostConditional") {
					set conv("PostConditional") = (conv("Frag") = ":")
				}
			} 
			set conv("Line") = conv("Line") _ conv("Frag") 
			quit
		} 
		set conv("Line") = conv("Line") _ this("Frag") 
	} elseif this("Lang") = "SQL" { 
		if ..#INDENTATION { 
			// Indentation Adjustments
			if (this("Type") = $$$SQLDelimiter) { 
				if "(" = this("Frag")  { 
					set next("Indent") = next("Indent") + 1
				} elseif ")" = this("Frag") { 
					if conv("Line") = ..#OPENWHITESPACE { 
						set this("Indent") = this("Indent") - 1
					} else { 
						set next("Indent") = next("Indent") - 1
					} 
				} 
			} 
		} 
		// SQL keywords and operators
		if this("Type") = $$$SQLStatementkeyword || (this("Type") = $$$SQLQualifierkeyword) || (this("Type") = $$$SQLOperator) { 
			if ..#SQLCASE '= "" { 
				// Upper case SQL keywords and operators
				set conv("Frag") = $zconvert(this("Frag"), ..#SQLCASE) 
			} 
			set conv("Line") = conv("Line") _ conv("Frag") 
			quit
		} 
		set conv("Line") = conv("Line") _ this("Frag") 
	} elseif this("Lang") = "JAVASCRIPT" { 
		if ..#INDENTATION { 
			// Indentation Adjustments
			if (this("Type") = $$$JAVASCRIPTDelimiter) { 
				if "{(" [ this("Frag")  { 
					set next("Indent") = next("Indent") + 1
					if conv("JSSwitch") && (this("Frag") = "{") { 
						if $increment(conv("JSSwitch", conv("JSSwitch"), "braceCount"))
					} 
				} elseif "})" [ this("Frag") { 
					set i = 1
					if conv("JSSwitch") && (this("Frag") = "}") { 
						if $increment(conv("JSSwitch", conv("JSSwitch"), "braceCount"), -1)
						if conv("JSSwitch", conv("JSSwitch"), "braceCount") = 0 { 
							set i = 2
							if $increment(conv("JSSwitch"), -1)
						} 
					} 
					if conv("Line") = ..#OPENWHITESPACE { 
						set this("Indent") = this("Indent") - i
					} else { 
						set next("Indent") = next("Indent") - i
					} 
				} 
			} 
		} 
		if (this("Type") = $$$JAVASCRIPTStatementkeyword) { 
			if $case(this("Frag"), "switch":1, :0)  { 
				set next("Indent") = next("Indent") + 1
				if $increment(conv("JSSwitch"))
			} elseif $case(this("Frag"), "case":1, "default":1, :0) { 
				set this("Indent") = this("Indent") - 1
				set next("Indent") = next("Indent") + 1
			} 
		} 
		set conv("Line") = conv("Line") _ this("Frag") 
	} elseif this("Lang") = "HTML" { 
		// <head></head>
		// <csp:parameter> 
		if this("Type") = $$$HTMLTag { 
			set conv("Frag") = $zconvert(this("Frag"), "L") 
			if ..#CODEEXPANSION { 
				// Convert <server> to <script language="cache" runat="server">
				if conv("Frag") = "server" { 
					set conv("Frag") = "script"
					if last("Type") = $$$HTMLDelimiter, last("Frag") '= "/" set conv("Frag") = conv("Frag") _ " language=""cache"" runat=""server"""
				} 
			} 
			set conv("Line") = conv("Line") _ conv("Frag") 
			quit
		} 
		set conv("Line") = conv("Line") _ this("Frag") 
	} else { 
		set conv("Line") = conv("Line") _ this("Frag")
	}
}

ClassMethod InitialiseMap()
{
	set $$$MappedValue("COS", $$$COSFunction, "$a") = "$ascii"
	set $$$MappedValue("COS", $$$COSFunction, "$ascii") = "$ascii"
	set $$$MappedValue("COS", $$$COSFunction, "$bit") = "$bit"
	set $$$MappedValue("COS", $$$COSFunction, "$bitcount") = "$bitcount"
	set $$$MappedValue("COS", $$$COSFunction, "$bitfind") = "$bitfind"
	set $$$MappedValue("COS", $$$COSFunction, "$bitlogic") = "$bitlogic"
	set $$$MappedValue("COS", $$$COSFunction, "$case") = "$case"
	set $$$MappedValue("COS", $$$COSFunction, "$c") = "$char"
	set $$$MappedValue("COS", $$$COSFunction, "$char") = "$char"
	set $$$MappedValue("COS", $$$COSFunction, "$classmethod") = "$classmethod"
	set $$$MappedValue("COS", $$$COSFunction, "$classname") = "$classname"
	set $$$MappedValue("COS", $$$COSFunction, "$d") = "$data"
	set $$$MappedValue("COS", $$$COSFunction, "$data") = "$data"
	set $$$MappedValue("COS", $$$COSFunction, "$decimal") = "$decimal"
	set $$$MappedValue("COS", $$$COSFunction, "$double") = "$double"
	set $$$MappedValue("COS", $$$COSFunction, "$e") = "$extract"
	set $$$MappedValue("COS", $$$COSFunction, "$extract") = "$extract"
	set $$$MappedValue("COS", $$$COSFunction, "$f") = "$find"
	set $$$MappedValue("COS", $$$COSFunction, "$find") = "$find"
	set $$$MappedValue("COS", $$$COSFunction, "$fn") = "$fnumber"
	set $$$MappedValue("COS", $$$COSFunction, "$fnumber") = "$fnumber"
	set $$$MappedValue("COS", $$$COSFunction, "$g") = "$get"
	set $$$MappedValue("COS", $$$COSFunction, "$get") = "$get"
	set $$$MappedValue("COS", $$$COSFunction, "$i") = "$increment"
	set $$$MappedValue("COS", $$$COSFunction, "$increment") = "$increment"
	set $$$MappedValue("COS", $$$COSFunction, "$isobject") = "$isobject"
	set $$$MappedValue("COS", $$$COSFunction, "$isvalidnum") = "$isvalidnum"
	set $$$MappedValue("COS", $$$COSFunction, "$j") = "$justify"
	set $$$MappedValue("COS", $$$COSFunction, "$justify") = "$justify"
	set $$$MappedValue("COS", $$$COSFunction, "$lb") = "$listbuild"
	set $$$MappedValue("COS", $$$COSFunction, "$ld") = "$listdata"
	set $$$MappedValue("COS", $$$COSFunction, "$l") = "$length"
	set $$$MappedValue("COS", $$$COSFunction, "$length") = "$length"
	set $$$MappedValue("COS", $$$COSFunction, "$lf") = "$listfind"
	set $$$MappedValue("COS", $$$COSFunction, "$lfs") = "$listfromstring"
	set $$$MappedValue("COS", $$$COSFunction, "$lg") = "$listget"
	set $$$MappedValue("COS", $$$COSFunction, "$li") = "$list"
	set $$$MappedValue("COS", $$$COSFunction, "$list") = "$list"
	set $$$MappedValue("COS", $$$COSFunction, "$listbuild") = "$listbuild"
	set $$$MappedValue("COS", $$$COSFunction, "$listdata") = "$listdata"
	set $$$MappedValue("COS", $$$COSFunction, "$listfind") = "$listfind"
	set $$$MappedValue("COS", $$$COSFunction, "$listfromstring") = "$listfromstring"
	set $$$MappedValue("COS", $$$COSFunction, "$listget") = "$listget"
	set $$$MappedValue("COS", $$$COSFunction, "$ll") = "$listlength"
	set $$$MappedValue("COS", $$$COSFunction, "$listlength") = "$listlength"
	set $$$MappedValue("COS", $$$COSFunction, "$listnext") = "$listnext"
	set $$$MappedValue("COS", $$$COSFunction, "$listsame") = "$listsame"
	set $$$MappedValue("COS", $$$COSFunction, "$listtostring") = "$listtostring"
	set $$$MappedValue("COS", $$$COSFunction, "$listvalid") = "$listvalid"
	set $$$MappedValue("COS", $$$COSFunction, "$locate") = "$locate"
	set $$$MappedValue("COS", $$$COSFunction, "$lts") = "$listtostring"
	set $$$MappedValue("COS", $$$COSFunction, "$lv") = "$listvalid"
	set $$$MappedValue("COS", $$$COSFunction, "$match") = "$match"
	set $$$MappedValue("COS", $$$COSFunction, "$method") = "$method"
	set $$$MappedValue("COS", $$$COSFunction, "$na") = "$name"
	set $$$MappedValue("COS", $$$COSFunction, "$name") = "$name"
	set $$$MappedValue("COS", $$$COSFunction, "$nconvert") = "$nconvert"
	set $$$MappedValue("COS", $$$COSFunction, "$normalize") = "$normalize"
	set $$$MappedValue("COS", $$$COSFunction, "$now") = "$now"
	set $$$MappedValue("COS", $$$COSFunction, "$number") = "$num"
	set $$$MappedValue("COS", $$$COSFunction, "$number") = "$number"
	set $$$MappedValue("COS", $$$COSFunction, "$o") = "$order"
	set $$$MappedValue("COS", $$$COSFunction, "$order") = "$order"
	set $$$MappedValue("COS", $$$COSFunction, "$parameter") = "$parameter"
	set $$$MappedValue("COS", $$$COSFunction, "$p") = "$piece"
	set $$$MappedValue("COS", $$$COSFunction, "$piece") = "$piece"
	set $$$MappedValue("COS", $$$COSFunction, "$property") = "$property"
	set $$$MappedValue("COS", $$$COSFunction, "$q") = "$query"
	set $$$MappedValue("COS", $$$COSFunction, "$ql") = "$qlength"
	set $$$MappedValue("COS", $$$COSFunction, "$qlength") = "$qlength"
	set $$$MappedValue("COS", $$$COSFunction, "$qs") = "$qsubscript"
	set $$$MappedValue("COS", $$$COSFunction, "$qsubscript") = "$qsubscript"
	set $$$MappedValue("COS", $$$COSFunction, "$query") = "$query"
	set $$$MappedValue("COS", $$$COSFunction, "$r") = "$random"
	set $$$MappedValue("COS", $$$COSFunction, "$random") = "$random"
	set $$$MappedValue("COS", $$$COSFunction, "$re") = "$reverse"
	set $$$MappedValue("COS", $$$COSFunction, "$replace") = "$replace"
	set $$$MappedValue("COS", $$$COSFunction, "$reverse") = "$reverse"
	set $$$MappedValue("COS", $$$COSFunction, "$sconvert") = "$sconvert"
	set $$$MappedValue("COS", $$$COSFunction, "$s") = "$select"
	set $$$MappedValue("COS", $$$COSFunction, "$select") = "$select"
	set $$$MappedValue("COS", $$$COSFunction, "$sortbegin") = "$sortbegin"
	set $$$MappedValue("COS", $$$COSFunction, "$sortend") = "$sortend"
	set $$$MappedValue("COS", $$$COSFunction, "$stack") = "$stack"
	set $$$MappedValue("COS", $$$COSFunction, "$t") = "$text"
	set $$$MappedValue("COS", $$$COSFunction, "$text") = "$text"
	set $$$MappedValue("COS", $$$COSFunction, "$tr") = "$translate"
	set $$$MappedValue("COS", $$$COSFunction, "$translate") = "$translate"
	set $$$MappedValue("COS", $$$COSFunction, "$xecute") = "$xecute"
	set $$$MappedValue("COS", $$$COSFunction, "$zabs") = "$zabs"
	set $$$MappedValue("COS", $$$COSFunction, "$zb") = "$zboolean"
	set $$$MappedValue("COS", $$$COSFunction, "$zbitget") = "$zbitget"
	set $$$MappedValue("COS", $$$COSFunction, "$zbitlen") = "$zbitlen"
	set $$$MappedValue("COS", $$$COSFunction, "$zbitor") = "$zbitor"
	set $$$MappedValue("COS", $$$COSFunction, "$zbitset") = "$zbitset"
	set $$$MappedValue("COS", $$$COSFunction, "$zbitstr") = "$zbitstr"
	set $$$MappedValue("COS", $$$COSFunction, "$zboolean") = "$zboolean"
	set $$$MappedValue("COS", $$$COSFunction, "$zconvert") = "$zconvert"
	set $$$MappedValue("COS", $$$COSFunction, "$zcrc") = "$zcrc"
	set $$$MappedValue("COS", $$$COSFunction, "$zcvt") = "$zconvert"
	set $$$MappedValue("COS", $$$COSFunction, "$zconvert") = "$zconvert"
	set $$$MappedValue("COS", $$$COSFunction, "$zd") = "$zdate"
	set $$$MappedValue("COS", $$$COSFunction, "$zdate") = "$zdate"
	set $$$MappedValue("COS", $$$COSFunction, "$zdateh") = "$zdateh"
	set $$$MappedValue("COS", $$$COSFunction, "$zdatetime") = "$zdatetime"
	set $$$MappedValue("COS", $$$COSFunction, "$zdatetimeh") = "$zdatetimeh"
	set $$$MappedValue("COS", $$$COSFunction, "$zdh") = "$zdateh"
	set $$$MappedValue("COS", $$$COSFunction, "$zdt") = "$zdatetime"
	set $$$MappedValue("COS", $$$COSFunction, "$zdth") = "$zdatetimeh"
	set $$$MappedValue("COS", $$$COSFunction, "$zf") = "$zf"
	set $$$MappedValue("COS", $$$COSFunction, "$zh") = "$zhex"
	set $$$MappedValue("COS", $$$COSFunction, "$zhex") = "$zhex"
	set $$$MappedValue("COS", $$$COSFunction, "$ziswide") = "$ziswide"
	set $$$MappedValue("COS", $$$COSFunction, "$zlascii") = "$zlascii"
	set $$$MappedValue("COS", $$$COSFunction, "$zlc") = "$zlc"
	set $$$MappedValue("COS", $$$COSFunction, "$zlchar") = "$zlchar"
	set $$$MappedValue("COS", $$$COSFunction, "$zlog") = "$zlog"
	set $$$MappedValue("COS", $$$COSFunction, "$zname") = "$zname"
	set $$$MappedValue("COS", $$$COSFunction, "$zo") = "$zorder"
	set $$$MappedValue("COS", $$$COSFunction, "$zobjclass") = "$classname"
	set $$$MappedValue("COS", $$$COSFunction, "$zobjclassmethod") = "$classmethod"
	set $$$MappedValue("COS", $$$COSFunction, "$zobjexport") = "$zobjexport"
	set $$$MappedValue("COS", $$$COSFunction, "$zobjmethod") = "$method"
	set $$$MappedValue("COS", $$$COSFunction, "$zobjproperty") = "$property"
	set $$$MappedValue("COS", $$$COSFunction, "$zobjval") = "$zobjval"
	set $$$MappedValue("COS", $$$COSFunction, "$zpower") = "$zpower"
	set $$$MappedValue("COS", $$$COSFunction, "$zse") = "$zsearch"
	set $$$MappedValue("COS", $$$COSFunction, "$zsearch") = "$zsearch"
	set $$$MappedValue("COS", $$$COSFunction, "$zstrip") = "$zstrip"
	set $$$MappedValue("COS", $$$COSFunction, "$zt") = "$ztime"
	set $$$MappedValue("COS", $$$COSFunction, "$zth") = "$ztimeh"
	set $$$MappedValue("COS", $$$COSFunction, "$ztime") = "$ztime"
	set $$$MappedValue("COS", $$$COSFunction, "$ztimeh") = "$ztimeh"
	set $$$MappedValue("COS", $$$COSFunction, "$zu") = "$zutil"
	set $$$MappedValue("COS", $$$COSFunction, "$zutil") = "$zutil"
	set $$$MappedValue("COS", $$$COSFunction, "$zv") = "$zversion"
	set $$$MappedValue("COS", $$$COSFunction, "$zversion") = "$zversion"
	set $$$MappedValue("COS", $$$COSFunction, "$zwascii") = "$zwascii"
	set $$$MappedValue("COS", $$$COSFunction, "$zwc") = "$zwchar"
	set $$$MappedValue("COS", $$$COSFunction, "$zwchar") = "$zwchar"
	
	set $$$MappedValue("COS", $$$COSCommand, "as") = "as"
	set $$$MappedValue("COS", $$$COSCommand, "b") = "break"
	set $$$MappedValue("COS", $$$COSCommand, "break") = "break"
	set $$$MappedValue("COS", $$$COSCommand, "catch") = "catch"
	set $$$MappedValue("COS", $$$COSCommand, "c") = "close"
	set $$$MappedValue("COS", $$$COSCommand, "close") = "close"
	set $$$MappedValue("COS", $$$COSCommand, "continue") = "continue"
	set $$$MappedValue("COS", $$$COSCommand, "d") = "do"
	set $$$MappedValue("COS", $$$COSCommand, "do") = "do"
	set $$$MappedValue("COS", $$$COSCommand, "e") = "else"
	set $$$MappedValue("COS", $$$COSCommand, "else") = "else"
	set $$$MappedValue("COS", $$$COSCommand, "elseif") = "elseif"
	set $$$MappedValue("COS", $$$COSCommand, "f") = "for"
	set $$$MappedValue("COS", $$$COSCommand, "for") = "for"
	set $$$MappedValue("COS", $$$COSCommand, "g") = "goto"
	set $$$MappedValue("COS", $$$COSCommand, "goto") = "goto"
	// leave H as is (due to HANG x   versus HALT)
	set $$$MappedValue("COS", $$$COSCommand, "h") = "h"
	set $$$MappedValue("COS", $$$COSCommand, "hang") = "hang"
	set $$$MappedValue("COS", $$$COSCommand, "i") = "if"
	set $$$MappedValue("COS", $$$COSCommand, "if") = "if"
	set $$$MappedValue("COS", $$$COSCommand, "j") = "job"
	set $$$MappedValue("COS", $$$COSCommand, "job") = "job"
	set $$$MappedValue("COS", $$$COSCommand, "k") = "kill"
	set $$$MappedValue("COS", $$$COSCommand, "kill") = "kill"
	set $$$MappedValue("COS", $$$COSCommand, "l") = "lock"
	set $$$MappedValue("COS", $$$COSCommand, "lock") = "lock"
	set $$$MappedValue("COS", $$$COSCommand, "m") = "merge"
	set $$$MappedValue("COS", $$$COSCommand, "merge") = "merge"
	set $$$MappedValue("COS", $$$COSCommand, "n") = "new"
	set $$$MappedValue("COS", $$$COSCommand, "new") = "new"
	set $$$MappedValue("COS", $$$COSCommand, "o") = "open"
	set $$$MappedValue("COS", $$$COSCommand, "open") = "open"
	set $$$MappedValue("COS", $$$COSCommand, "p") = "print"
	set $$$MappedValue("COS", $$$COSCommand, "print") = "print"
	set $$$MappedValue("COS", $$$COSCommand, "q") = "quit"
	set $$$MappedValue("COS", $$$COSCommand, "quit") = "quit"
	set $$$MappedValue("COS", $$$COSCommand, "r") = "read"
	set $$$MappedValue("COS", $$$COSCommand, "read") = "read"
	set $$$MappedValue("COS", $$$COSCommand, "ret") = "ret"
	set $$$MappedValue("COS", $$$COSCommand, "return") = "return"
	set $$$MappedValue("COS", $$$COSCommand, "s") = "set"
	set $$$MappedValue("COS", $$$COSCommand, "set") = "set"
	set $$$MappedValue("COS", $$$COSCommand, "tc") = "tcommit"
	set $$$MappedValue("COS", $$$COSCommand, "tcommit") = "tcommit"
	set $$$MappedValue("COS", $$$COSCommand, "throw") = "throw"
	set $$$MappedValue("COS", $$$COSCommand, "trollback") = "trollback"
	set $$$MappedValue("COS", $$$COSCommand, "try") = "try"
	set $$$MappedValue("COS", $$$COSCommand, "ts") = "tstart"
	set $$$MappedValue("COS", $$$COSCommand, "tstart") = "tstart"
	set $$$MappedValue("COS", $$$COSCommand, "u") = "use"
	set $$$MappedValue("COS", $$$COSCommand, "use") = "use"
	set $$$MappedValue("COS", $$$COSCommand, "v") = "view"
	set $$$MappedValue("COS", $$$COSCommand, "view") = "view"
	set $$$MappedValue("COS", $$$COSCommand, "while") = "while"
	set $$$MappedValue("COS", $$$COSCommand, "w") = "write"
	set $$$MappedValue("COS", $$$COSCommand, "write") = "write"
	set $$$MappedValue("COS", $$$COSCommand, "x") = "xecute"
	set $$$MappedValue("COS", $$$COSCommand, "xecute") = "xecute"
	set $$$MappedValue("COS", $$$COSCommand, "za") = "zallocate"
	set $$$MappedValue("COS", $$$COSCommand, "zbreak") = "zbreak"
	set $$$MappedValue("COS", $$$COSCommand, "zd") = "zdeallocate"
	set $$$MappedValue("COS", $$$COSCommand, "zkill") = "zkill"
	set $$$MappedValue("COS", $$$COSCommand, "zn") = "znspace"
	set $$$MappedValue("COS", $$$COSCommand, "znspace") = "znspace"
	set $$$MappedValue("COS", $$$COSCommand, "zt") = "ztrap"
	set $$$MappedValue("COS", $$$COSCommand, "ztrap") = "ztrap"
	set $$$MappedValue("COS", $$$COSCommand, "zw") = "zwrite"
	set $$$MappedValue("COS", $$$COSCommand, "zwrite") = "zwrite"
	
	set $$$MappedValue("COS", $$$COSSystemvariable, "$j") = "$job"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$job") = "$job"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$ec") = "$ec"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$ecode") = "$ecode"
	
	// leave as $h...
	set $$$MappedValue("COS", $$$COSSystemvariable, "$h") = "$h"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$horolog") = "$h"
	
	set $$$MappedValue("COS", $$$COSSystemvariable, "$i") = "$io"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$io") = "$io"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$j") = "$job"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$job") = "$job"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$k") = "$key"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$key") = "$key"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$ns") = "$namespace"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$namespace") = "$namespace"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$principal") = "$principal"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$roles") = "$roles"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$s") = "$storage"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$storage") = "$storage"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$stack") = "$stack"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$system") = "$system"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$t") = "$test"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$test") = "$test"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$this") = "$this"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$tl") = "$tlevel"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$tlevel") = "$tlevel"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$username") = "$username"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$x") = "$x"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zb") = "$zb"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zc") = "$zc"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zchild") = "$zchild"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$ze") = "$zerror"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zeof") = "$zeof"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zerror") = "$zerror"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zh") = "$zhorolog"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zhorolog") = "$zhorolog"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zj") = "$zjob"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zjob") = "$zjob"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zn") = "$zname"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zname") = "$zname"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$znspace") = "$znspace"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zparent") = "$zparent"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zpi") = "$zpi"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zr") = "$zreference"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zr") = "$zreference"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zs") = "$zstorage"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zs") = "$zstorage"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zt") = "$ztrap"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zts") = "$ztimestamp"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$ztimestamp") = "$ztimestamp"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$ztz") = "$ztimezone"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$ztimezone") = "$ztimezone"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$ztrap") = "$ztrap"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zv") = "$zversion"
	set $$$MappedValue("COS", $$$COSSystemvariable, "$zversion") = "$zversion"
}

}