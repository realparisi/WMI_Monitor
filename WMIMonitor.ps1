function New-EventSubscriberMonitor
{
<#
.SYNOPSIS

    Create a new Event Subscriber to monitor for newly created WMI Event Consumers and processes.
	
    Author: Tim Parisi
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None
 
.DESCRIPTION

    New-EventSubscriberMonitor will create an Event Subscriber to monitor for newly created WMI Event Consumers and processes. Each event will be logged in the application event log as Event ID 8 and source of "WSH"

.LINK

    {link to blog post when posted}

.INSTRUCTIONS
    1) Execute the script from an Administrative PowerShell console
    The functions "New-EventSubscriberMonitor" and "Remove-SubscriberMonitor" will no be loaded into your system's PowerShell instance.
    2) Type New-EventSubscriberMonitor to invoke the function and start recording WMI process creations and Consumers
    3) Type Remove-SubscriberMonitor to remove the WMI subscriber created and discontinue logging the events

#>
	#ConsumerFilterArguments
	$ConsumerFilterNamespace = 'root/subscription'
    $ConsumerFilterClass = '__EventFilter' 
    $ConsumerFilterArgs = @{
		EventNamespace = 'root/subscription'
		Name = '_PersistenceEvent_'
		Query = 'SELECT * FROM __InstanceCreationEvent WITHIN 5 Where TargetInstance ISA "__EventConsumer"'
		QueryLanguage = 'WQL'
	}

    #ProcessCallFilter Arguments
    $ProcessCallFilterNamespace = 'root/subscription'
    $ProcessCallFilterClass = '__EventFilter'
	$ProcessCallFilterArgs = @{
		EventNamespace = 'root/cimv2'
		Name = '_ProcessCreationEvent_'
		Query = 'SELECT * FROM MSFT_WmiProvider_ExecMethodAsyncEvent_Pre WHERE ObjectPath="Win32_Process" AND MethodName="Create"'
		QueryLanguage = 'WQL'
	}
    
    #Create Consumer and Process Call Filters
	$ConsumerFilter = Set-WmiInstance -Class $ConsumerFilterClass -Namespace $ConsumerFilterNamespace -Arguments $ConsumerFilterArgs
	$ProcessCallFilter = Set-WmiInstance -Class $ProcessCallFilterClass -Namespace $ProcessCallFilterNamespace -Arguments $ProcessCallFilterArgs

	# Define the event log template and parameters
	$ConsumerTemplate = @(
		'==New WMI Consumer Created==',
		'Consumer Name: %TargetInstance.Name%',
		'Command Executed: %TargetInstance.ExecutablePath%'
	)

	$ProcessCallTemplate = @(
		'==WMI Command Executed==',
		'Namespace: %Namespace%',
		'Method Executed: %MethodName%',
		'Command Executed: %InputParameters.CommandLine%'
	)

    #Define the ConsumerEvent Arguments
    $ConsumerEventNamespace = 'root/subscription'
    $ConsumerEventClass = 'NTEventLogEventConsumer'
    $ConsumerEventArgs = @{
		Name = '_LogWMIConsumerEvent_'
		Category = [UInt16] 0
		EventType = [UInt32] 2 # Warning
		EventID = [UInt32] 8
		SourceName = 'WSH'
		NumberOfInsertionStrings = [UInt32] $ConsumerTemplate.Length
		InsertionStringTemplates = [String[]] $ConsumerTemplate
	}

    #Define the ProcessCallEvent Arguments
    $ProcessCallEventNamespace = 'root/subscription'
    $ProcessCallEventClass = 'NTEventLogEventConsumer'
	$ProcessCallEventArgs = @{
		Name = [String] '_LogWMIProcessCreationEvent_'
		Category = [UInt16] 0
		EventType = [UInt32] 2 # Warning
		EventID = [UInt32] 8
		SourceName = [String] 'WSH'
		NumberOfInsertionStrings = [UInt32] $ProcessCallTemplate.Length
		InsertionStringTemplates = [String[]] $ProcessCallTemplate
	}

    #Create the Event Consumers
	$ConsumerConsumer = Set-WmiInstance -Class $ConsumerEventClass -Namespace $ConsumerEventNamespace -Arguments $ConsumerEventArgs
	$ProcessCallConsumer = Set-WmiInstance -Class $ProcessCallEventClass -Namespace $ProcessCallEventNamespace -Arguments $ProcessCallEventArgs

    #Define the Consumer Binding Arguments
	$ConsumerBindingNamespace = 'root/subscription'
    $ConsumerBindingClass = '__FilterToConsumerBinding'
    $ConsumerBindingArgs = @{
		Filter = $ConsumerFilter
		Consumer = $ConsumerConsumer
	}

    #Define the ProcessCall Binding Arguments
    $ProcessCallBindingNamespace = 'root/subscription'
    $ProcessCallBindingClass = '__FilterToConsumerBinding'
	$ProcessCallBindingArgs = @{
		Filter = $ProcessCallFilter
		Consumer = $ProcessCallConsumer
	}

	# Register the bindings
	$ConsumerBinding = Set-WmiInstance -Class $ConsumerBindingClass -Namespace $ConsumerBindingNamespace -Arguments $ConsumerBindingArgs
	$ProcessCallBinding = Set-WmiInstance -Class $ProcessCallBindingClass -Namespace $ProcessCallBindingNamespace -Arguments $ProcessCallBindingArgs
	
	Write-Output 'The new event subscriber has been successfully created!'
	Write-Output 'Check the Application Event Log for Event ID 8 and source of "WSH"'
}

function Remove-SubscriberMonitor
{
<#
.SYNOPSIS

    Will remove the Event Subscriber that monitors for newly created WMI Event Consumers and processes.
	
    Author: Evan Pena
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None
 
.DESCRIPTION

    Remove-SubscriberMonitor removes all event consumer bindings, consumers, and filters that were created.

.LINK

    {link to blog post when posted}
#>

	Get-WmiObject __eventFilter -namespace root/subscription -filter "name='_PersistenceEvent_'"| Remove-WmiObject
	Get-WmiObject __eventFilter -namespace root/subscription -filter "name='_ProcessCreationEvent_'"| Remove-WmiObject
	
	Remove-WmiObject -Path "ROOT/subscription:NTEventLogEventConsumer.Name='_LogWMIConsumerEvent_'"
	Remove-WmiObject -Path "ROOT/subscription:NTEventLogEventConsumer.Name='_LogWMIProcessCreationEvent_'"
	
	Get-WmiObject __FilterToConsumerBinding -Namespace root/subscription | Where-Object { $_.filter -match '_ProcessCreationEvent_'} | Remove-WmiObject
	Get-WmiObject __FilterToConsumerBinding -Namespace root/subscription | Where-Object { $_.filter -match '_PersistenceEvent_'} | Remove-WmiObject
	
	Write-Output 'The event subscriber and all associating WMI objects have been successfully removed.'
}
