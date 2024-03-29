// TODO: Have this get auto-generated
let gfxlistText = `
0000 FGCommon
0800 FGGrassy
0800 FGGlassTerrain
1200 FGForestStone
0e00 FGTropicalWood
6400 SPCommon
7000 SPWalker
7000 SPWalker2
7000 SPCannon
3000 BGForest
5000 MapBGForest
0100 InventoryBG
3f00 InventoryBG2
4000 InventorySprite
0100 OWGrassy
4000 OWNova
4200 OWLevel
5000 OWGreenery
5000 OWStone
3e00 OWPaths
0000 SolidTiles
4200 Mode7Sprites
1600 FGSmallTrees
1900 FGCommonPalFlowertops
7000 SPFire
7000 SPFire2
7000 SPGeorge
6400 Mode7HUD
3e00 DialogBG
7000 SPMirrorRabbit
7000 SPBomberTree
3800 CurlyFont
6c00 DialogForest
2600 FGSuitLocks
2400 FGSpecialPush
4200 InventoryItem
1400 FGGlassBlocks
1600 FGGlassBlocksGray
3000 BGGlass
5000 MapBGGlass
5000 MapBGHillsMountains
3000 BGHillsMountains
3000 BGLake
5000 MapBGLake
2800 FGHannah
7000 SPHannah
1a00 FGColorfulFlowers
1400 FGWater
1c00 FGCommonPalSand
4800 layer3test
2c00 FGToggleBlocks define
2c00 FGToggleBlocksSwapped define
7000 SPMoai
7000 SPBubble
7000 SPBurgerRider
1d00 FGTreehouse
1c00 FGIndoorDecor
4600 Mode7HUDSprites
7000 SPLife
7000 SPKnuckleSandwich
7000 SPPumpkinBoat
7000 SPStrider
7000 SPSwordSlime
7000 SPStrifeCloud
2f00 FGLineFollowing
7000 SPActorBlocks
7c00 MapBGMode7Clouds
6000 BGMode7Clouds
1e00 FGCliffCave
2200 FGGuideRails
2200 FGGuideRailsCanopy
3000 BGClouds
5000 MapBGClouds
`.split('\n');

let gfxListDestination = {};   // Destination addresses
let gfxListPreload = {};       // Images for each file, to get the height
let gfxListHeight = {};        // Height in pixels of each file
let gfxListAllNames = [];      // All file names sorted by destination

let gfxListAllCheckboxes = []; // Used to uncheck all check boxes
let gfxListAllNameSpans = [];  // Used to reset conflict for all the names
let gfxListCheckboxForFile = {}; // Used to set checkboxes
let gfxListNameSpanForFile = {}; // Used to mark conflict

function pngFromName(name) {
	return "../tilesets4/"+name+".png";
}
function isRenderable(name) {
	return !name.startsWith("BG") && !name.startsWith("MapBG");
}
function compareByDestination(a, b) {
	return gfxListDestination[a] - gfxListDestination[b];
}
for(let i=0; i<gfxlistText.length; i++) {
	let words = gfxlistText[i].split(' ');
	if(words.length < 2)
		continue;
	let fileName = words[1];
	let destination = parseInt(words[0], 16);
	if(isNaN(destination) || destination >= 0xa000)
		continue;

	gfxListDestination[fileName] = destination;

	// Preload the image to get the height, if it's not a background or map
	if(!isRenderable(fileName))
		continue;
	gfxListPreload[fileName] = new Image();
	gfxListPreload[fileName].onload = function(){
		gfxListHeight[fileName] = gfxListPreload[fileName].naturalHeight;
	};
	gfxListPreload[fileName].src = pngFromName(fileName);
	if(!fileName.startsWith("FG"))
		continue;
	gfxListAllNames.push(fileName);
}
gfxListAllNames.sort(compareByDestination);
function setUpCheckboxes() {
	let checkboxes = document.getElementById("checkboxes");
	for(let i=0; i<gfxListAllNames.length; i++) {
		let label = document.createElement("label");
		let checkbox = document.createElement("input");
		checkbox.setAttribute("type", "checkbox");

		// Add or remove the item from the graphics upload list
		checkbox.addEventListener("change", function (e) {
			let fileName = gfxListAllNames[i];
			let gfxUpload = getGfxUploadArray();
			if(gfxUpload === null)
				return;

			if(this.checked && !gfxUpload.includes(fileName)) {
				gfxUpload.push(fileName);				
			} else if(!this.checked){
				let index = gfxUpload.indexOf(fileName);
				if(index > -1) {
					gfxUpload.splice(index, 1);
				}
			}
			setGfxUploadArray(gfxUpload);
			updatePreview();
		});

		gfxListAllCheckboxes.push(checkbox);
		gfxListCheckboxForFile[gfxListAllNames[i]] = checkbox;

		// Image of the file
		let im = new Image();
		im.src = pngFromName(gfxListAllNames[i]);
		label.appendChild(checkbox);
		label.appendChild(im);

		// Name, whose coloring is used to show conflicts
		let name = document.createElement("span");
		name.textContent = gfxListAllNames[i];
		gfxListAllNameSpans.push(name);
		gfxListNameSpanForFile[gfxListAllNames[i]] = name;
		label.appendChild(name);

		label.appendChild(document.createElement("br"));
		checkboxes.appendChild(label);
	}
}

function getGfxUploadArray() {
	try {
		return JSON.parse(document.getElementById("gfxUpload").value);
	} catch (e) {
		console.error(e);
		return null;
	}
}
function setGfxUploadArray(gfx) {
	// Sort by destination address
	if(document.getElementById("autoSort").checked) {
		gfx.sort(compareByDestination);
	}
	document.getElementById("gfxUpload").value = JSON.stringify(gfx);
}
function updatePreview() {
	let gfxUpload = getGfxUploadArray();
	if(gfxUpload === null)
		return;
	setGfxUploadArray(gfxUpload);

	// Uncheck all checkboxes
	for(let i=0; i<gfxListAllCheckboxes.length; i++) {
		gfxListAllCheckboxes[i].checked = false;
	}
	// Don't show any conflicts
	for(let i=0; i<gfxListAllNameSpans.length; i++) {
		gfxListAllNameSpans[i].classList.remove("conflict");
	}

	// Create VRAM space
	let vram = [];
	for(let i=0; i<80; i++) {
		vram.push(null);
	}

	function checkAndMarkConflict(index, use) {
		if(vram[index] !== null) {
			if(vram[index] in gfxListNameSpanForFile)
				gfxListNameSpanForFile[vram[index]].classList.add("conflict");
			if(use in gfxListNameSpanForFile)
				gfxListNameSpanForFile[use].classList.add("conflict");
		}
	}

	for(let i=0; i<gfxUpload.length; i++) {
		let fileName = gfxUpload[i];
		if(fileName in gfxListCheckboxForFile) {
			gfxListCheckboxForFile[fileName].checked = true;
		}

		let destination = gfxListDestination[fileName];
		let index = destination >> 8;

		let height = gfxListHeight[fileName];
		if(height === undefined) {
			height = 1;
		} else {
			height /= 8;
		}
		
		if(index < vram.length) {
			checkAndMarkConflict(index, fileName);
			vram[index] = fileName;
			for(let j=1; j<height; j++) {
				checkAndMarkConflict(index+j, fileName);
				vram[index+j] = true;
			}
		}
	}

	// Clear out the old preview first
	let previewFg = document.getElementById("vramPreviewFg");
	while (previewFg.firstChild) {
		previewFg.removeChild(previewFg.firstChild);
	}
	let previewBg = document.getElementById("vramPreviewBg");
	while (previewBg.firstChild) {
		previewBg.removeChild(previewBg.firstChild);
	}

	// Render the new preview
	for(let i=0; i<vram.length; i++) {
		let preview = (i >= 48) ? previewBg : previewFg;
		let row = vram[i];
		if(row === null) {
			let div = document.createElement("div");
			div.style.width = "128px";
			div.style.height = "8px";
			div.style.background = "gray";
			div.style.opacity = 0.5;
			preview.appendChild(div);
		} else if(row === true) {
			continue;
		} else if(!isRenderable(row)) {
			let div = document.createElement("div");
			div.style.width = "128px";
			div.style.height = "8px";
			div.style.background = "blue";
			div.style.opacity = 0.5;
			preview.appendChild(div);
		} else if(isRenderable(row)){
			let img = new Image();
			img.src = pngFromName(row);
			img.text = row;
			preview.appendChild(img);
		}
	}
}
