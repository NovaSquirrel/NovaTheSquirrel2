import PIL, sys
from PIL import Image

im = Image.open("tilesets2/DialogNameFont.png")

# Do the enum in a separate file because I can't export enums
outfile = open("src/namefontwidth.s", "w")
outfile.write('; This is automatically generated. Edit "namefontwidthtable.py"\n')
outfile.write('.segment "Dialog"\n')
outfile.write('.export DialogNameFontWidths\n')
outfile.write('DialogNameFontWidths:\n')

for i in range(im.height//16):
	imtile = im.crop((0, i*16, 8, i*16+8)).getdata()
	width = 0
	# Find out how wide the character is
	for px in range(8):
		for py in range(8):
			if imtile[py*8+px]:
				width = px+1
	outfile.write('  .byt %d\n' % (width+1))
outfile.close()
