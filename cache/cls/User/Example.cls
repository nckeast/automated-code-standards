Class User.Example Extends %Persistent
{

Property Code As %String;

Property Description As %String;

ClassMethod Method1(Parameter As %String) As %Status
{
	s var = $p($get(^DATA(Parameter)), "|", 3)
	i 'var quit $$$OK
	
	set (code,desc) =""
	f {
		s code = $o(^INDEX(var,code), 1,data)
		if code ="" quit  ; 
		
		set desc=$piece(data,"|")
	}
	
	s code= %session.Get("code")
	
	&SQL(
	select %ID
		INTO :id
		from SQLUser.Example
		WHERE Description = :desc
		AND :code IN (
			select Code 
			FROM SQLUser.Example
		)
		)
}

/// generate Fibonacci sequences
ClassMethod Fibonacci()
{
    r !, "Generate Fibonacci sequence up to where? ", upto
    
    set t1=1, t2 = 1,fib=1
    w !
    d {
        write fib,"  "
        set fib=t1+t2,t1=t2,t2=fib
    }
    while (fib'>upto)
    set t1 = 1, t2 = 1, fib = 1
    write !
    while (fib'>upto){
        w fib,"  "
        set fib = t1 + t2, t1 = t2, t2 = fib
    }
}

ClientMethod Method2(Parameter As %String) [ Language = javascript ]
{
	function sample() {
		var arr
		for (var i=0;i++;i<10) {
			arr[i]="";
			}
			return arr;
	}
	
	// 
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

ClassMethod AddAdressen(intRange As %Integer = 2500)
{
                s sql="select id from vms_marketing.aktionskopf"
                $$$MakeRS(sql,rs)
                While rs.Next()
                {
                               D ..AddAdressenKopf(rs.Get("ID"),$RANDOM(intRange))
                }
                $$$CloseRS(rs)
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

