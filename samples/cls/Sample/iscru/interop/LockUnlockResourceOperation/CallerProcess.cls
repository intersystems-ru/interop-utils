/// Sample ObjectScript-based business process intended to demonstrate an approach similar to "Message Groups" concept found in other messaging engines.<p/>
/// 
/// Use case: consider a business process that receives messages related to resources of a certain type.
/// The process needs to guarantee serial processing of messages in the scope of each particular resource, 
/// e.g. serial processing of messages related to a patient, while sustaining high-volume message load.
/// (Setting PoolSize=1 and using only sync calls within the process would guarantee FIFO "globally" but would also significantly limit scalability.)<p/>
/// 
/// Solution demonstrated by this class performs the following steps: <ul><li>first acquire a logical lock for the resource ID retrieved from the request message,</li>
/// <li>execute business logic,</li><li> once finished, release the lock.</li></ul> 
/// First and last steps are calls to <class>iscru.interop.LockUnlockResourceOperation</class>.
/// That class takes care of queueing up process instances that request resource lock simultaneously. 
/// Due to "deferred response" technique there is no long-term job/db blocking involved.<p/>
Class Sample.iscru.interop.LockUnlockResourceOperation.CallerProcess Extends Ens.BusinessProcess
{

Property lockUnlockOperation As Ens.DataType.ConfigName;

Property currentResourceId As %String(MAXLEN = "");

Parameter SETTINGS = "lockUnlockOperation:Basic";

Parameter lockCOMPLETIONKEY = "*lock*";

/// do ##class(Sample.iscru.interop.LockUnlockResourceOperation.CallerProcess).test()
ClassMethod test(processName As %String = {$classname()}, resourceId As %String = {$lb("abc", 123)}, count As %Integer = 5)
{
	for i = 1:1:count
	{
		#dim sc As %Status = ##class(iscru.util.EnsUtils).sendRequestFromService(processName, ##class(Ens.StringContainer).%New(resourceId))
		if $$$ISERR(sc) write $System.Status.GetErrorText(sc),!
	}
}

Method OnRequest(request As Ens.StringContainer, Output response As %Library.Persistent) As %Status
{
	$$$TRACE("OnRequest")
	
	// memorize resource ID
	set ..currentResourceId = request.StringValue
	
	// acquire logical lock for the resource
	quit ..lockResource()
}

/// Acquire logical lock for the resource
Method lockResource() As %Status [ Private ]
{
	if (..currentResourceId = "") quit $$$ERROR($$$GeneralError, "Empty resource ID")
	
	#dim msg As Ens.StringContainer = ##class(Ens.StringContainer).%New("+" _ ..currentResourceId)
	quit ..SendRequestAsync(..lockUnlockOperation, msg, $$$YES, ..#lockCOMPLETIONKEY, "lock resource ID " _ ##class(%Global).Quote(..currentResourceId))
}

/// Release logical lock for the resource
Method unlockResource() As %Status [ Private ]
{
	if (..currentResourceId = "") quit $$$OK
	
	#dim msg As Ens.StringContainer = ##class(Ens.StringContainer).%New("-" _ ..currentResourceId)
	
	// here pResponseRequired=$$$NO means that we don't need any response back
	#dim sc As %Status = ..SendRequestAsync(..lockUnlockOperation, msg, $$$NO,, "unlock resource ID " _ ##class(%Global).Quote(..currentResourceId))
	
	// clear current resource ID
	if $$$ISOK(sc) set ..currentResourceId = ""
	
	quit sc
}

/// Async response received
Method OnResponse(request As %Library.Persistent, ByRef response As %Library.Persistent, callrequest As %Library.Persistent, callresponse As %Library.Persistent, pCompletionKey As %String) As %Status
{
	$$$TRACE("OnResponse" _ "; pCompletionKey=" _ pCompletionKey)
	
	if (pCompletionKey = ..#lockCOMPLETIONKEY)
	{
		// if it's a response from the locking operation then execute custom OnRequest logic
		quit ..customOnRequest(request, .response)
	}
	else
	{
		// otherwise execute custom OnResponse logic
		quit ..customOnResponse(request, .response, callrequest, callresponse, pCompletionKey)
	}
}

Method customOnRequest(request As %Library.Persistent, Output response As %Library.Persistent) As %Status
{
	$$$TRACE("Custom OnRequest code")
	
	// Pause for 20 seconds (releasing the job) so that we can inspect visual traces
	#dim msg As Ens.AlarmRequest = ##class(Ens.AlarmRequest).%New()
	set msg.Duration = "PT20S"
	quit ..SendRequestAsync("Ens.Alarm", msg, $$$YES, "*alarm*", "alarm call")
}

Method customOnResponse(request As %Library.Persistent, ByRef response As %Library.Persistent, callrequest As %Library.Persistent, callresponse As %Library.Persistent, pCompletionKey As %String) As %Status
{
	$$$TRACE("Custom OnResponse code")
	quit $$$OK
}

Method customOnError(request As %Library.Persistent, ByRef response As %Library.Persistent, callrequest As %Library.Persistent, pErrorStatus As %Status, pCompletionKey As %String) As %Status
{
	$$$TRACE("Custom OnError code")
	quit pErrorStatus
}

Method customOnComplete(request As %Library.Persistent, ByRef response As %Library.Persistent) As %Status
{
	$$$TRACE("Custom OnComplete code")
	quit $$$OK
}

/// This method is called when an error response is received OR there is an "internal" exception in OnRequest() or OnResponse().
/// Returning the same error will cause the BusinessProcess to set its status to error and close down - without executing OnComplete().
/// In case of error response returning $$$OK from this method causes the BusinessProcess to recover from this error.
/// Note thet in case of an internal exception (i.e. empty callrequest) returning $$$OK from this method would hang the process: response would be never sent back to the caller.
Method OnError(request As %Library.Persistent, ByRef response As %Library.Persistent, callrequest As %Library.Persistent, pErrorStatus As %Status, pCompletionKey As %String) As %Status
{
	$$$TRACE("OnError: " _ $$$StatusDisplayString(pErrorStatus) _ "; $isObject(callrequest)=" _ $isObject($get(callrequest)))

	// if we've got an exception from the lock call, then stop here
	if (pCompletionKey = ..#lockCOMPLETIONKEY) quit pErrorStatus
	
	// execute custom OnError logic
	try
	{
		set pErrorStatus = ..customOnError(request, .response, callrequest, pErrorStatus, pCompletionKey)
	}
	catch ex
	{
		set pErrorStatus = $$$ADDSC(pErrorStatus, ex.AsStatus())
	}
	
	if $$$ISERR(pErrorStatus) || '$isObject($get(callrequest))
	{
		// if the exception has not been "swallowed" OR this is an internal kind of exception, then OnComplete() will not fire, so we need to call unlock here
		#dim sc As %Status = ..unlockResource()
		if $$$ISERR(sc) $$$LOGSTATUS(sc) // this is very unlikely to happen
	}
	
	quit pErrorStatus
}

/// Called when all the Async responses are received, or timeout has occurred.
/// Not called if an error has not been swallowed by OnError().
Method OnComplete(request As %Library.Persistent, ByRef response As %Library.Persistent) As %Status
{
	$$$TRACE("OnComplete")
	
	// execute custom OnComplete logic
	#dim sc As %Status = $$$OK
	try
	{
		set sc = ..customOnComplete(request, .response)
	}
	catch ex
	{
		set sc = ex.AsStatus()
	}
	
	// release logical lock for the resource
	#dim sc2 As %Status = ..unlockResource()
	if $$$ISERR(sc2) $$$LOGSTATUS(sc2) // this is very unlikely to happen
	
	quit sc
}

Storage Default
{
<Data name="CallerProcessDefaultData">
<Subscript>"CallerProcess"</Subscript>
<Value name="1">
<Value>lockUnlockOperation</Value>
</Value>
<Value name="2">
<Value>currentResourceId</Value>
</Value>
</Data>
<DefaultData>CallerProcessDefaultData</DefaultData>
<Type>%Library.CacheStorage</Type>
}

}

