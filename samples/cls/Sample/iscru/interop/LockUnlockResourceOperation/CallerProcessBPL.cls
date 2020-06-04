/// Sample BPL-based business process intended to demonstrate an approach similar to "Message Groups" concept found in other messaging engines.
/// 
/// Use case: consider a business process receiving messages related to resources of a certain type.
/// It needs to guarantee serial processing of messages in the scope of each particular resource, e.g. serial processing of messages related to a patient, while sustaining high-volume message load.
/// (For a non-BPL process setting PoolSize=1 and using only sync calls within the process would guarantee FIFO "globally" but would also significantly limit scalability.)<p/>
/// 
/// Solution demonstrated by this class: 1) acquire a logical lock for the resource ID retrieved from the request message, 
/// 2) execute business logic, 3) release the lock once finished. 1) and 2) are calls to iscru.interop.LockUnlockResourceOperation.
/// That class takes care of queueing up process instances that request resource lock.
/// Due to "deferred response" technique there is no long-term job/db locks involved.</p>
/// 
/// Since the logical lock should be eventually released regardless of any exceptions thrown,
/// &lt;scope&gt;, &lt;faulthandlers&gt; and &lt;catchall&gt; elements have to be employed.
Class Sample.iscru.interop.LockUnlockResourceOperation.CallerProcessBPL Extends Ens.BusinessProcessBPL
{

Property target As Ens.DataType.ConfigName;

Parameter SETTINGS = "target:Basic";

XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript' request='Ens.StringContainer' response='Ens.Response'>
<context>
<property name='lastError' type='%Library.Status' initialexpression='$$$OK'/>
</context>
<sequence>
<call name="lockCall" target="@..%Process.target" async="0">
<annotation>Resource lock should be acquired as early as possible to ensure correct ordering of messages related to the resource</annotation>
<request type="Ens.StringContainer">
<assign property="callrequest.StringValue" value='"+" _ request.StringValue'/>
</request>
<response type="Ens.Response"/>
</call>

<scope>
<annotation>This scope is supposed to contain all the user defined logic of the process. In case of any exception we make sure to unlock the resource before throwing the exception out - see the second scope below.</annotation>
	
<trace value='"do something useful here"'>
<annotation>Do something useful here</annotation>
</trace>

<call name="alarmCall" target="Ens.Alarm" async="0">
<annotation>Pause for 20 seconds (releasing the job) so that we can inspect visual traces</annotation>
<request type="Ens.AlarmRequest">
<assign property="callrequest.Duration" value='"PT20S"'/>
</request>
<response type="Ens.AlarmResponse"/>
</call>

<faulthandlers>
<catchall>
<!-- Catch an exception and put it into context.lastError so that we can re-throw it later -->
<assign property="context.lastError" value="context.%LastError">
<annotation>Store exception in context.lastError so that we can re-throw it later</annotation>
</assign>
</catchall>
</faulthandlers>
</scope>

<scope>
<annotation>Unlock the resource before re-throwing exception (if any)</annotation>
<call name="unlockCall" target="@..%Process.target" async="0">
<request type="Ens.StringContainer">
<assign property="callrequest.StringValue" value='"-" _ request.StringValue'/>
</request>
<response type="Ens.Response"/>
</call>
<faulthandlers>
<catchall>
<code>
<annotation>Log exception using $$$LOGSTATUS and proceed</annotation>
<![CDATA[ $$$LOGSTATUS(context.%LastError) ]]>
</code>
</catchall>
</faulthandlers>
</scope>

<assign property="status" value='context.lastError'>
<annotation>If there was an exception in the main scope, then re-throw it here</annotation>
</assign>
</sequence>
</process>
}

ClassMethod test(process As %String = {$classname()})
{
	for i = 1:1:5 { set sc = ##class(isc.util.EnsUtils).invokeHostAsync(process, ##class(Ens.StringContainer).%New($lb("abc", 123)))  if (sc '= 1) write $System.Status.GetErrorText(sc),! }
}

Storage Default
{
<Data name="CallerProcessBPLDefaultData">
<Subscript>"CallerProcessBPL"</Subscript>
<Value name="1">
<Value>target</Value>
</Value>
</Data>
<DefaultData>CallerProcessBPLDefaultData</DefaultData>
<Type>%Library.CacheStorage</Type>
}

}

