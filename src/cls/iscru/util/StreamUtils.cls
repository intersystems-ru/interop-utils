/// A container class for stream-related utilities.
Class iscru.util.StreamUtils [ Abstract ]
{

/// Process-private global that is used by streamLike() method to cache parsed patterns
Parameter ppgROOT = "^||iscru.util.StreamUtils";

/// Tests if the given stream's content satisfies a SQL Like comparison with the given </var>pattern</var> string.
/// In SQL Like patterns, % matches 0 or more characters, and _ matches any single character.
/// Note that an <var>escape</var> character can be specified, e.g. pattern="#%SYSVAR_#_%" with escape="#" to match any value string that starts with "%SYSVAR" followed by any single character, an underscore, and anything else.<br/>
/// <var>streamRefOrOid</var> can be either a stream reference or a stream OID.
/// If <var>cacheToPPG</var> is 1 then a process-private global is used for caching parsed patterns; this is useful when the same pattern is applied many times, e.g. WHERE clause of a SQL query.
ClassMethod streamLike(streamRefOrOid As %Stream.Object, pattern As %String, escape As %String(MAXLEN=1) = "", caseInsensitive As %Boolean = {$$$YES}, cacheToPPG As %Boolean = {$$$NO}) As %Boolean [ SqlProc ]
{
	if (pattern = "") quit $$$NO // null pattern --> false
	
	if caseInsensitive set pattern = $zcvt(pattern, "L")
	
	set escape = $extract(escape, 1)
	if (escape '= "")
	{
		if caseInsensitive && (escape '= $zcvt(escape, "L")) $$$ThrowStatus($$$ERROR($$$GeneralError, "Escape character " _ escape _ " is not supported in case insensitive mode"))
		if (escape = "%") || (escape = "_") $$$ThrowStatus($$$ERROR($$$GeneralError, "Escape character " _ escape _ " is not supported"))
	}
	
	#dim stream As %Stream.Object = streamRefOrOid
	if '$isObject(stream)
	{
		// assume we've got a stream OID
		#dim sc As %Status = $$$OK
		set stream = ##class(%Stream.Object).%Open(streamRefOrOid,, .sc)
		$$$ThrowOnError(sc)
	}
	else
	{
		do stream.Rewind()
	}
	
	// empty string pattern corresponds to an empty stream
	if (pattern = $c(0)) quit (stream.Size = 0)

	#dim patternPartsList As %List = ""
	if cacheToPPG && $data(@..#ppgROOT@(pattern, "\" _ escape))
	{
		// use cached list from PPG
		set patternPartsList = @..#ppgROOT@(pattern, "\" _ escape)
	}
	else
	{
		// split pattern into a list	
		if (escape = "")
		{
			// simple case: no escape char specified
			set patternPartsList = $listFromString(pattern, "%")
		}
		else
		{
			#dim prevP As %Integer = 1
			#dim p As %Integer = $find(pattern, "%")
			while (p > 0)
			{
				if (p = (prevP + 1))
				{
					set patternPartsList = patternPartsList _ $lb("")
					set prevP = p
				}
				else
				{
					#dim subPattern As %String = $extract(pattern, prevP, p - 2)
					if '..endsWithEscape(subPattern, escape)
					{
						set patternPartsList = patternPartsList _ $lb(subPattern)
						set prevP = p
					}
				}
				
				set p = $find(pattern, "%", p)
			}
			
			// last piece of the pattern
			set patternPartsList = patternPartsList _ $lb($extract(pattern, prevP, *))
		}
		
		// save list to PPG (if needed)
		if cacheToPPG set @..#ppgROOT@(pattern, "\" _ escape) = patternPartsList
	}
	
	#dim negative As %Boolean = $$$NO
	#dim currentPos As %Integer = 1
	#dim patternPartsCount As %Integer = $listlength(patternPartsList)
	#dim pointer As %Integer = 0
	#dim i As %Integer = 0
	set subPattern = ""
	while $listnext(patternPartsList, pointer, subPattern)
	{
		set i = i + 1
		
		// the first/last character of the pattern is %, or there are repeating %
		if (subPattern = "") continue
		
		#dim len As %Integer = $length(..removeEscape(subPattern, escape)) 

		if (i = 1)
		{
			// if we are here, then the pattern starts with something other than %
			#dim substr As %String = stream.Read(.len)
			if caseInsensitive && (substr '= "") set substr = $zcvt(substr, "L")
			if (len < 1) || (0 = ..find(substr, subPattern,, escape, cacheToPPG))
			{
				set negative = $$$YES
				quit
			}
			
			set currentPos = len + 1
			
			if (patternPartsCount = 1) && (currentPos < (stream.Size + 1))
			{
				// if we are here, then the pattern is a one piece pattern, i.e. no % at all
				// and there are some extra characters in the stream after the pattern
				set negative = $$$YES
				quit
			}
		}
		else
		{
			do
			{
				#dim tmpstr As %String
				#dim pos As %Integer = ..findInStream(stream, subPattern, escape, .tmpstr, caseInsensitive, cacheToPPG)
				if (pos = -1)
				{
					set negative = $$$YES
					quit
				}
			
				set currentPos = currentPos + pos - 1 + len
				
				// if this is the last piece of the pattern, then try to find the subpattern at the end of the stream
				// otherwise proceed to the next piece of the pattern

			} while (i = patternPartsCount) && (currentPos < (stream.Size + 1))
			
			if negative quit
		}
		
		//w "currentPos=" _ currentPos,!
		
	} // while $listnext
	
	quit 'negative
}

ClassMethod endsWithEscape(str As %String, escape As %String) As %Boolean [ Private ]
{
	set escape = $extract(escape, 1)
	if (escape = "") || (str '[ escape) quit $$$NO
	
	quit ($extract($replace(str, escape_escape, ""), *) = escape)
}

ClassMethod removeEscape(str As %String, escape As %String = "") As %String [ Private ]
{
	set escape = $extract(escape, 1)
	if (escape = "") || (str '[ escape) quit str
	
	#dim list As %List = $listFromString(str, escape_escape)
	#dim result As %String = ""
	#dim pointer As %Integer = 0
	#dim item As %String = ""
	while $listnext(list, pointer, item)
	{
		if (result '= "") set result = result _ escape
		set result = result _ $replace(item, escape, "")
	}
	
	quit result
}

/// Analogous to ##class(%Stream.Object).FindAt(-1, ...)
/// Pattern argument supports underscore that matches any single character.
/// Escape argument can contain a character which is used to escape underscores within the pattern.
ClassMethod findInStream(stream As %Stream.Object, pattern As %String, escape As %String(MAXLEN=1) = "", ByRef tmpstr As %String = "", caseInsensitive As %Boolean = {$$$NO}, cacheToPPG As %Boolean = {$$$NO}) As %Integer [ Private ]
{
	if caseInsensitive set pattern = $zcvt(pattern, "L")
	
	set escape = $extract(escape, 1)
	if (escape '= "") && caseInsensitive && (escape '= $zcvt(escape, "L")) $$$ThrowStatus($$$ERROR($$$GeneralError, "Escape character " _ escape _ " is not supported in case insensitive mode"))
	
	#dim find As %Integer = 0
	#dim patternlen As %Integer = $length(..removeEscape(pattern, escape))
	#dim position As %Integer = 1
	
	if ($get(tmpstr) '= "")
	{
		set find = ..find(tmpstr, pattern,, escape, cacheToPPG)
		if find
		{
			set tmpstr = $extract(tmpstr, find, *)
			quit position + find - patternlen - 1
		}
		else 
		{
			set position = position + $length(tmpstr) - patternlen + 1
		}
	}
	
	while 'stream.AtEnd
	{
		#dim tmp = stream.Read(20000)
		if caseInsensitive set tmp = $zcvt(tmp, "L")
		set tmpstr = $extract(tmpstr, * - patternlen + 2, *) _ tmp
		set find = ..find(tmpstr, pattern,, escape, cacheToPPG)
		if find
		{
			set tmpstr = $extract(tmpstr, find, *)
			quit
		}
		set position = position + $length(tmpstr) - patternlen + 1
	}

	if find
	{
		quit position + find - patternlen - 1
	}
	else
	{
		quit -1
	}
}

/// Same as $find() plus support for patterns containing underscore that matches any single character.
/// If substringOrPattern is found, this method returns the integer position of the first character following substringOrPattern.
/// If substringOrPattern is not found then a value of 0 is returned.
/// Escape argument can contain a character which is used to escape underscores within substringOrPattern.
ClassMethod find(str As %String, substringOrPattern As %String, position As %Integer = 1, escape As %String(MAXLEN=1) = "", cacheToPPG As %Boolean = {$$$NO}) As %Integer [ Private ]
{
	if (position > $length(str)) $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid position"))
	
	set escape = $extract(escape, 1)
	if (escape = "_") $$$ThrowStatus($$$ERROR($$$InvalidArgument))
	
	if (substringOrPattern '[ "_")
	{
		// no underscores --> use $find
		// remove escape char if specified
		quit $find(str, ..removeEscape(substringOrPattern, escape), position)
	}
	
	if ($translate(substringOrPattern, "_", "") = "")
	{
		// a special case of all underscores pattern
		// find any string which length equals substringOrPattern's length
		#dim len As %Integer = $length(substringOrPattern)
		quit $select(len <= ($length(str) - position + 1):position + len, 1:0)
	}
	
	#dim firstNonEmptyPart As %String = ""
	#dim firstNonEmptyPartNum As %Integer = 0
	#dim pattern As %String = ""
	
	if cacheToPPG && $data(@..#ppgROOT@(substringOrPattern, "\" _ escape, "pattern"))
	{
		// use cached info from PPG
		set firstNonEmptyPart = @..#ppgROOT@(substringOrPattern, "\" _ escape, "part")
		set firstNonEmptyPartNum = @..#ppgROOT@(substringOrPattern, "\" _ escape, "partNum")
		set pattern = @..#ppgROOT@(substringOrPattern, "\" _ escape, "pattern")
	}
	else
	{
		do ..findParseInternal(substringOrPattern, escape, .firstNonEmptyPart, .firstNonEmptyPartNum, .pattern)
		//w pattern,":",str?@pattern,!
		
		if cacheToPPG
		{
			// save info to PPG
			set @..#ppgROOT@(substringOrPattern, "\" _ escape, "part") = firstNonEmptyPart
			set @..#ppgROOT@(substringOrPattern, "\" _ escape, "partNum") = firstNonEmptyPartNum
			set @..#ppgROOT@(substringOrPattern, "\" _ escape, "pattern") = pattern
		}
	}
	
	#dim substringOrPatternLen As %Integer = $length(..removeEscape(substringOrPattern, escape))
	#dim firstNonEmptyPartLen As %Integer = $length(firstNonEmptyPart)
	
	// loop through all occurencies of firstNonEmptyPart within str
	#dim pos As %Integer = $find(str, firstNonEmptyPart, position + firstNonEmptyPartNum - 1)
	while (pos > 0)
	{
		#dim start As %Integer = pos - firstNonEmptyPartLen - firstNonEmptyPartNum + 1
		#dim substr As %String = $extract(str, start, start + substringOrPatternLen - 1)

		if substr?@pattern
		{
			set pos = start + substringOrPatternLen
			quit
		}
		
		set pos = $find(str, firstNonEmptyPart, pos)
	}
	
	quit pos
}

ClassMethod findParseInternal(substringOrPattern As %String, escape As %String(MAXLEN=1), Output firstNonEmptyPart As %String, Output firstNonEmptyPartNum As %Integer, Output pattern As %String) [ Private ]
{
	set firstNonEmptyPartNum = 0
	set firstNonEmptyPart = ""
	set pattern = ""
	
	// split substringOrPattern into a list
	#dim patternPartsList As %List = ""
	if (escape = "")
	{
		// simple case: no escape char specified
		set patternPartsList = $listFromString(substringOrPattern, "_")
	}
	else
	{
		#dim prevP As %Integer = 1
		#dim p As %Integer = $find(substringOrPattern, "_")
		while (p > 0)
		{
			if (p = (prevP + 1))
			{
				set patternPartsList = patternPartsList _ $lb("")
				set prevP = p
			}
			else
			{
				#dim subPattern As %String = $extract(substringOrPattern, prevP, p - 2)
				if '..endsWithEscape(subPattern, escape)
				{
					set patternPartsList = patternPartsList _ $lb(..removeEscape(subPattern, escape))
					set prevP = p
				}
			}
			
			set p = $find(substringOrPattern, "_", p)
		}
		
		// last piece of the pattern
		set patternPartsList = patternPartsList _ $lb(..removeEscape($extract(substringOrPattern, prevP, *), escape))
	}

	// construct a pattern to be used with ? operator
	//   and find the first non-empty part of the original pattern
	#dim pointer As %Integer = 0
	#dim item As %String = ""
	#dim i As %Integer = 0
	while $listnext(patternPartsList, pointer, item)
	{
		set i = i + 1
		if (firstNonEmptyPartNum = 0) && (item '= "")
		{
			set firstNonEmptyPartNum = i
			set firstNonEmptyPart = item
		}

		if (i > 1) set pattern = pattern _ "1E"
		if (item '= "") set pattern = pattern _ "1""" _ $replace(item, """", """""") _ """"
	}
}

/*
/// d ##class(iscru.util.StreamUtils).test()
ClassMethod test(arg As %String)
{
	&sql(select count(1) into :cnt from isc_esb_msg.SoapClientRequest where iscru_util.FunctionSet_streamLike(body, :arg) = 1)
	write "cnt=" _ $get(cnt) _ ";SQLCODE=" _ $get(SQLCODE) _ "; %msg=" _ $get(%msg),!
}
*/
}

