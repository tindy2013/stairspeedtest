function  orderByName(sTableID, iCol) {
	var  oTable = document.getElementById(sTableID);
	var  oTBody = oTable.tBodies[0];
	var  colDataRows = oTBody.rows;
	var  aTRs =  new  Array;
	for  (  var  i = 0; i < colDataRows.length; i++) {
		aTRs[i] = colDataRows[i];
	}
	if  (oTable.sortCol == iCol) {
		aTRs.reverse();
	}  else  {
		aTRs.sort(speedCompare(iCol));
	}
	var  oFragment = document.createDocumentFragment();
	for  (  var  j = 0; j < aTRs.length; j++) {
		oFragment.appendChild(aTRs[j]);
	}
	oTBody.appendChild(oFragment);
	oTable.sortCol = iCol;
}

function getSpeed(speed){
	var value=parseFloat(speed.toString().slice(0,-2));
	if(speed.toString().slice(-2)=="MB") value*=1024;
	return value;
}

function speedCompare(iCol){
	return function Compare(speed1,speed2){
		var vValue1 = parseFloat(getSpeed(speed1.cells[iCol].firstChild.nodeValue.toString()));
		var vValue2 = parseFloat(getSpeed(speed2.cells[iCol].firstChild.nodeValue.toString()));
		if(vValue1.isNaN) return -1;
		if(vValue2.isNaN) return 1;
		if(vValue1>vValue2) return 1;
		if(vValue1<vValue2) return -1;
		return 0;
	};
}

//remake from https://github.com/NyanChanMeow/SSRSpeed/blob/Dev/SSRSpeed/Result/exportResult.py

var colorgroup=[[255,255,255],[128,255,0],[255,255,0],[255,128,192],[255,0,0]];
var bounds=[0,64,512,4*1024,16*1024];

function useNewPalette() {
	colorgroup=[[255,255,255],[102,255,102],[255,255,102],[255,178,102],[255,102,102],[226,140,255],[102,204,255],[102,102,255]];
	bounds=[0,64,512,4*1024,16*1024,24*1024,32*1024,40*1024];
}

function getColor(lc,rc,level) {
	var colors=[];
	var r,g,b;
	colors.push(parseInt(lc[0]*(1-level)+rc[0]*level));
	colors.push(parseInt(lc[1]*(1-level)+rc[1]*level));
	colors.push(parseInt(lc[2]*(1-level)+rc[2]*level));
	return colors;
}

function rgb2hex(rgb) {
    var reg=/(\d{1,3}),(\d{1,3}),(\d{1,3})/;
    var arr=reg.exec(rgb);
    function hex(x) {
        return ("0" + parseInt(x).toString(16)).slice(-2);
    }
    var _hex="#" + hex(arr[1]) + hex(arr[2]) + hex(arr[3]);
    return _hex.toUpperCase();
}

function getSpeedColor(speed) {
	for(var i=0;i<bounds.length-1;i++) {
		if(speed>=bounds[i]&&speed<=bounds[i+1]) return rgb2hex(getColor(colorgroup[i],colorgroup[i+1],((speed-bounds[i])/(bounds[i+1]-bounds[i]))));
	};
	return rgb2hex(colorgroup[colorgroup.length-1]);
}

function drawcolor() {
	var x = document.getElementsByClassName("speed");
	for(var i=0;i<x.length;i++){
		x[i].bgColor=getSpeedColor(getSpeed(x[i].innerText));
	};
}

function saveAndRemoveRow(id) {
	var idObject = document.getElementById(id);
	if (idObject != null) {
		var retval = idObject.innerHTML;
		if (idObject != null) idObject.parentNode.removeChild(idObject);
		return retval;
	}
}

function addRow(pos,str,id) {
	var table = document.getElementById("table");
	var tr = document.createElement("tr");
	tr=table.insertRow(pos);
	tr.setAttribute("id",id);
	tr.innerHTML=str;
	//table.insertBefore(tr,tr);
}

function loadevent() {
	var gentime=saveAndRemoveRow("gentime");
	saveAndRemoveRow("first");
	orderByName("table",4);
	drawcolor();
	addRow(0,"<td>Group</td><td>Remarks</td><td>Loss</td><td>Ping</td><td>AvgSpeed</td>","first");
	addRow(-1,gentime,"gentime");
}