/// 
/// Handles log messages using log levels
Class Studio.SourceControl.Util.Logger Extends %RegisteredObject
{

/// Current log level
Parameter LOGLEVEL = 2;

Parameter DEBUG = 1;

Parameter INFO = 2;

Parameter ERROR = 7;

Property LogLevel As %Integer [ InitialExpression = {..#LOGLEVEL} ];

Method Log(pLevel As %String, pMsg As %String, pNL As %Boolean = 1)
{
	if pLevel >= ..LogLevel {
	 write:pNL !
	 write pMsg
	}
	quit
}

Method Debug(pMsg As %String, pNL As %Boolean = 1)
{
	do ..Log(..#DEBUG, pMsg, pNL)
}

Method Error(pMsg As %String, pNL As %Boolean = 1)
{
	do ..Log(..#ERROR, pMsg, pNL)
}

Method Info(pMsg As %String, pNL As %Boolean = 1)
{
	do ..Log(..#INFO, pMsg, pNL)
}

/// This callback method is invoked by the <METHOD>%New</METHOD> method to 
/// provide notification that a new instance of an object is being created.
/// 
/// <P>If this method returns an error then the object will not be created.
/// <p>It is passed the arguments provided in the %New call.
/// When customizing this method, override the arguments with whatever variables and types you expect to receive from %New().
/// For example, if you're going to call %New, passing 2 arguments, %OnNew's signature could be:
/// <p>Method %OnNew(dob as %Date = "", name as %Name = "") as %Status
/// If instead of returning a %Status code this returns an oref and this oref is a subclass of the current
/// class then this oref will be the one returned to the caller of %New method.
Method %OnNew() As %Status [ Private, ServerOnly = 1 ]
{
	// Writing to the current device will disrupt REST calls such as those used from Atelier.
	if $data(%request) && (%request.URL [ "atelier") set ..LogLevel = 10
	
	quit $$$OK
}

}

