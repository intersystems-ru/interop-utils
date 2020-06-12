Class UnitTest.iscru.util.StreamUtils.TestStreamLike Extends %UnitTest.TestCase
{

Method TestWithoutPPGCache()
{
	do ..internal($$$NO)
}

Method TestWithPPGCache()
{
	do ..internal($$$YES)
}

Method internal(cacheToPPG As %Boolean) [ Private ]
{
	// temp global name
	#dim global As %String = "^||" _ $classname()
	
	do ..populateGlobal(global)
	
	// now each node of the global contains a list:
	//   edgesStr*, stuffingStringCount*, pattern, escape char, case insensitive flag, expected result
	// * - edgesStr and stuffingStringCount are arguments for ..createStream() method

	// loop through the items and test streamLike()
	for i = 1:1:@global
	{
		#dim list As %List = @global@(i)
		#dim result As %Boolean
		#dim expected As %Boolean
		do ..getResultAndExpected(cacheToPPG, list, .result, .expected)
		
		do $$$AssertEquals(result, expected, expected _ " = " _ result)
	}
	
	kill @global
}

/// do ##class(UnitTest.iscru.util.StreamUtils.TestStreamLike).debugTest(0)
ClassMethod debugTest(cacheToPPG As %Boolean)
{
	// temp global name
	#dim global As %String = "^||" _ $classname()
	
	do ..populateGlobal(global)
	
	for i = 1:1:@global
	{
		#dim list As %List = @global@(i)
		#dim result As %Boolean
		#dim expected As %Boolean
		do ..getResultAndExpected(cacheToPPG, list, .result, .expected)
		if (expected '= result) write expected _ " '= " _ result _ " / "  zw list
	}
	
	kill @global
}

ClassMethod populateGlobal(global As %String) [ Private ]
{
	kill @global
	
	// each node of the global will contain a list:
	//   edgesStr*, stuffingStringCount*, pattern, escape char, case insensitive flag, expected result
	// * - edgesStr and stuffingStringCount are arguments for ..createStream() method
		
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

/// Call ##class(iscru.util.StreamUtils).streamLike() with data from <var>list</var>.
/// We assume that <var>list</var> contains the following items:
///   edgesStr*, stuffingStringCount*, pattern, escape char, case insensitive flag, expected result<br/>
/// * - edgesStr and stuffingStringCount are arguments for ..createStream() method.
ClassMethod getResultAndExpected(cacheToPPG As %Boolean, list As %List, Output result As %Boolean, expected As %Boolean) [ Private ]
{
	#dim stream As %Stream.Object = ..createStream($list(list, 1), $list(list, 2))
	#dim pattern As %String = $list(list, 3)
	#dim escape As %String = $list(list, 4)
	#dim caseInsens As %Boolean = +$list(list, 5)
	set expected = +$list(list, 6)
	set result = ##class(iscru.util.StreamUtils).streamLike(stream, pattern, escape, caseInsens, cacheToPPG)
}

}

