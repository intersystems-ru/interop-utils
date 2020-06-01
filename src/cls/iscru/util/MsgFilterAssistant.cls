/// SQL query construction and execution for the Ensemble Message Viewer.
/// Added support for stream Like/NotLike operators.
/// Need to set ^EnsPortal.Settings("MessageViewer","AssistantClass") = "iscru.util.MsgFilterAssistant" in order to use this class for the Message Viewer.
/// User should have a permission to run iscru_util.FunctionSet_streamLike stored procedure.
Class iscru.util.MsgFilterAssistant Extends EnsPortal.MsgFilter.Assistant
{

/// Overridden to support Like/NotLike operators for streams.
Method addSQLTerms(ByRef aSelect, ByRef aFrom, Output xWhere, level = 1, tNode = "1", Output pAllowEmptyWhere As %Boolean, pBitmapIndexUsed As %Boolean = 0) As %Integer
{
	set xWhere = ""
	set pAllowEmptyWhere = $$$NO
	
	if '$data(..Tree) quit 2
	
	#dim tType As %String = @("..Tree("_tNode_",""type"")")
	#dim tProp As %String = $get(@("..Tree("_tNode_",""prop"")"))
	#dim tOp As %String = $get(@("..Tree("_tNode_",""op"")"))
	
	if (tType '= "Body") || (tProp = "") || ((tOp '= "Like") && (tOp '= "NotLike"))
	{
		quit ##super(.aSelect, .aFrom, .xWhere, level, tNode, .pAllowEmptyWhere, pBitmapIndexUsed)
	}

	#dim tClass As %String = @("..Tree("_tNode_",""class"")")
	#dim tDisplayOnly As %Boolean = +$get(@("..Tree("_tNode_",""display"")"))
	#dim tVal As %String = @("..Tree("_tNode_",""val"")")
	#dim asName As %String = $select(..BodyClasses = 1: "Body", 1:$translate(tClass,".%","__"))_"_"_$select(tProp = "": "ID", 1:$replace($translate(tProp,".%()","____"),"->","_"))
	set @("..Tree("_tNode_",""asname"")") = asName

	set pAllowEmptyWhere = tDisplayOnly

	#dim tDone As %Boolean = $$$YES
	#dim tPropString As %String = ""
	#dim tClassKey As %String = tClass
	#dim tPropType As %String = ""
	for k = 1:1:$length(tProp, ".")
	{
		#dim tPropName As %String = $piece(tProp, ".", k)
		#dim tPropDef As %Dictionary.CompiledProperty = ##class(%Dictionary.CompiledProperty).IDKEYOpen(tClassKey, tPropName, 0)
		if '$isObject(tPropDef)
		{
			set tDone = $$$NO
			quit
		}
		set tClassKey = tPropDef.Type
		set tPropType = $$$comClassKeyGet(tPropDef.Type,$$$cCLASSclasstype)
		#dim tPropRef = $$$comMemberKeyGet(tClassKey,$$$cCLASSproperty,tPropName,$$$cPROPsqlfieldname)
		set tPropString = tPropString _ $select(tPropRef'="":tPropRef,1:tPropName) _ $select(tPropType = "serial": "_", 1: "->")
	}
	
	if 'tDone
	{
		set tPropString = $replace(tProp, ".", "->")  // Assume -> syntax
	}
	elseif (tPropType '= "")
	{
		set tPropString = $extract(tPropString, 1, *-$select(tPropType="serial": 1, 1: 2))
	}

	#dim prop As %String = $$$ClassSQLTable(tClass) _ "." _ tPropString
	
	if (..BodyClasses > 1)
	{
		#; Only want to show the value if the body class is the class pointed to by the header
		do ..addTerm(.aSelect, "CASE head.MessageBodyClassName WHEN '" _ tClass _ "' THEN " _ prop _ " ELSE '' END  As " _ asName, ":" _ tNode)
	}
	else
	{
		do ..addTerm(.aSelect, prop _ " As "_ asName, ":" _ tNode)
	}

	if 'tDisplayOnly
	{
		if (tPropType '= "stream") || 'tDone
		{
			set xWhere = ..GetSQLCondition(tOp, prop, tVal, 1)
		}
		else
		{
			#dim escape As %String = ""
			if ("%%" = $extract(tVal, *-2, *-1))
			{
				//set tVal = "'" _ $extract(tVal, 1, *-3) _ "' ESCAPE '" _ $extract(tVal, *) _ "'"
				set tVal = $extract(tVal, 1, *-3)
				set escape = $extract(tVal, *)
			}

			set tVal = "'" _ $replace(tVal, "'", "''") _ "'"
			if (escape '= "") set escape = "'" _ $replace(escape, "'", "''") _ "'"
			
			//set xWhere = "substring(" _ prop _ ", 1, 3000000) " _ $case(tOp, "Like": "LIKE", "NotLike": "NOT LIKE") _ " " _ tVal

			set xWhere = "iscru_util.FunctionSet_streamLike(" _ prop _ ", " _ tVal _ "," _ escape _ ",, 1) " _ $case(tOp, "Like": "", "NotLike": "!") _ "= 1"
		}
	}
	
	#dim result As %Integer = $select(tDisplayOnly: 2, xWhere = "": 1, 1: 2)
	if result set @("..Tree("_tNode_",""sqldone"")") = result

	quit result
}

/* 
A "quick and dirty" proof-of-concept implementation.

/// Helper method to return a valid WHERE subclause condition for a supplied property
/// reference (<var>pProp</var>), operator (<var>pOperator</var>) and value (<var>pValue</var>).
/// Overridden to support Like/NotLike operators for streams not longer than 3M bytes.
ClassMethod GetSQLCondition(
	pOperator As %String,
	pProp As %String,
	pValue As %String,
	pDisplay As %Boolean = 0,
	pNoIndex As %Boolean = 0) As %String
{
	if (pValue '= "") && ((pOperator = "Like") || (pOperator = "NotLike"))
	{
		if ("%%" = $extract(pValue, *-2, *-1))
		{
			set pValue = "'" _ $replace($extract(pValue, 1, *-3), "'", "''") _ "' ESCAPE '" _ $extract(pValue, *) _ "'"
		}
		else
		{
			set pValue = "'" _ $replace(pValue, "'", "''") _ "'"
		}
		
		quit "substring(" _ pProp _ ", 1, 3000000) " _ $case(pOperator, "Like": "LIKE", "NotLike": "NOT LIKE") _ " " _ pValue
	}
	else
	{
		quit ##super(pOperator, pProp, pValue, pDisplay, pNoIndex)
	}
}
*/
}

