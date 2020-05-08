#!/usr/bin/env python3
import PIL, glob, os
from PIL import Image

outfile = open("src/vwf_fontdata.s", "w")
outfile.write('; This is automatically generated. Edit "makefont.py" or the font graphics instead\n')
outfile.write('.segment "Dialog"\n')

def process_font(font_name):
	im = Image.open("tools/fonts/" + font_name + ".png")
	sheet_width = im.width // 8
	sheet_height = im.height // 8
	glyph_data = []
	glyph_width = []

	for ch in range(sheet_height):
		for cw in range(sheet_width):
			base_x = cw * 8
			base_y = ch * 8
			imtile = im.crop((base_x, base_y, base_x+8, base_y+8)).getdata()
			width = 0
			pixel_data = []
			for py in range(8):
				pixel_row = 0
				for px in range(8):
					pixel = imtile[py*8+px]
					if pixel > 0:
						width = max(width, px+1)
					if pixel > 1:
						pixel_row |= 1 << (7-px)
				pixel_data.append(pixel_row)
			glyph_data.append(pixel_data)
			glyph_width.append(width)
	im.close()

	outfile.write('.export VWF_%s_FontData, VWF_%s_FontWidth\n' % (font_name, font_name))
	outfile.write('VWF_%s_FontData:\n' % font_name)
	for char in glyph_data:
		outfile.write('  .byt %s\n' % ','.join([str(x) for x in char]))
	outfile.write('VWF_%s_FontWidth:\n' % font_name)
	for char in glyph_width:
		outfile.write('  .byt %d\n' % char)

process_font('BaseSeven')
outfile.close()
