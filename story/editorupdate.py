import PIL, glob, os
from PIL import Image

outfile = open("vwf_fontdata.js", "w")
outfile.write('// This is automatically generated. Edit "editorupdate.py" or other files instead\n')
outfile.write('let fontVWF = {}\n')

def process_font(font_name):
	im = Image.open("../tools/fonts/" + font_name + ".png")
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

	outfile.write('fontVWF["%s"] = {}\n' % font_name)
	outfile.write('fontVWF["%s"]["data"]  = [%s];\n' % (font_name, ','.join([str(x) for x in glyph_data])))
	outfile.write('fontVWF["%s"]["width"] = [%s];\n' % (font_name, ','.join([str(x) for x in glyph_width])))

process_font('BaseSeven')
outfile.close()
