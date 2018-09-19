Class User.IndentationCheck Extends %RegisteredObject
{

/// This Parameter is updated by Perforce
Parameter SrcVer = "$Id$";

ClassMethod One() As %Status
{
	 if ##class(User.LBCF).LBCFConfidentialPrintingSiteGetStored(1) = "R" {  // Confidential courier site from Episode
 	set siteid = lbep.LBEPLabSiteDRGetObjectId(), reason = reason _ " EPSite=" _ lbep.LBEPLabSiteDR.CTLOCCode }
}

ClassMethod Two()
{
 do ..SetEpisodeReporting(EP("DR01"), 10, , , TP("MP1"), , 
 	"Mark J Pybus", "Sydney", CR("DRCC00"))                                                                                              // EPR("DR01|10")
 do ..SetEpisodeReporting(EP("DR01"), 11, , , TP("MP2"), , 
 	"Mark NoCourier Pybus", "Sydney")
 set myvariable = "blah blah blah"
 	_ "and more blah blah blah"
 	_ "cat in the hat"
}

ClassMethod Three()
{
 set dr = "" for {
 	set dr = $order(^CTPCP(dr), -1) quit:dr=""
 	if $order(^CTPCP(dr, "")) = "KEYW" && ($order(^CTPCP(dr, "KEYW")) = "") {kill ^CTPCP(dr)}
 	else {quit}}
 for {
 	set a = $order(^User.LBCTestItemD(a)) quit:a=""
 	for {
 		set a2=$order(^User.LBCTestItemD(a, "Ranges", a2)) quit:a2=""
 		set b=$order(^User.LBCTestItemD(a, "Ranges", a2, "Machine", ""), -1)
 		if b > m set m = b}}
}

ClassMethod Four()
{
 #if @..#LABTRAK
 	&SQL(INSERT INTO SQLUser.CT_Courier (CTCR_Code,CTCR_RunDesc,CTCR_Confidential,CTCR_UserSite_DR,CTCR_TimeSlot)
 		VALUES (:code,:desc,:confidential,:confsite,:timeslot)) set CR(code) = %ROWID break:SQLCODE
 	if $length(schedule) {for i = 1:1:$length(schedule, ",") {
 			set s = $piece(schedule, ",", i), fromtime = $piece(s, "-", 1), totime = $piece(s, "-", 2) if totime = "" break
 			&SQL(INSERT INTO SQLUser.CT_CourierSchedule (CTCRS_ParRef,CTCRS_Sequence,CTCRS_TimeStart,CTCRS_TimeEnd)
 				VALUES (:CR(code),:i,:fromtime,:totime))         set CRS(code _ "||" _ i) = %ROWID break:SQLCODE  }}
 #else
 	set cr=##class(User.LBCCourier).%New()
}

ClassMethod Five()
{
 write !?3, "TestSet ", 
 	tsid, " LBCTS=", 
 	ts.LBTSTestSetDR.%Id(), 
 	" ", ts.LBTSTestSetDR.LBCTSCode, 
 	" Seq=", ts.LBTSTestSetSeq, " Status=", ts.LBTSStatusResult
 if 0 {
 	write !?3, "TestSet ", 
 		tsid, " LBCTS="
 }
}

ClassMethod Six()
{
 &SQL(SELECT DISTINCT list(LBTS_Episode_DR)
 	INTO :qLBEpisodeList
 	FROM SQLUser.LB_TestSet
 	WHERE LBTS_Episode_DR->LBEP_PAAdm_DR->PAADM_PAPMI_DR=:qPatientID
 	AND ((LBTS_Episode_DR->LBEP_CollectionDate<:qLastCollectionDate)
 		OR (LBTS_Episode_DR->LBEP_CollectionDate=:qLastCollectionDate
 			AND (LBTS_Episode_DR->LBEP_CollectionTime<=:qLastCollectionTime OR :qLastCollectionTime IS NULL))
 		OR (:qLastCollectionDate IS NULL)
 	)
 	ORDER BY LBTS_Episode_DR->LBEP_CollectionDate,LBTS_Episode_DR->LBEP_CollectionTime)
}

ClassMethod Seven()
{
 // Keep the dot structure count before checking DecIndent
 if +$get(Handle("&sql(")) || (+$get(Handle("&js<"))) || (+$get(Handle("&html<"))) {
 	set dotCount = +$get(Handle("."))
 } else {
 	set dotCount = 0
 }
}

ClassMethod Nine()
{
 // if (bad) {
 // }

 &SQL(SELECT * INTO :arr FROM Cat_In_The_Hat)
 if ($h)	// If using comment after condition
 {
 	write "dog"
 }

 // Comment prior to if statement
 if ($h) {
 	write "dog"
 }
 for {
 	quit
 }
}

ClassMethod Ten()
{
 if 1 {
 } else {
 	if (resultType = "S") { // STANDARD COMMENT (TEST ITEM COMMENT)
 		set ok = ..StandardCommentResultBroker(Result, LBTestSetItemID, .msgLBTSI)
 		if $$$ISERR(ok) quit 0
 	} elseif (resultType = "MP") {  // MICRO PATHOGENS
 		set ok = ..MicroPathogenResultBroker(Result, LBTestSetItemID, .msgLBTSI)
 		if $$$ISERR(ok) quit 0
 	} elseif (resultType = "D") { // DATE
 		set msgLBTSI.LBTSIResultDate = ##class(websys.Conversions).DateHtmlToLogical(Result)
 		set msgLBTSI.LBTSIResultClassName = "%Date"
 	} elseif (resultType = "T") { // TIME
 		set msgLBTSI.LBTSIResultTime = ##class(websys.Conversions).TimeHtmlToLogical(Result)
 		set msgLBTSI.LBTSIResultClassName = "%Time"
 	} elseif (resultType = "YN") { // YES/NO lookup
 		set msgLBTSI.LBTSIResultYesNo = ##class(websys.StandardTypeItem).GetIdFromCodeOrDescription("YESNO", Result)
 		set msgLBTSI.LBTSIResultClassName = "YESNO"
 	} elseif (resultType = "XY") {
 		// Extend here...
 	} else {
 		set msgLBTSI.LBTSIResultClassName = "%String"
 	}
 	
 	set msgLBTSI.LBTSIValue = Result
 	set sc = msgLBTSI.%Save()
 	if $$$ISERR(sc) quit 0
 }
}

ClassMethod Eleven()
{
 if 1 {
 	do ..Cat() } elseif 0 { do ..Dog()
 	do ..Cat() } elseif 1 {
 	set x = $h}
 set y = x
 quit 0
}

ClientMethod Twelve() [ Language = javascript ]
{
 _svgOverlay = new Array();
 var svg = zen('svgCanvas');
 
 //Create a group for Overlay
 var group = svg.document.getElementById('ConditionOverlay');
 if (group) {
 	for (var child = group.firstChild; child != null; child = group.firstChild) {
 		group.removeChild(child);
 	}
 } else {
 	var group = svg.document.createElementNS(SVGNS,'g');
 	svgGroup.appendChild(group);
 	group.setAttribute('id','ConditionOverlay');
 }
 
 for (var i in _svgIndex)
 {
 	switch (_svgIndex[i].baseClass) {
 		case 'rectCondition':
 		case 'rectOperator':
 		case 'rectConditionRow':
 			this.drawOverlayNode(group,_svgIndex[i].group);
 			break;
 		default:
 			break;
 	}
 }
}

ClassMethod Thirteen()
{
 &SQL(
 	DECLARE MRObservations CURSOR FOR
 	SELECT OBS_RowID,OBS_Item_DR,OBS_Value,OBS_Date,
 		OBS_Time,OBS_User_DR->SSUSR_Name,OBS_ShortDesc,OBS_Item_DR->ITM_InputType,
 		OBS_Item_DR->ITM_LowRange,OBS_Item_DR->ITM_HighRange, OBS_OEExec_DR, OBS_Item_DR->ITM_Code,
 		OBS_IsPartogram
 	FROM   MR_Observations
 	WHERE  ({fn CONCAT( '^', {fn CONCAT((:mradm),'^')})} [ {fn CONCAT( '^', {fn CONCAT((%INTERNAL(OBS_ParRef)),'^')})})
 	AND OBS_Item_DR = :itm
 	ORDER BY OBS_Date DESC,OBS_Time DESC
 	)
 // "^"_:mradm_"^") [ ("^"_%INTERNAL(OBS_ParRef)_"^")
 //
}

ClientMethod Fourteen() [ Language = javascript ]
{
 if (/\{\}/) { var a=1
 	var b=2
 	var c=3 }
 else {
 }
 test = function () { asd
 }
}

ClassMethod Fifteen()
{
zDisplayVerificationWorkFlow(LBTestSetID="") public {
 	for i = 1:1:length {
 		set actualVerificationQueueID=$listget(actualVerificationQueueList, i)
 		set actualVerificationQueueDesc = "" if actualVerificationQueueID '= "" set actualVerificationQueueDesc = ##class(User.LBCQueue).LBCQDescGetStored(actualVerificationQueueID)
 		if actualVerificationQueueDesc '= "" {
 			write "<td align='right'>", $char(13, 10)
 			if i = curPos write "<b>"
 			write actualVerificationQueueDesc
 			if i = curPos write "</b>"
 			write "</td>", $char(13, 10)
 			write "<td>></td>"
 		}
 	}
 	quit 1
 }
zGetAuditDisplayInfo(aryColInfo)
 set aryColInfo("LBTSQT_INDATE") = "##Class(websys.Conversions).DateLogicalToHtml(val)"
 set aryColInfo("LBTSQT_INTIME") = "##Class(websys.Conversions).TimeLogicalToHtml(val)"
 set aryColInfo("LBTSQT_INUSER") = "##Class(web.SSUser).GetCodeDescriptionFromId(id)"
 set aryColInfo("LBTSQT_OUTDATE") = "##Class(websys.Conversions).DateLogicalToHtml(val)"
 set aryColInfo("LBTSQT_OUTTIME") = "##Class(websys.Conversions).TimeLogicalToHtml(val)"
 set aryColInfo("LBTSQT_OUTUSER") = "##Class(web.SSUser).GetCodeDescriptionFromId(id)"
 set aryColInfo("LBTSQT_QUEUE_DR") = "##Class(web.LBCQueue).GetCodeDescriptionFromId(id)"
 quit
}

ClientMethod Sixteen(obj) [ Language = javascript ]
{
 // Todo: refactor
 switch(true) {
 	case /^O_ConditionRow/.test(obj.id):
 		var row = obj.id.split('O_ConditionRow')[1];
 		this.toggleObject(_svgIndex['ConditionRow'+row].group);
 		this.toggleConditionOption(row);
 		break;
 	case /^O_Condition/.test(obj.id):
 		var id = obj.id.split('O_Condition')[1];
 		this.toggleObject(_svgIndex['Condition'+id].group);
 		this.toggleConditionEdit(id);
 		break;
 	case /^O_Operator/.test(obj.id):
 		var id = obj.id.split('Operator')[1];
 		var row = id.split('_')[0];
 		var col = id.split('_')[1];
 		this.toggleOperator(row,col);
 		break;
 	case /^Event/.test(obj.id):
 		this.toggleObject(obj);
 		this.toggleEventEdit();
 		break;
 	case /^ConditionHead/.test(obj.id):
 		this.toggleObject(obj);
 		this.toggleConditionEdit('',0);
 		break;
 	case /^ActionHead/.test(obj.id):
 		this.toggleObject(obj);
 		this.toggleActionEdit('');
 		break;
 	case /^Action/.test(obj.id):
 		this.toggleObject(obj);
 		var id = obj.id.split('Action')[1];
 		this.toggleActionEdit(id);
 		break;
 	default:
 		break;
 }
}

ClassMethod Seventeen()
{
 set LBCWorksheetProperties = $listbuild(
 $listbuild("LBCWSMaxEpisodesPerSheet", 4), 
 	$listbuild("LBCWSLabSiteRestrictionDR", ""), 
 	$listbuild("LBCWSCloseOnPrinting", "N"), 
 	$listbuild("LBCWSAddItemsToClosedWorksheets", "N"))
}

/*
/// Eighteen
/// This cannot be tested from within a class.  It needs to be in a JavaScript file.
/// The braces in the regular expression should not affect the parsing.
function getFunction(func)
{
	var f = func.toString();
	var a = f.match(/^function\W*(.*[(](.*)[)])/i);
	
	//if function doesn't have name.
	if (a[1].match(/^[(].*[)]$/))
	{
		a[1] = f.match(/^function[^{]*[{]((?:.|\s)*)[}]\s*$/i)[1];
	}
	
	return a;
}
*/
ClientMethod Nineteen() [ Language = javascript ]
{
 console.debug(type)
 switch(type) {
 	case 9:
 		// inverted triangle
 		var marker = this.document.createElementNS(SVGNS,'path');
 		var d = 'M' + (x + (this.MarkerSize/2.0)) + ' ' + (y + (this.MarkerSize/2.0)) + ' h ' + (-this.MarkerSize) + ' l ' + (this.MarkerSize/2.0) + ' ' + (-this.MarkerSize) + ' Z';
 		marker.setAttribute('d', d);
 		break;
 	case 3:
 		//triangle
 		var marker = this.document.createElementNS(SVGNS,'path');
 		var d = 'M' + (x + (this.MarkerSize/2.0)) + ' ' + (y - (this.MarkerSize/2.0)) + ' h ' + (-this.MarkerSize) + ' l ' + (this.MarkerSize/2.0) + ' ' + (this.MarkerSize) + ' Z';
 		marker.setAttribute('d', d);
 		break;
 	case 2:
 		// circle
 		var marker = this.document.createElementNS(SVGNS,'circle');
 		marker.setAttribute('cx', x);
 		marker.setAttribute('cy', y);
 		marker.setAttribute('r', this.MarkerSize/2.0);
 		break;
 	case 4:
 		// diamond
 		var marker = this.document.createElementNS(SVGNS,'path');
 		var d = 'M' + (x+ (this.MarkerSize/2.0)) + ' ' + y + ' l '+ (-this.MarkerSize/2.0) + ' ' + (-this.MarkerSize/2.0)+ ' l '+ (-this.MarkerSize/2.0) + ' ' + (this.MarkerSize/2.0)+ ' l '+ (this.MarkerSize/2.0) + ' ' + (this.MarkerSize/2.0) +' Z';
 		marker.setAttribute('d', d);
 	case 6:
 		// rect
 		var marker = this.document.createElementNS(SVGNS,'line');
 		marker.setAttribute('x1',-(this.MarkerSize/2.0));
 		marker.setAttribute('x2',(this.MarkerSize/2.0));
 		marker.setAttribute('y1',0);
 		marker.setAttribute('y2',0);
 		
 		break;
 		break;
 	case 8:
 		// cross
 		var marker = this.document.createElementNS(SVGNS,'g');
 		var line1 = this.document.createElementNS(SVGNS,'line');
 		var line2 = this.document.createElementNS(SVGNS,'line');
 		line1.setAttribute('x1', (this.MarkerSize/2.0));
 		line1.setAttribute('y1', 0);
 		line1.setAttribute('x2', (this.MarkerSize/2.0));
 		line1.setAttribute('y2', (this.MarkerSize));
 		line2.setAttribute('y1', (this.MarkerSize/2.0));
 		line2.setAttribute('x1', 0);
 		line2.setAttribute('y2', (this.MarkerSize/2.0));
 		line2.setAttribute('x2', (this.MarkerSize));
 		marker.appendChild(line1);
 		marker.appendChild(line2);
 		break;
 	case 10:
 		// 'cube'
 		var marker = this.document.createElementNS(SVGNS,'path');
 		var d = 'M' + (x+ (this.MarkerSize/2.0)) + ' ' + (y + (this.MarkerSize/4.0)) + ' l 0 ' + (-this.MarkerSize/4.0)  + ' l 0 ' + (- (this.MarkerSize/4.0));
 		d = d + ' l ' + (-this.MarkerSize/2.0)+ ' ' + (-this.MarkerSize/4.0)+ ' l ' + (-this.MarkerSize/2.0)+ ' ' + (this.MarkerSize/4.0)+ ' l 0 ' + (this.MarkerSize/2.0)+ ' l ' + (this.MarkerSize/2.0) + ' ' + (this.MarkerSize/4.0)+" Z";
 		marker.setAttribute('d', d);
 		break;
 	default:
 		// rect
 		var marker = this.document.createElementNS(SVGNS,'rect');
 		marker.setAttribute('width',(this.MarkerSize));
 		marker.setAttribute('height',(this.MarkerSize));
 		marker.setAttribute('rx',2);
 		break;
 }
 if (type!=8){
 	marker.setAttribute('x',x-(this.MarkerSize/2.0));
 	marker.setAttribute('y',y-(this.MarkerSize/2.0));
 }else{
 	marker.setAttribute('transform','translate('+(x-(this.MarkerSize/2.0))+','+(y-(this.MarkerSize/2.0))+')');
 }
 marker.setAttribute('class','marker');
 marker.setAttribute('titlex',titleText);
 marker.addEventListener('mouseover',zen('graph').showTitle,false);
 marker.addEventListener('mouseout',zen('graph').hideTitle,false);
 marker.setAttribute("style","stroke:"+color);
 graphGroup.appendChild(marker);
}

Trigger Eight
{
 #define className ##expression(""""_%classname_"""")
 #define storageName $$$defClassKeyGet(%classname, $$$cCLASSstoragestrategy)
 #if $$$comMemberKeyGet(%classname, $$$cCLASSparameter, "GUIDENABLED", $$$cPARAMdefault)
 	try {
 		#if $length($$$defClassKeyGet(%classname, $$$cCLASSstoragestrategy))
 			#if $length($$$defMemberKeyGet(%classname, $$$cCLASSstorage, $$$storageName, $$$cSDEFidlocation))
 				#define idLocation ##expression($$$defMemberKeyGet(%classname, $$$cCLASSstorage, $$$storageName, $$$cSDEFidlocation))
 				if $get(%xmlconfigitem) {
 					// Child object.
 					// Ensure that any child id counter is equal or greater than this object id.
 					if $order($$$idLocation) = "" {
 						kill $$$idLocation
 					}
 				}
 			#endif
 		#endif
 		if '$data(%ChangeControl) do ##class(TC.ChangeControl.Interface).ChangeControlCreate($select($isobject($get(%session)):$get(%session.Data("LOGON.USERID")), 1:""))
 		if $isobject($get(%ChangeControl)) {
 			new oid, sc
 			// %d(1) used to access row id.
 			// The column name will vary between tables.
 			set oid = $$$oidCompose(%d(1), $$$className)
 			set sc = %ChangeControl.%AfterDeleteTrigger(oid)
 			if $$$ISERR(sc) set %ok = 0, %msg = $system.Status.GetErrorText(sc)
 		}
 	} catch {
 		do BACK^%ETN
 	}
 #endif
 
 quit
}

}

