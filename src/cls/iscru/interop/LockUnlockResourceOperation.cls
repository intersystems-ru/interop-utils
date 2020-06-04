/// A generic business-operation that logically locks/unlocks a resource identified by the ID specified within Ens.StringContainer request.
/// Passing an ID prefixed with "+" means lock, while "-" prefix means unlock.
/// A resource ID could be anything (including $lb list) suitable to be used as a global subscript. It should not be longer than 400 bytes.<p/>
/// 
/// The operation is intended to help implement the approach similar to "Message Groups" concept found in other messaging engines:
/// guarantee ordering of the processing of messages related to some resource (e.g. a patient) across the caller's queue without sacrificing scalability, 
/// i.e. caller's PoolSize can be greater than 1.<p/>
/// 
/// Lock: <ul>
///   <li> if the resource is not busy, then we just lock it logically by filling 
///        a global node under ^Ens.AppData with the current session id, 
///        and return an empty response to the caller;</li>
///   <li> otherwise <b>defer response</b> and put $lb(&lt;defer token&gt;, &lt;session id&gt;) pair at the end of the resource's <i>lock wait queue</i>,
///        making the caller wait for its turn to process a message related to the resource.</li></ul>
/// 
/// Unlock: <ul>
///   <li> if the resource's <i>lock wait queue</i> is empty, then just unlock the resource logically by removing corresponding global node;</li>
///   <li> otherwise pull the next token/sessionId pair from the queue, lock the resource logically on behalf of that session,
///        and call <b>SendDeferredResponse()</b> method using the retrieved token - in order to return an empty response to that session, thus 
///        informing it that a logical lock has finally been acquired by the session.</li></ul>
/// 
/// Note that all of the above manipulations are performed while holding a physical (exclusive) lock for the resource ID.
/// Hence using the operation with PoolSize greater than 1 should be fine.<p/>
/// 
/// If a production deals with several types of resources (e.g. patients and care providers) 
/// then several business operations of this class should be configured within a production.
Class iscru.interop.LockUnlockResourceOperation Extends Ens.BusinessOperation
{

Parameter SETTINGS = "ExclusiveLockTimeout:Basic";

/// Period of time to wait before physical exclusive lock command times out. Specify timeout as an integer number of seconds. A value of 0 means make one attempt, then time out. -1 means wait indefinitely.
Property ExclusiveLockTimeout As %Integer(MINVAL = -1) [ InitialExpression = 30, Required ];

Property rootGlobalName As %String [ Private ];

/// Memorize name of the global node within ^Ens.AppData that will hold resource lock flags and lock wait queues.
/// Note that name of the business operation (..%ConfigName) corresponds to a resource type.
Method OnInit() As %Status
{
	set ..rootGlobalName = $name($$$EnsStaticAppData(..%ConfigName, "data"))
	quit $$$OK
}

/// Dispatch the request either to lock() or to unlock() method depending on the first character of the request's StringValue:
/// "+" means lock, "-" means unlock.
Method OnMessage(pRequest As Ens.StringContainer, Output pResponse As Ens.Response) As %Status
{
	if '$isObject($get(pRequest)) quit $$$ERROR($$$InvalidArgument)
	
	#dim method As %String = $case($extract(pRequest.StringValue, 1, 1), "+":"lock", "-":"unlock", :"")
	#dim arg As %String = $extract(pRequest.StringValue, 2, *)
	
	if (method = "") || (arg = "") quit $$$ERROR($$$GeneralError, "Invalid request: " _ ##class(%Global).Quote(pRequest.StringValue))
	if ($length(arg) > 400) quit $$$ERROR($$$GeneralError, "A resource ID should not be longer than 400 bytes")

	set pResponse = $$$NULLOREF
	
	quit $method($this, method, arg)
}

/// Put a logical lock on the specified resource: <ul>
///    <li> if the resource is not busy, then just lock it logically by filling
///        a global node under ^Ens.AppData with the current session id, and return an empty response to the caller;</li>
///    <li> otherwise defer response and append [defer token, session id] pair at the end of the resource's <i>lock wait queue</i>
///        making the caller wait for its turn to process a message related to the resource.</li></ul>
Method lock(resourceId As %String) As %Status
{
	// get a zw-like string for the resource ID to be used in error/trace messages
	#dim quotedResourceId As %String = ##class(%Global).Quote(resourceId)
	
	// acquire physical lock
	#dim sc As %Status = ..acquireExclusiveLock(resourceId)
	if $$$ISERR(sc) quit sc
	
	try
	{
		// get lock flag global node
		#dim lockFlagNode As %String = ..getLockFlagGlobalName(resourceId)
		
		if ($get(@lockFlagNode) = ..%SessionId)
		{
			// nothing to do since the resource has already been locked by the current session
		}
		elseif ($get(@lockFlagNode) = "")  // the resource is free
		{
			// raise a flag indicating that the resource has been locked by the current session
			set @lockFlagNode = ..%SessionId
			
			$$$TRACE("Logical lock has been acquired for the resource " _ quotedResourceId)
		}
		else
		{
			// if logical lock cannot be acquired now, then 1) call DeferResponse() and 2) put defer token at the end of the resource's lock wait queue
			
			#dim deferToken As %String = ""
			set sc = ..DeferResponse(.deferToken)
			if $$$ISERR(sc) quit
			
			// append [defer token, session id] pair to the resource's lock wait queue
			#dim queueSize As %Integer
			set sc = ..enqueue(resourceId, deferToken, ..%SessionId, .queueSize)
			if $$$ISERR(sc) quit
			
			if $$$DoTrace $$$TRACE("Resource " _ quotedResourceId _ " is busy, so defer the response and append defer token " _ ##class(%Global).Quote(deferToken) _ " to the resource's lock wait queue. Queue size is " _ queueSize _ " now.")
		}
	}
	catch ex
	{
		set sc = $get(%objlasterror)
		if (sc = "") set sc = ex.AsStatus()
	}
	
	// release physical lock
	try { do ..releaseExclusiveLock(resourceId) } catch ignore { $$$LOGSTATUS(ignore.AsStatus()) }
	
	quit sc
}

/// Unlock the specified resource: <ul>
///    <li> if the resource's <i>lock wait queue</i> is empty, then just unlock the resource logically by removing the corresponding global node;</li>
///    <li> otherwise pull the next token/sessionId pair from the queue, replace the resource's logical lock with that session id,
///        and call SendDeferredResponse() using the token - in order to return an empty response to that session 
///        (meaning that a successful logical lock has finally been acquired by the session).</li></ul>
Method unlock(resourceId As %String) As %Status
{
	// get a zw-like string for the resource ID to be used in error/trace messages
	#dim quotedResourceId As %String = ##class(%Global).Quote(resourceId)
	
	// acquire physical lock
	#dim sc As %Status = ..acquireExclusiveLock(resourceId)
	if $$$ISERR(sc) quit sc
	
	try
	{
		// get lock flag global node
		#dim lockFlagNode As %String = ..getLockFlagGlobalName(resourceId)
		
		// check if the resource is currently locked by the current session
		if ($get(@lockFlagNode) '= ..%SessionId)
		{
			set sc = $$$ERROR($$$GeneralError, "Resource " _ quotedResourceId _ " is currently locked by some other session: " _ $get(@lockFlagNode))
			quit
		}

		#dim found As %Boolean
		#dim deferToken As %String
		#dim sessionId As %Integer
		set sc = ..dequeue(resourceId, .found, .deferToken, .sessionId)
		if $$$ISERR(sc) quit
		
		if 'found
		{
			// lock wait queue is empty --> just remove the lock flag
			kill @lockFlagNode
			
			$$$TRACE("Resource " _ quotedResourceId _ " has been unlocked")
		}
		else
		{
			// if lock wait queue is not empty then
			///  - lock the resource on behalf of the session which ID has just been retrieved, i.e. replace the resource's logical lock flag with that session id,
			///  - call SendDeferredResponse() using the retrieved token;
			///     the call will return a response to that session informing it of a successful logical lock just acquired for the resource.
			
			// lock the resource on behalf of the session which ID has just been retrieved from the queue
			set @lockFlagNode = sessionId
			
			$$$TRACE("Resource " _ quotedResourceId _ " has been unlocked by the current session and then locked again by session #" _ sessionId)

			// call SendDeferredResponse() returning an empty response to the session that corresponds to defer token
			//  thus informing the session of a successful logical lock just acquired for the resource
			set sc = ##class(Ens.Host).SendDeferredResponse(deferToken, $$$NULLOREF)
			if $$$ISERR(sc) quit
		}
	}
	catch ex
	{
		set sc = $get(%objlasterror)
		if (sc = "") set sc = ex.AsStatus()
	}
	
	// release physical lock
	try { do ..releaseExclusiveLock(resourceId) } catch ignore { $$$LOGSTATUS(ignore.AsStatus()) }
	
	quit sc
}

/// Append [defer token, session id] pair to the resource's lock wait queue
Method enqueue(resourceId As %String, deferToken As %String, sessionId As %String, Output queueSize As %Integer) As %Status [ Private ]
{
	#dim queueNode As %String = ..getQueueGlobalName(resourceId)
	
	// append [defer token, session id] pair to the resource's lock wait queue
	set @queueNode@($increment(@queueNode)) = $lb(deferToken, sessionId)
	
	set queueSize = @queueNode - $order(@queueNode@("")) + 1
	
	quit $$$OK
}

/// Pull the next [defer token, session id] pair from resource's lock wait queue
Method dequeue(resourceId As %String, Output found As %Boolean, Output deferToken As %String, Output sessionId As %String) As %Status [ Private ]
{
	#dim queueNode As %String = ..getQueueGlobalName(resourceId)
	
	// get queue's head key
	#dim queueHeadKey As %Integer = $order(@queueNode@(""))

	set found = (queueHeadKey '= "")
	
	// if lock wait queue is empty then bail out
	if 'found quit $$$OK
	
	// pull the next element (token/session pair) from the queue
	#dim val As %List = $get(@queueNode@(queueHeadKey))
	
	// remove the element from the queue (need to remove it even if it turns out to be invalid)
	kill @queueNode@(queueHeadKey)
	
	// check if the retrieved element is a list of two non-empty strings
	if (val = "") || '$listvalid(val) || ($lg(val, 1) = "") || ($lg(val, 2) = "")
	{
		quit $$$ERROR($$$GeneralError, "Encountered an invalid element in lock wait queue of the resource " _ ##class(%Global).Quote(resourceId) _ ": " _ ##class(%Global).Quote(val))
	}
	
	set deferToken = $lg(val, 1)
	set sessionId = $lg(val, 2)
	
	quit $$$OK
}

/// Physical lock
Method acquireExclusiveLock(resourceId As %String) As %Status [ Private ]
{
	#dim lock As %String = ..getGlobalName(resourceId, "")

	if (..ExclusiveLockTimeout = -1)
	{
		lock +@lock
	}
	else
	{
		lock +@lock:..ExclusiveLockTimeout
		if '$test quit $$$ERROR($$$LockFailedToAcquireExclusive, lock)
	}

	quit $$$OK
}

/// Physical unlock
Method releaseExclusiveLock(resourceId As %String) As %Status [ Private ]
{
	#dim lock As %String = ..getGlobalName(resourceId, "")

	lock -@lock

	quit $$$OK
}

/// Lock flag global node
Method getLockFlagGlobalName(resourceId As %String) As %String [ Private ]
{
	quit ..getGlobalName(resourceId, "lockedBySessionId")
}

/// Lock wait queue global node
Method getQueueGlobalName(resourceId As %String) As %String [ Private ]
{
	quit ..getGlobalName(resourceId, "queue")
}

Method getGlobalName(resourceId As %String, subscript As %String = "") As %String [ Private ]
{
	if (subscript '= "") quit $name(@..rootGlobalName@(resourceId, subscript))
	
	quit $name(@..rootGlobalName@(resourceId))
}

}

