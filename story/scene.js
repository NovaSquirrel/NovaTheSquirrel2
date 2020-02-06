const specialChars = {
	"curlyl": "{".charCodeAt(0),
	"curlyr": "}".charCodeAt(0),
	"buttona":    0x80,
	"buttonb":    0x81,
	"buttonx":    0x82,
	"buttony":    0x83,
	"arrowup":    0x84,
	"arrowdown":  0x85,
	"arrowleft":  0x86,
	"arrowright": 0x87,
	"heart":      0x88,
	"heartfull":  0x89,
	"copyright":  0x8a,
	"registered": 0x8b,
	"trademark":  0x8c,
	"star":       0x8d,
	"check":      0x8e,
	"eyes":       0x8f,
	"buttonl":    0x90,
	"buttonr":    0x91,
	"smile":      0x92,
	"frown":      0x93,
	"mad":        0x94,
	"meh":        0x95,
	"thumbsup":   0x96,
	"thumbsdown": 0x97,
	"think":      0x98,
	"flipsmiley": 0x99,
	"pawprint":   0x9a
};

// Process the font data first
fontCanvas = {};
for(fontName in fontVWF) {
	function makeCanvas(w, h, color, variant) {
		let c = document.createElement("canvas");
		let ctx = c.getContext("2d");
		c.width = w;
		c.height = h;
		let data = ctx.getImageData(0, 0, w, h);
		function put(x, y) {
			let red = y * (w*4) + x*4;
			data.data[red+0] = color[0];
			data.data[red+1] = color[1];
			data.data[red+2] = color[2];
			data.data[red+3] = 255;
		}
		function drawRegular(i) {
			let baseX = (i&15)*8;
			let baseY = (i>>4)*8;
			for(j=0; j<8; j++) {
				let row = inData[i][j];
				for(k=0; k<8; k++) {
					if(row & (1 << (7-k))) {
						put(baseX+k, baseY+j);
					}
				}
			}
		}
		function drawWide(i) {
			let baseX = (i&15)*16;
			let baseY = (i>>4)*8;
			for(j=0; j<8; j++) {
				let row = inData[i][j];
				for(k=0; k<8; k++) {
					if(row & (1 << (7-k))) {
						put(baseX+k*2+0, baseY+j);
						put(baseX+k*2+1, baseY+j);
					}
				}
			}
		}
		function drawBig(i) {
			let baseX = (i&15)*16;
			let baseY = (i>>4)*16;
			for(j=0; j<8; j++) {
				let row = inData[i][j];
				for(k=0; k<8; k++) {
					if(row & (1 << (7-k))) {
						put(baseX+k*2+0, baseY+j*2+0);
						put(baseX+k*2+1, baseY+j*2+0);
						put(baseX+k*2+0, baseY+j*2+1);
						put(baseX+k*2+1, baseY+j*2+1);
					}
				}
			}
		}
		theDraw = [drawRegular, drawWide, drawBig][variant];

		// draw each character
		let inData = fontVWF[fontName]["data"];
		for(let i=0; i<inData.length; i++) {
			theDraw(i);
		}
		ctx.putImageData(data, 0, 0);
		return c;
	}

	fontCanvas[fontName] = {};
	fontCanvas[fontName]["black"] = makeCanvas(128, 128, [0,0,0],   0);
	fontCanvas[fontName]["red"]   = makeCanvas(128, 128, [255,0,0], 0);
	fontCanvas[fontName]["blue"]  = makeCanvas(128, 128, [0,0,255], 0);
	fontCanvas[fontName]["wide"]  = makeCanvas(256, 128, [0,0,0],   1);
	fontCanvas[fontName]["big"]   = makeCanvas(256, 256, [0,0,0],   2);
}

const screenChoices = {
	"dialog": {
		"baseX": 66,
		"baseY": 23,
		"template": "template"
	},
	"inventory": {
		"baseX": 65,
		"baseY": 171,
		"template": "inventory"
	}
};

function updatePreview() {
	const screenChoice = screenChoices[document.getElementById('screenChoice').value];
	const script = document.getElementById("script");
	const canvas = document.getElementById("preview");
	const font1 = fontCanvas["BaseSeven"]["black"]
	const font2 = fontCanvas["BaseSeven"]["red"]
	const font3 = fontCanvas["BaseSeven"]["blue"]
	const fontwide = fontCanvas["BaseSeven"]["wide"];
	const fontzoom = fontCanvas["BaseSeven"]["big"];
	const ctx = canvas.getContext('2d');

	const textBaseX = screenChoice["baseX"];
	const textBaseY = screenChoice["baseY"];

	ctx.drawImage(document.getElementById(screenChoice["template"]), 0, 0);
	let font = font1;
	let fontWidth = fontVWF["BaseSeven"]["width"];

	let CurrentX = 0, CurrentY = 0, wide = false, big = false;
	const userText = script.value;
	for(let i = 0; i < userText.length; i++) {
		c = userText.charAt(i);
		code = userText.charCodeAt(i);

		hasChar = false;
		if(c == '{') {
			// Skip to the next } but get the stuff inside of it
			index = userText.indexOf("}", i);
			if(index == -1)
				continue;
			command = userText.slice(i+1, index).split(" ");
			i = index;

			switch(command[0].toLowerCase()) {
				case 'c1':
					font = font1;
					wide = false;
					big = false;
					break;
				case 'c2':
					font = font2;
					wide = false;
					big = false;
					break;
				case 'c3':
					font = font3;
					wide = false;
					big = false;
					break;
				case 'wide':
					font = font1;
					wide = true;
					big = false;
					break;
				case 'big':
					font = font1;
					wide = false;
					big = true;
					break;
				case 'x':
					CurrentX = parseInt(command[1]);
					break;
				case 'xy':
					CurrentX = parseInt(command[1]);
					CurrentY = parseInt(command[2]);
					break;
				default:
					if(command[0].toLowerCase() in specialChars) {
						code = specialChars[command[0].toLowerCase()];
						hasChar = true;
					}
					break;
			}

			if(!hasChar)
				continue;
		}
		else if(c == '\n') {
			CurrentX = 0;
			CurrentY += 8;
			continue;
		}
		if(!wide && !big) {
			drawCharacter(ctx, font, code-0x20, textBaseX+CurrentX, textBaseY+CurrentY);
			CurrentX += fontWidth[code-0x20];
		} else if(wide) {
			drawCharacterWide(ctx, fontwide, code-0x20, textBaseX+CurrentX, textBaseY+CurrentY);
			CurrentX += fontWidth[code-0x20] * 2;
		} else if(big) {
			drawCharacterBig(ctx, fontzoom, code-0x20, textBaseX+CurrentX, textBaseY+CurrentY);
			CurrentX += fontWidth[code-0x20] * 2;
		}
	}
}

function drawCharacter(ctx, font, character, x, y) {
	ctx.drawImage(font, (character&15)*8, (character>>4)*8, 8, 8, x, y, 8, 8);
}

function drawCharacterWide(ctx, font, character, x, y) {
	ctx.drawImage(font, (character&15)*16, (character>>4)*8, 16, 8, x, y, 16, 8);
}

function drawCharacterBig(ctx, font, character, x, y) {
	ctx.drawImage(font, (character&15)*16, (character>>4)*16, 16, 16, x, y, 16, 16);
}

