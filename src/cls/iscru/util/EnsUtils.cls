Include Ensemble

/// A container class for utility methods that deal with Ensemble productions / InterSystems IRIS Interoperability productions.
Class iscru.util.EnsUtils [ Abstract ]
{

/// Get the currently running production. 
ClassMethod getCurrentProduction() As Ens.Config.Production
{
	#dim prodName As %String
	if '##class(Ens.Director).IsProductionRunning(.prodName) quit ""
	
	#dim sc As %Status
	#dim prod As Ens.Config.Production = ##class(Ens.Config.Production).%OpenId(prodName,, .sc)
	$$$ThrowOnError(sc)  // highly unlikely
	
	quit prod
}

/// Send request <var>message</var> asynchronously from <var>serviceName</var> business service 
/// to <var>targetHostName</var> business process or operation.
/// If <var>serviceName</var> is not specified then EnsLib.Testing.Service is used.
/// In that case "Testing Enabled" production setting should be checked.
/// Specify <var>sessionId</var> if the request should be sent in the scope of a particular session.
/// The actual session ID is recorded to <var>sessionId</var> once the message has been sent.
ClassMethod sendRequestFromService(targetHostName As %String, message As %Persistent, serviceName As %String = "EnsLib.Testing.Service", ByRef sessionId As %Integer = "", description As %String = "") As %Status
{
	#dim prod As Ens.Config.Production = ..getCurrentProduction()
	if '$isObject(prod) quit $$$ERROR($$$GeneralError, "No running production")
		
	#dim item As Ens.Config.Item = ..findConfigItem(targetHostName)
	if '$isObject(item) quit $$$ERROR($$$GeneralError, targetHostName _ " not found")
	
	#dim service As Ens.BusinessService
	#dim sc As %Status = ##class(Ens.Director).CreateBusinessService(serviceName, .service)
	if $$$ISERR(sc) quit sc
	
	if ($get(sessionId) '= "") set service.%SessionId = sessionId
	set sc = service.SendRequestAsync(targetHostName, message, description)
	set sessionId = service.%SessionId
	
	quit sc
}

/// Find a business host by name and type.
/// <var>businessType</var> can be either $$$eHostTypeService, $$$eHostTypeProcess or $$$eHostTypeOperation.
/// Empty <var>businessType</var> means that type does not matter.
/// If <var>enabledOnly</var> is 1 then search through enabled hosts only.
ClassMethod findConfigItem(name As %String, businessType As %String = "", enabledOnly As %Boolean = {$$$NO}) As Ens.Config.Item
{
	#dim prod As Ens.Config.Production = ..getCurrentProduction()
	if '$isObject(prod) quit ""

	// loop through production elements
	#dim result As Ens.Config.Item = ""
	for i = 1:1:prod.Items.Count()
	{
		#dim item As Ens.Config.Item = prod.Items.GetAt(i)
		
		if '$isObject(item)
		    || (item.Name '= name)
				|| ((businessType '= "") && (item.BusinessType() '= businessType))
				|| (enabledOnly && 'item.Enabled)
		{
			continue
		}
						
		set result = item
		quit
	}
	
	quit result
}

/// Find a business host by a setting name/value pair.
/// <var>businessType</var> can be $$$eHostTypeService, $$$eHostTypeProcess or $$$eHostTypeOperation.
/// Empty <var>businessType</var> means that type does not matter.
/// If <var>enabledOnly</var> is 1 then search through enabled hosts only.
ClassMethod findConfigItemBySettingValue(settingName As %String, settingValue As %String, businessType As %String = "", enabledOnly As %Boolean = {$$$NO}) As Ens.Config.Item
{
	#dim prod As Ens.Config.Production = ..getCurrentProduction()
	if '$isObject(prod) quit ""

	// loop through production elements
	#dim result As Ens.Config.Item = ""
	for i = 1:1:prod.Items.Count()
	{
		#dim item As Ens.Config.Item = prod.Items.GetAt(i)

		if '$isObject(item)
				|| ((businessType '= "") && (item.BusinessType() '= businessType))
				|| (enabledOnly && 'item.Enabled)
		{
			continue
		}
		
		// loop through settings
		do item.PopulateModifiedSettings()
		#dim ind As %String = ""
		for
		{
			#dim setting = item.ModifiedSettings.GetNext(.ind)
			if (ind = "") quit

			if (setting.Name = settingName)
			{
				if ($zstrip(setting.Value, "<>W") = $zstrip(settingValue, "<>W")) set result = item
				quit
			}
		} // for

		if $isObject(result) quit
	} // for
	
	quit result
}

/// Get the value of <var>settingName</var> setting of <var>hostName</var> production element.
ClassMethod getSettingValue(hostName As %String, settingName As %String) As %String
{
	#dim prod As Ens.Config.Production = ..getCurrentProduction()
	if '$isObject(prod) quit ""
	
	// loop through production elements
	for i = 1:1:prod.Items.Count()
	{
		#dim item As Ens.Config.Item = prod.Items.GetAt(i)
		if '$isObject(item) || (item.Name '= hostName) continue
		
		// loop through settings
		do item.PopulateModifiedSettings()
		#dim ind As %String = ""
		for
		{
			#dim setting = item.ModifiedSettings.GetNext(.ind)
			if (ind = "") quit

			if (setting.Name = settingName) return setting.Value
		} // for

		quit
	}	

	quit ""
}

/// Abort a Queued/Suspended/Deferred request message returning a standard error response 
/// with "Message XXX aborted" text to the sender.
/// Note that a synchronous request can only be aborted when there is a running production.
ClassMethod abortMessage(messageHeaderId As %Integer) As %Status
{
	#dim sc As %Status = $$$OK
	try
	{
		#dim message As Ens.MessageHeader = ##class(Ens.MessageHeader).%OpenId(messageHeaderId,, .sc)
		if $$$ISERR(sc) quit
		
		// verify that this is a request message - not a response
		if (message.Type '= 1)
		{
			set sc = $$$ERROR($$$GeneralError, "Message " _ messageHeaderId _ " is not a Request")
			quit
		}
		
		// verify that message status is one of the following: Queued/Suspended/Deferred
		if (message.Status '= $$$eMessageStatusQueued) && (message.Status '= $$$eMessageStatusDeferred) && (message.Status '= $$$eMessageStatusSuspended)
		{
			set sc = $$$ERROR($$$GeneralError, "Status of the message " _ messageHeaderId _ " is neither of these: Queued, Suspended, Deferred")
			quit
		}
		
		// if the production is not running then we cannot abort a sync request
		if '$data($$$EnsQueue) && (message.ReturnQueueName '= "") && '$$$queueIsNotSyncQueue(message.ReturnQueueName)
		{
			set sc = $$$ERROR($$$GeneralError, "Sync request " _ messageHeaderId _ " can only be aborted when the production is running")
			quit
		}
		
		if (message.Status '= $$$eMessageStatusQueued)
		{
			// simple case: Deferred/Suspended request
			do message.SetStatus($$$eMessageStatusAborted)
		}
		else
		{
			// not so simple: Queued
			
			#dim queueName As %String = message.TargetQueueName
			#dim globalName As %String = $select($data($$$EnsQueue):$name($$$EnsQueue), 1:$name($$$EnsSuspended($$$SystemName, "Ens.Queue")))
			
			if '$data(@globalName@(queueName))
			{
				set sc = $$$ERROR($$$GeneralError, "Queued message " _ messageHeaderId _ "'s queue " _ queueName _ " cannot be found")
				quit
			}
			
			#dim found As %Boolean = $$$NO
			#dim pri As %Integer = 0
			for
			{
				set pri = $order(@globalName@(queueName, pri))
				if (pri = "") quit
				
				#dim ind As %String = ""
				for
				{
					set ind = $order(@globalName@(queueName, pri, ind))
					if (ind = "") quit
					
					if ($get(@globalName@(queueName, pri, ind)) = messageHeaderId)
					{
						set found = $$$YES
						quit
					}
				} // for
				
				if found quit
			} // for
			
			if $$$ISERR(sc) quit
		
			if 'found
			{
				set sc = $$$ERROR($$$GeneralError, "Queued message " _ messageHeaderId _ " is not on the queue " _ queueName)
				quit
			}
			
			set sc = ##class(Ens.Queue).AbortItem(queueName, pri, ind)
			if $$$ISERR(sc) quit
			
			///////////////// if the production is running then that's it for a Queued message!
			if $data($$$EnsQueue) quit
		}
		
		
		// if we know return queue, then return a standard error response
		if (message.ReturnQueueName '= "")
		{
			#dim responseHeader As Ens.MessageHeader
			set sc = message.NewErrorResponse(.responseHeader, $$$ERROR($$$EnsErrGeneral, "Message '" _ messageHeaderId _ "' aborted."))
			if $$$ISERR(sc) quit
			
			set sc = ##class(Ens.Queue).EnQueue(responseHeader)
			if $$$ISERR(sc) quit
		}
	}
	catch ex
	{
		set sc = $get(%objlasterror)
		if (sc = "") set sc = ex.AsStatus()
	}

	quit sc
}

}

