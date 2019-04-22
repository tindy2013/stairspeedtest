var page = require('webpage').create(),
    system = require('system'),
    address, output;

if (system.args.length < 3 || system.args.length > 3) {
    console.log('Usage: simplerender.js URL filename');
    phantom.exit(1);
} else {
    address = system.args[1];
    output = system.args[2];
	page.viewportSize = {width:1,height:1};
	page.open(address, function (status) {
		if (status !== 'success') {
		console.log('Unable to load the address!');
		phantom.exit(1);
		} else {
			window.setTimeout(function () {
				//page.paperSize = {width:page.viewportSize.width,height:page.viewportSize.height,margin:'0px'}; //not working
				page.render(output);
				phantom.exit();
			}, 200);
		}
    });
}