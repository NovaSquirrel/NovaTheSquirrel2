#!/usr/bin/env python3
import math

raw_tables = True # Don't do premade HDMA tables
sine_only = True # Repeat first 1/4 of the angles; single overlapping sine/cosine table

def perspective(angle, height, scale_x, scale_y):
    """
    angle   - angle to face
    height  - this is the height of the camera above the plane
    scale_x - scale of space coordinates to pixels
    scale_y - scale of space coordinates to pixels
    """
    def to_fixed(f):
        return int(round(f*256)) & 0xffff
   
    m7a, m7b, m7c, m7d = [], [], [], []
    for screen_y in range(224):
        scale_z = 1/((screen_y+1)*0.75)
        
        m7a.append(to_fixed( math.cos(angle) * scale_x * scale_z))
        m7b.append(to_fixed( math.sin(angle) * scale_x * scale_z))
        m7c.append(to_fixed(-math.sin(angle) * scale_y * scale_z))
        m7d.append(to_fixed( math.cos(angle) * scale_y * scale_z))
    return (m7a, m7b, m7c, m7d)

""" HDMA format:
xx Line count
xx * N Data
xx Line count
xx * N Data
xx Line count
xx * N Data
00 Terminate
"""

# Takes a value from 0 to 1
# Returns a value from 0 to 1 with some smoothing?
def smoothing(value):
	value = (2*value-1) * math.pi/2
	value = (math.sin(value)+1)/2
	return value

def output_tables():
	outfile = open("src/perspective_data.s", "w")

	sky_lines = 48
	data_skip = 16
	angles    = 64
	denominator = angles

	quarters = 4
	if sine_only:
		angles += angles//4
		quarters += 1

	outfile.write('; This is automatically generated. Edit "perspective.py" instead\n')
	if raw_tables:
		outfile.write('.export m7a_m7b_list, m7a_m7b_0\n')
	else:
		outfile.write('.export m7a_m7b_list, m7c_m7d_list, m7a_m7b_0, m7c_m7d_0\n')
	outfile.write('.segment "C_Mode7Game"\n')
	outfile.write('m7a_m7b_list:\n')
	for a in range(denominator):
		outfile.write('  .addr .loword(m7a_m7b_%d)\n' % a)
	if not raw_tables:
		outfile.write('m7c_m7d_list:\n')
		for a in range(angles):
			outfile.write('  .addr .loword(m7c_m7d_%d)\n' % a)

	table_id = -1
	for quarter in range(quarters):
		quarter_size = denominator//4
		base_angle = quarter*quarter_size

		for a in range(quarter_size):
			table_id += 1

			desired_angle = base_angle + quarter_size*smoothing(a/quarter_size)
			desired_angle = desired_angle/denominator*2*math.pi
			m7a, m7b, m7c, m7d = perspective(desired_angle, 0, 64, 64)

			if raw_tables:
				if sine_only:
					outfile.write('.segment "Mode7TblAB"\n')
					outfile.write('m7a_m7b_%d:\n' % table_id)
					for i in range(224-sky_lines):
						outfile.write('  .word $%.4x\n' % (m7b[i+data_skip]))
				else:
					outfile.write('.segment "Mode7TblAB"\n')
					outfile.write('m7a_m7b_%d:\n' % table_id)
					for i in range(224-sky_lines):
						outfile.write('  .word $%.4x, $%.4x\n' % (m7a[i+data_skip], m7b[i+data_skip]))
			else:
				outfile.write('.segment "Mode7TblAB"\n')
				outfile.write('m7a_m7b_%d:\n' % table_id)
				outfile.write('  .byte %d\n' % sky_lines)
				outfile.write('  .word 0, 0\n')
				for i in range(224-sky_lines):
					outfile.write('  .byte 1\n')
					outfile.write('  .word $%.4x, $%.4x\n' % (m7a[i+data_skip], m7b[i+data_skip]))
				outfile.write('  .byte 0\n')

				outfile.write('.segment "Mode7TblCD"\n')
				outfile.write('m7c_m7d_%d:\n' % table_id)
				outfile.write('  .byte %d\n' % sky_lines)
				outfile.write('  .word 0, 0\n')
				for i in range(224-sky_lines):
					outfile.write('  .byte 1\n')
					outfile.write('  .word $%.4x, $%.4x\n' % (m7c[i+data_skip], m7d[i+data_skip]))
				outfile.write('  .byte 0\n')

	outfile.close()
output_tables()
