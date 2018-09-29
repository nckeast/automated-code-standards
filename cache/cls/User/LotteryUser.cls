/// The <CLASS>LotteryUser</CLASS> class represents a user for 
/// the CSP Lottery Example application.
Class User.LotteryUser Extends %Persistent
{

Index UserNameIdx On UserName [ Unique ];

Property UserName As %String [ Required ];

Property LastName As %String [ Required ];

Property FirstName As %String [ Required ];

Property Password As %String [ Private, Required ];

Property VisitCount As %Integer [ InitialExpression = 0 ];

Property TotalBalance As %Integer [ InitialExpression = 0 ];

Property History As list Of LotteryActivity;

/// Change the password for this user.
Method changePassword(pass As %String) As %Integer
{
	set ..Password = pass	
	quit
}

/// Test if <var>pass</var> is correct password for this user.
Method testPassword(pass As %String) As %Boolean
{
	quit (..Password = pass)
}

/// Called by CSP page to add a new user.
ClassMethod addNewUser(UserName As %String, FirstName As %String, LastName As %String, pass As %String) As %Integer
{
	set user = ##class(LotteryUser).%New()
	set user.UserName = UserName
	set user.FirstName = FirstName
	set user.LastName = LastName
	do user.changePassword(pass)

	set sc = user.%Save()

	if ($$$ISERR(sc)) &javascript<alert('Unable to create user.');> quit 0

	quit 1
}

/// Find the ID of the user with the specified user name.
ClassMethod findUser(UserName As %String) As %String
{
	set id = ""

	// use embedded SQL to search for user
	&SQL(SELECT ID INTO :id FROM LotteryUser WHERE (UserName = :UserName))

	quit id
}

/// Test if the name/password specifies a valid user. If so, return the user's ID.
ClassMethod authenticate(UserName As %String, Password As %String) As %String
{
	set id = ..findUser(UserName)
	if (id '= "") do
	. set user = ..%OpenId(id)
	. if ' user.testPassword(Password) set id = ""

	quit id
}

/// Called by CSP page to add a new purchase. Returns amount of purchase.
ClassMethod addPurchase(id As %String, type As %String) As %Float
{
	set price = 0
	if (type = "STANDARD") set price = 10
	else  if (type = "DELUXE") set price = 50

	if (price = 0) quit 0

	set user = ##class(LotteryUser).%OpenId(id)
	if user = "" quit 0

	set action = ##class(LotteryActivity).%New()
	set action.TheUser = user
	set action.ActivityType = "PURCHASE"
	set action.Amount = price
	set action.Product = type

	do user.History.Insert(action)

	set sc = user.%Save()

	quit price
}

Storage Default
{
<Data name="LotteryUserDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>FirstName</Value>
</Value>
<Value name="3">
<Value>History</Value>
</Value>
<Value name="4">
<Value>LastName</Value>
</Value>
<Value name="5">
<Value>Password</Value>
</Value>
<Value name="6">
<Value>TotalBalance</Value>
</Value>
<Value name="7">
<Value>UserName</Value>
</Value>
<Value name="8">
<Value>VisitCount</Value>
</Value>
</Data>
<DataLocation>^User.LotteryUserD</DataLocation>
<DefaultData>LotteryUserDefaultData</DefaultData>
<ExtentSize>100000</ExtentSize>
<IdLocation>^User.LotteryUserD</IdLocation>
<IndexLocation>^User.LotteryUserI</IndexLocation>
<StreamLocation>^User.LotteryUserS</StreamLocation>
<Type>%Library.CacheStorage</Type>
}

}
