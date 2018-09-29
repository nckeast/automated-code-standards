Class User.Example Extends %Persistent
{

Property Description As %String;

ClassMethod Method1(Parameter As %String) As %Status
{
	set var = $piece($get(^DATA(Parameter)), "|", 3)
	if 'var quit $$$OK
	
	set (code, desc) = ""
	for {
		set code = $order(^INDEX(var, code), 1, data)
		if code = "" quit  // 
		
		set desc = $piece(data, "|")
	}
	
	set cat = %session.Get("cat")
	
	&SQL(
		SELECT %ID
		INTO :id
		FROM SQLUser.Example
		WHERE Description = :desc
		)
}

ClientMethod Method2(Parameter As %String) [ Language = javascript ]
{
	var row = 0, col = 0
	
	switch(Parameter) {
		case 1:
			var col = 1;
			this.toggle(row, col);
			break;
		case 2:
			var row = 1;
			this.toggle(row, col);
			break;
		case 2:
			row = 1;
			col = 1;
			this.toggle(row, col);
			break;
		default:
			break;
	}
}

Storage Default
{
<Data name="ExampleDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Description</Value>
</Value>
</Data>
<DataLocation>^User.ExampleD</DataLocation>
<DefaultData>ExampleDefaultData</DefaultData>
<IdLocation>^User.ExampleD</IdLocation>
<IndexLocation>^User.ExampleI</IndexLocation>
<StreamLocation>^User.ExampleS</StreamLocation>
<Type>%Library.CacheStorage</Type>
}

}

