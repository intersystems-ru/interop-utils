Class UnitTest.iscru.util.StreamUtils.TestStreamLike Extends %UnitTest.TestCase
{

/// Name of the persistent class for testing streamLike stored procedure
Parameter TEMPCLASSNAME = {..%ClassName(1) _ ".TempClass"};

Method OnBeforeAllTests() As %Status
{
	do ..dropTempClass(..#TEMPCLASSNAME)
	
	// create and compile a persistent class with just one stream property
	quit ..createTempClass(..#TEMPCLASSNAME)
}

Method OnAfterAllTests() As %Status
{
	quit ..dropTempClass(..#TEMPCLASSNAME)
}

Method TestWithoutPPGCache()
{
	do ..internal($$$NO, $$$NO)
}

Method TestWithPPGCache()
{
	do ..internal($$$YES, $$$NO)
}

Method TestStoredProcWithoutPPGCache()
{
	do ..internal($$$NO, $$$YES)
}

Method TestStoredProcWithPPGCache()
{
	do ..internal($$$YES, $$$YES)
}

Method internal(cacheToPPG As %Boolean, testStoredProc As %Boolean) [ Private ]
{
	if testStoredProc && '$$$comClassDefined(..#TEMPCLASSNAME)
	{
		$$$ThrowStatus($$$ERROR($$$GeneralError, "Persistent class " _ ..#TEMPCLASSNAME _ " not compiled"))
	}
	
	// populate temp global, assuming each node has a list of items:
	//   edgesStr*, stuffingStringCount*, pattern, escape char, case insensitive flag, expected result
	// * - edgesStr and stuffingStringCount are arguments for ..createStream() method
	#dim globalName As %String = ..populateGlobal()

	// loop through the nodes and test streamLike() method or stored procedure (testStoredProc=1)
	for i = 1:1:@globalName
	{
		#dim list As %List = @globalName@(i)
		#dim result As %Boolean
		#dim expected As %Boolean
		do ..doTest(cacheToPPG, testStoredProc, ..#TEMPCLASSNAME, list, .result, .expected)
		
		do $$$AssertEquals(result, expected, expected _ " = " _ result)
	}
	
	kill @globalName
}

/// do ##class(UnitTest.iscru.util.StreamUtils.TestStreamLike).debugTest(0, 0)
ClassMethod debugTest(cacheToPPG As %Boolean, testStoredProc As %Boolean)
{
	if testStoredProc
	{
		do ..dropTempClass(..#TEMPCLASSNAME)
		#dim sc As %Status = ..createTempClass(..#TEMPCLASSNAME)
		$$$ThrowOnError(sc)
	}
	
	#dim globalName As %String = ..populateGlobal()
	
	for i = 1:1:@globalName
	{
		#dim list As %List = @globalName@(i)
		#dim result As %Boolean
		#dim expected As %Boolean
		do ..doTest(cacheToPPG, testStoredProc, ..#TEMPCLASSNAME, list, .result, .expected)
		if (expected '= result) write expected _ " '= " _ result _ " / "  zw list
	}
	
	kill @globalName
	if testStoredProc do ..dropTempClass(..#TEMPCLASSNAME)
}

/// Return name of the global.
/// Each node of the global contains a list:
///   edgesStr*, stuffingStringCount*, pattern, escape char, case insensitive flag, expected result
/// * - edgesStr and stuffingStringCount are arguments for ..createStream() method.
ClassMethod populateGlobal() As %String [ Private ]
{
	#dim global As %String = "^||" _ $classname()
	
	kill @global
			
	// I. test with no escape char, case insensitive
	//  1) stream = "abcabc"
	set @global@($i(@global)) = $lb("abcabc", 0, "ABCABC", "", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abcabc", 0, "ABCABC%", "", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abcabc", 0, "ABC_ABC", "", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "ABCAB", "", $$$YES, $$$NO)
	
	//  2) stream = "abc_123%ABC.... ... ...abc_123%ABC" (more than 7Mb of dots)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%abc", "", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%123%123%abc", "", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%123%ABC%", "", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%123%ABC%abc", "", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%def", "", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%def%", "", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "def%", "", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc_123%ABC%def%", "", $$$YES, $$$NO)
	
	// II. test with no escape char, case sensitive
	//  1) stream = "abcabc"
	set @global@($i(@global)) = $lb("abcabc", 0, "abcabc", "", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abcabc", 0, "abcabc%", "", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abcabc", 0, "abc_abc", "", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "abcab", "", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "abcAbc", "", $$$NO, $$$NO)
	
	//  2) stream = "abc_123%ABC.... ... ...abc_123%ABC" (more than 7Mb of dots)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%ABC", "", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%123%123%ABC", "", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%123%ABC%", "", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%123%abc%ABC", "", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%ABC%ABC%ABC", "", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%0123%", "", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "Abc%", "", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc_123%ABC%1234%", "", $$$NO, $$$NO)

	// III. test with escape char "~", case insensitive
	//  1) stream = "abcabc"
	set @global@($i(@global)) = $lb("abcabc", 0, "ABCABC", "~", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abcabc", 0, "ABCABC%", "~", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abcabc", 0, "ABC_ABC", "~", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "ABC~%ABC", "~", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "ABCAB", "~", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "abcabc~%", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "abcabc%", "~", $$$NO, $$$YES)
	
	//  2) stream = "abc_123%ABC.... ... ...abc_123%ABC" (more than 7Mb of dots)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%abc", "~", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%123%123%abc", "~", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%123%ABC%", "~", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%123%ABC%abc", "~", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%def", "~", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%def%", "~", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "def%", "~", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc_123%ABC%def%", "~", $$$YES, $$$NO)
	
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc_123~%123%abc", "~", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%~_123~%abc%", "~", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%~_123~%abc%~%%", "~", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%~_123~%abc%abc", "~", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%~_123~%abc%abc%~_abc", "~", $$$YES, $$$NO)
	
	// IV. test with escape char "~", case sensitive
	//  1) stream = "abcabc"
	set @global@($i(@global)) = $lb("abcabc", 0, "abcabc", "~", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abcabc", 0, "abcabc%", "~", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abcabc", 0, "abc_abc", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "abc~%abc", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "abcab", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "abcAbc", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "abcabc~%", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "abcabc%", "~", $$$NO, $$$YES)
	
	//  2) stream = "abc_123%ABC.... ... ...abc_123%ABC" (more than 7Mb of dots)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%ABC", "~", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%123%123%ABC", "~", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%123%ABC%", "~", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%123%abc%ABC", "~", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc%ABC%ABC%ABC", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%0123%", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "Abc%", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc_123%ABC%1234%", "~", $$$NO, $$$NO)
	
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc_123~%123%ABC", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc_123~%%abc", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "abc_123~%%ABC", "~", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%~_123~%abc%", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%~_123~%ABC%~%%", "~", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%~_123~%ABC%abc", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abc_123%ABC", 2, "%~_123~%ABC%abc%~_ABC", "~", $$$NO, $$$NO)
	
	// special case: null pattern --> always return false
	set @global@($i(@global)) = $lb("", 0, "", "", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("", 0, "", "", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("", 0, "", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("", 0, "", "~", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "", "", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "", "", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "", "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, "", "~", $$$YES, $$$NO)
	
	// special case: empty ($char(0)) pattern --> return true if empty stream
	set @global@($i(@global)) = $lb("", 0, $c(0), "", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("", 0, $c(0), "", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("", 0, $c(0), "~", $$$NO, $$$YES)
	set @global@($i(@global)) = $lb("", 0, $c(0), "~", $$$YES, $$$YES)
	set @global@($i(@global)) = $lb("abcabc", 0, $c(0), "", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, $c(0), "", $$$YES, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, $c(0), "~", $$$NO, $$$NO)
	set @global@($i(@global)) = $lb("abcabc", 0, $c(0), "~", $$$YES, $$$NO)
	
	quit global
}

/// If <var>stuffingStringCount</var> equals zero then return <var>edgesStr</var> wrapped in a %Stream.TmpCharacter.
/// Otherwise return a stream that starts and ends with <var>edgesStr</var>, and has <var>stuffingChar</var> in between.
/// In the latter case size of the stream is (2 * $length(edgesStr)) + (stuffingStringCount * $$$MaxLocalLength).
ClassMethod createStream(edgesStr As %String, stuffingStringCount As %Integer(MINVAL=0) = 0, stuffingChar As %String(MAXLEN=1) = ".") As %Stream.TmpCharacter [ Private ]
{
	#dim s As %Stream.TmpCharacter = ##class(%Stream.TmpCharacter).%New()
	
	do s.Write(edgesStr)
	
	if (+stuffingStringCount > 0)
	{
		for i = 1:1:stuffingStringCount
		{
			do s.Write($translate($justify(stuffingChar, $$$MaxLocalLength), " ", stuffingChar))
		}
		do s.Write(edgesStr)
	}
	
	do s.Rewind()
	
	quit s
}

/// Using data from <var>list</var>: test either ##class(iscru.util.StreamUtils).streamLike() method
/// or iscru_util.FunctionSet_streamLike stored procedure (if <var>testStoredProc</var> equals 1)
/// assuming that <var>list</var> contains the following items:
///   edgesStr*, stuffingStringCount*, pattern, escape char, case insensitive flag, expected result<br/>
/// * - edgesStr and stuffingStringCount are arguments for ..createStream() method.
ClassMethod doTest(cacheToPPG As %Boolean, testStoredProc As %Boolean, className As %String, list As %List, Output result As %Boolean, Output expected As %Boolean) [ Private ]
{
	#dim stream As %Stream.Object = ..createStream($list(list, 1), $list(list, 2))
	#dim pattern As %String = $list(list, 3)
	#dim escape As %String = $list(list, 4)
	#dim caseInsens As %Boolean = +$list(list, 5)
	set expected = +$list(list, 6)
	
	if 'testStoredProc
	{
		// test streamLike() method
		set result = ##class(iscru.util.StreamUtils).streamLike(stream, pattern, escape, caseInsens, cacheToPPG)
	}
	else
	{
		// test iscru_util.FunctionSet_streamLike stored procedure

		// truncate table and add just one row
		do $classmethod(className, "%KillExtent")
		#dim obj As %Persistent = $classmethod(className, "%New")
		do obj.stream.CopyFrom(stream)
		#dim sc As %Status = obj.%Save()
		kill stream, obj
		$$$ThrowOnError(sc)

		// query table
		#dim tableName As %String  = $$$comClassKeyGet(className, $$$cCLASSsqlschemaname) _ "." _ $$$comClassKeyGet(className, $$$cCLASSsqltablename)
		#dim sql As %String = "SELECT 1 FROM " _ tableName _ " WHERE 1 = iscru_util.FunctionSet_streamLike(stream, ?, ?, ?, ?)"
		#dim statement As %SQL.Statement = ##class(%SQL.Statement).%New()
		set sc = statement.%Prepare(sql)
		$$$ThrowOnError(sc)

		#dim stResult As %SQL.StatementResult = statement.%Execute(pattern, escape, caseInsens, cacheToPPG)
		#dim SQLCODE As %Integer = stResult.%SQLCODE
		if (SQLCODE < 0) $$$ThrowStatus($$$ERROR($$$SQLError, SQLCODE, stResult.%Message))
		
		set result = stResult.%Next()
	}
}

/// Create persistent class with the given name. Add just one stream property to the class.
ClassMethod createTempClass(className As %String) [ Private ]
{
	#dim c As %Dictionary.ClassDefinition = ##class(%Dictionary.ClassDefinition).%New()
	set c.Name = className
	set c.ProcedureBlock = $$$YES
	set c.Super = "%Persistent"

	#dim p As %Dictionary.PropertyDefinition = ##class(%Dictionary.PropertyDefinition).%New()
	set p.Name = "stream"
	set p.Type = "%GlobalCharacterStream"
	do c.Properties.Insert(p)

	#dim sc As %Status = c.%Save()
	if $$$ISERR(sc) quit sc
	
	set sc = $System.OBJ.Compile(c.Name)
	if $$$ISERR(sc) quit sc
	
	quit $$$OK
}

/// Delete data and drop persistent class.
ClassMethod dropTempClass(className As %String) [ Private ]
{
	try
	{
		// if there is a compiled class with the given name then kill data using %KillExtent() method
		if $$$comClassDefined(className) do $classmethod(className, "%KillExtent")
		
		// drop the class
		if ##class(%Dictionary.ClassDefinition).%ExistsId(className) do ##class(%Dictionary.ClassDefinition).%DeleteId(className)
	}
	catch
	{}
	
	quit $$$OK
}

}

