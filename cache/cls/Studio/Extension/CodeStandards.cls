Include (Studio.Extension.CodeStandards, %occErrors)

/// Example of automating code standards
Class Studio.Extension.CodeStandards Extends Studio.SourceControl.GIT
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

/// When enabled the system will debug output to current device during execution.
Parameter DEBUG = 0;

Method OnAfterSave(InternalName As %String, Object As %RegisteredObject) As %Status
{
	// Execute source control hook
	set status = ##super(InternalName, .Object) 
	if $$$ISERR(status) quit status
	
	// Execute code standards checks
	set status = ..ParseDocument(InternalName, .Object) 
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
	set (lastLang, lastType, lastFrag) = ""
	set (lastNonSpaceLang, lastNonSpaceType, lastNonSpaceFrag) = ""
	set (thisLang, thisType, thisFrag) = ""
	set (nextLang, nextType, nextFrag) = ""
	// Manipulations are temporarily kept as converted fragment and built up into a converted line of code.
	set (lastLine, convFrag, convLine) = ""
	set newLineCount = 0, thisIndent = 0, nextIndent = 0, postConditional = 0, atEnd = 0, jsInSwitch = 0
	
	for {
		// All syntax data processed
		if atEnd quit
		
		set lastLang = thisLang
		set lastType = thisType
		set lastFrag = thisFrag
		if thisType '= $$$COSWhiteSpace {
			set lastNonSpaceLang = thisLang
			set lastNonSpaceType = thisType
			set lastNonSpaceFrag = thisFrag
		}
		
		set thisLang = nextLang
		set thisType = nextType
		set thisFrag = nextFrag
		
		if 'syntaxStream.AtEnd {
			set nextLine = syntaxStream.ReadLine() 
			set nextLang = $piece(nextLine, ",", 1) 
			set nextType = $piece(nextLine, ",", 2) 
			set nextFrag = $piece(nextLine, ",", 3, *) 
		} else {
			set atEnd = 1
		}
		
		if ..#DEBUG write !, nextLine
		
		if thisLang = "\n" {
			// Count consecutive new lines
			// if more than 3 (i.e. 2 blank lines in a row) then ignore any subsequent ones
			// seems to add extra blank lines around the 32K mark for large methods - so this stops the proliferation
			set newLineCount = newLineCount + 1
			if newLineCount < 4 {
				
				if ..#INDENTATION {
					// Use an extra indent for multi-line commands 
					set firstChar = $extract(convLine,2)
					set multiLineCommand = (firstChar '= "") && ($case(lastLang, "COS":",_", :",") [ firstChar)
					if $extract($zstrip(lastLine,">W"),*) = "," set multiLineCommand = 1
					
					if $extract(convLine) = $char(32) {
						// Indentation
						set convFrag = $char(32) _ $translate($justify("", thisIndent + multiLineCommand), $char(32), $char(9))
						if ..#DEBUG write !,thisIndent,":",nextIndent,":",multiLineCommand,":",convLine
						set convLine = convFrag _ $extract(convLine, 2, *)
					} else {
						if ..#DEBUG write !,thisIndent,":",nextIndent,":",multiLineCommand,":",convLine
					}
				}
				do CodeStream.WriteLine(convLine) 
			}
			
			if ..#INDENTATION {
				set thisIndent = thisIndent + nextIndent
				set nextIndent = 0
			}
			
			set lastLine = convLine
			set convLine = ""
			continue
		} else {
			// Reset count of consecutive new lines
			set newLineCount = 0
		}
		
		// Indentation
		// NOTE: All languages use the same type value for whitespace(1).
		if (thisType = $$$COSWhiteSpace) && (convLine = "") {
			// Whitespace
			if ..#INDENTATION {
				// Indentation applied with the line
				set convLine = convLine _ $char(32)
			} else {
				set convLine = convLine _ thisFrag
			}
			continue
		}
				
		if thisLang = "COS" {		
			if ..#INDENTATION {
				// Indentation Adjustments
				if (thisType = $$$COSBrace) {
					if "{" = thisFrag  {
						set nextIndent = nextIndent + 1
					} elseif "}" = thisFrag {
						if convLine = $char(32) {
							set thisIndent = thisIndent - 1
						} else {
							set nextIndent = nextIndent - 1
						}
					}
				}	
			}
			// ##class
			if thisType = $$$COSObjectClass {
				set convFrag = thisFrag
				if ..#COSCASE '= "" {
					set convFrag = $zconvert(convFrag, ..#COSCASE) 
				}
				set convLine = convLine _ "##class"
				continue
			}
			// &sql
			if thisType = $$$COSSQL {
				set convFrag = thisFrag
				if ..#SQLCASE '= "" {
					set convFrag = $zconvert(convFrag, ..#SQLCASE) 
				}
				set convLine = convLine _ convFrag 
				if ..#INDENTATION {
					if "(" = thisFrag  {
						set nextIndent = nextIndent + 1
					} elseif ")" = thisFrag {
						if convLine = $char(32) {
							set thisIndent = thisIndent - 1
						} else {
							set nextIndent = nextIndent - 1
						}
					}
				}
				continue
			}
			// &javascript
			if thisType = $$$COSJavascript {
				set convFrag = thisFrag
				if ..#CODEEXPANSION {
					if $zconvert(convFrag, "L") = "js" set convFrag = "javascript"
				}
				if ..#COSCASE '= "" {
					set convFrag = $zconvert(convFrag, ..#COSCASE) 
				}
				set convLine = convLine _ convFrag 
				if ..#INDENTATION {
					if "<" = thisFrag  {
						set nextIndent = nextIndent + 1
					} elseif ">" = thisFrag {
						if convLine = $char(32) {
							set thisIndent = thisIndent - 1
						} else {
							set nextIndent = nextIndent - 1
						}
					}
				}
				continue
			}
			// &html
			if thisType = $$$COSHTML {
				set convFrag = $zconvert(thisFrag, "L") 
				set convLine = convLine _ convFrag 
				continue
			}
			if thisType = $$$COSPreProcessorCommand {
				set convFrag = $zconvert(thisFrag, "L") 
				set convLine = convLine _ convFrag 
				if ..#INDENTATION {
					if $case(thisFrag,"if":1,"ifdef":1,"ifndef":1,:0)  {
						set nextIndent = nextIndent + 1
					} elseif $case(thisFrag,"else":1,"elseif":1,:0) {
						set thisIndent = thisIndent - 1
						set nextIndent = nextIndent + 1
					} elseif $case(thisFrag,"endif":1,:0) {
						set thisIndent = thisIndent - 1
					}
				}
				continue
			}
			if thisType = $$$COSComment {
				set convFrag = thisFrag
				
				if ..#COSCOMMENT '= "" {
					set cosComment = ..#COSCOMMENT
					if (..#COSCOMMENT = "#;") && (lastNonSpaceType '= "") {
						// Comment is after the start of the line
						set cosComment = "##;"
					}
					
					// Convert single line comment style
					// Leave the double semi-colon as this acts differently to other styles.
					// Double semi-colon retains the comment in depolyed output.
					if $extract(thisFrag, 1) = ";", $extract(thisFrag, 1, 2) '= ";;" set convFrag = ..#COSCOMMENT _ $extract(thisFrag, 2, * ) 
					if $extract(thisFrag, 1, 2) = "#;" set convFrag = ..#COSCOMMENT _ $extract(thisFrag, 3, * ) 
					if $extract(thisFrag, 1, 3) = "##;" set convFrag = ..#COSCOMMENT _ $extract(thisFrag, 4, * ) 
					if ..#COSWHITESPACE {
						if $extract(convFrag, 1, 2) = "//", $extract(convFrag, 3) '= " " set convFrag = ..#COSCOMMENT _ " " _ $extract(thisFrag, 3, * ) 
					}
				}
				set convLine = convLine _ convFrag 
				continue
			}
			// Function or Command or Special Variables
			if (thisType = $$$COSFunction) || (thisType = $$$COSCommand) || (thisType = $$$COSSystemvariable) {
				set convFrag = thisFrag
				
				if ..#CODEEXPANSION {
					set convFrag = $get($$$MappedValue(thisLang, thisType, $zconvert(convFrag, "L")), convFrag) 
				}
				
				if ..#COSCASE '= "" {
					// Change case of functions, commands, and special variables
					set convFrag = $zconvert(convFrag, ..#COSCASE) 
				}
				set convLine = convLine _ convFrag
				continue
			}
			// Operator
			if thisType = $$$COSOperator {
				set convFrag = $zconvert(thisFrag, "L") 
				
				if ..#COSWHITESPACE {
					// Include whitespace either side of operators except for 
					//  by reference, not, and post conditions.
					// Post conditional expressions can only use spaces inside parenthesis.
					if ('postConditional) && (".'" '[ convFrag) && ((convFrag '= "+") || $case(lastNonSpaceType,$$$COSLocalvariable:1,$$$COSNumber:1,:0)) {
						if lastType '= $$$COSWhiteSpace set convFrag = " " _ convFrag
						if nextType '= $$$COSWhiteSpace set convFrag = convFrag _ " "
					}
				}
				set convLine = convLine _ convFrag 
				continue
			}
			// Delimiter
			if thisType = $$$COSDelimiter {
				set convFrag = $zconvert(thisFrag, "L") 
				
				if ..#COSWHITESPACE {
					if convFrag = "," {
						// Include whitespace before the next parameter.
						if nextType '= $$$COSWhiteSpace set convFrag = convFrag _ " "
					}	
					set postConditional = (convFrag = ":")
				}
				set convLine = convLine _ convFrag 
				continue
			}
			set convLine = convLine _ thisFrag 
		} elseif thisLang = "SQL" {
			if ..#INDENTATION {
				// Indentation Adjustments
				if (thisType = $$$SQLDelimiter) {
					if "(" = thisFrag  {
						set nextIndent = nextIndent + 1
					} elseif ")" = thisFrag {
						if convLine = $char(32) {
							set thisIndent = thisIndent - 1
						} else {
							set nextIndent = nextIndent - 1
						}
					}
				}
			}
			// SQL keywords and operators
			if thisType = $$$SQLStatementkeyword || (thisType = $$$SQLQualifierkeyword) || (thisType = $$$SQLOperator) {
				if ..#SQLCASE '= "" {
					// Upper case SQL keywords and operators
					set convFrag = $zconvert(thisFrag, ..#SQLCASE) 
				}
				set convLine = convLine _ convFrag 
				continue
			} 
			set convLine = convLine _ thisFrag 
		} elseif thisLang = "JAVASCRIPT" {
			if ..#INDENTATION {
				// Indentation Adjustments
				if (thisType = $$$JAVASCRIPTDelimiter) {
					if "{(" [ thisFrag  {
						set nextIndent = nextIndent + 1
						if jsInSwitch && (thisFrag = "{") {
							if $increment(jsInSwitch(jsInSwitch,"braceCount"))
						}
					} elseif "})" [ thisFrag {
						set i = 1
						if jsInSwitch && (thisFrag = "}") {
							if $increment(jsInSwitch(jsInSwitch,"braceCount"),-1)
							if jsInSwitch(jsInSwitch,"braceCount") = 0 {
								set i = 2
								if $increment(jsInSwitch,-1)
							}
						}
						if convLine = $char(32) {
							set thisIndent = thisIndent - i
						} else {
							set nextIndent = nextIndent - i
						}
					}
				}
			}
			if (thisType = $$$JAVASCRIPTStatementkeyword) {
				if $case(thisFrag,"switch":1,:0)  {
					set nextIndent = nextIndent + 1
					if $increment(jsInSwitch)
				} elseif $case(thisFrag,"case":1,"default":1,:0) {
					set thisIndent = thisIndent - 1
					set nextIndent = nextIndent + 1
				}
			}
			set convLine = convLine _ thisFrag 
		} elseif thisLang = "HTML" {
			// <head></head>
			// <csp:parameter> 
			if thisType = $$$HTMLTag {
				set convFrag = $zconvert(thisFrag, "L") 
				if ..#CODEEXPANSION {
					// Convert <server> to <script language="cache" runat="server">
					if convFrag = "server" {
						set convFrag = "script"
						if lastType = $$$HTMLDelimiter, lastFrag '= "/" set convFrag = convFrag _ " language=""cache"" runat=""server"""
					}
				}
				set convLine = convLine _ convFrag 
				continue
			}
			set convLine = convLine _ thisFrag 
		} else {
			set convLine = convLine _ thisFrag
		}
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

