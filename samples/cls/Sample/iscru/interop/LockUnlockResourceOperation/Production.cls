Class Sample.iscru.interop.LockUnlockResourceOperation.Production Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="Sample.iscru.interop.LockUnlockResourceOperation.Production" TestingEnabled="true" LogGeneralTraceEvents="true">
  <ActorPoolSize>1</ActorPoolSize>
  <Item Name="iscru.interop.LockUnlockResourceOperation" Category="" ClassName="iscru.interop.LockUnlockResourceOperation" PoolSize="4" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
  </Item>
  <Item Name="Sample.iscru.interop.LockUnlockResourceOperation.CallerProcessBPL" Category="" ClassName="Sample.iscru.interop.LockUnlockResourceOperation.CallerProcessBPL" PoolSize="4" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
    <Setting Target="Host" Name="lockUnlockOperation">iscru.interop.LockUnlockResourceOperation</Setting>
  </Item>
  <Item Name="Sample.iscru.interop.LockUnlockResourceOperation.CallerProcess" Category="" ClassName="Sample.iscru.interop.LockUnlockResourceOperation.CallerProcess" PoolSize="4" Enabled="true" Foreground="false" Comment="" LogTraceEvents="true" Schedule="">
  	<Setting Target="Host" Name="lockUnlockOperation">iscru.interop.LockUnlockResourceOperation</Setting>
  </Item>
</Production>
}

}

