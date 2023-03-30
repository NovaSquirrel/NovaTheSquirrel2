#!/usr/bin/env python3
import math

"""
	L0 to L1 defines the area of the screen to be covered by the perspective effect.
	S0, S1, and SH are the top, bottom, and height of a trapezoid view frustum, this is an area on the 1024x1024 mode 7 texture map that will be visible in this perspective

	Setup:
		ZR0 = 1/S0
		ZR1 = 1/S1
		SA = (256 * SH) / (S0 * (L1 - L0)), or SA = 1 if automatic (SH=0)
	Per-line:
		zr = lerp(ZR0,ZR1,(line-L0)/(L1-L0))
		z = 1 / zr
		a = z *  cos(angle)
		b = z *  sin(angle) * SA
		c = z * -sin(angle)
		d = z *  cos(angle) * SA
"""

def lerp(a, b, t):
	return (1 - t) * a + t * b

def to_fixed(f):
	return int(round(f*256)) & 0xffff

def perspective(angle, l0, l1, s0, s1):
	zr0 = 1/s0
	zr1 = 1/s1

	m7a, m7b, m7c, m7d = [], [], [], []

	lines = (l1-l0)
	for i in range(lines):
		zr = lerp(zr0, zr1, i/lines)
		z = 1 / zr
		m7a.append(to_fixed(z *  math.cos(angle)))
		m7b.append(to_fixed(z *  math.sin(angle)))
		m7c.append(to_fixed(z * -math.sin(angle)))
		m7d.append(to_fixed(z *  math.cos(angle)))
	return (m7a, m7b, m7c, m7d)

def output_tables():
	outfile = open("src/perspective_data.s", "w")

	angles    = 256

	outfile.write('; This is automatically generated. Edit "perspective.py" instead\n')
	outfile.write('.export perspective_m7a_m7b_list, perspective_m7c_m7d_list, perspective_abcd_banks\n')

	outfile.write('.segment "C_Mode7Game"\n')
	outfile.write('perspective_m7a_m7b_list:\n')
	for a in range(angles):
		outfile.write('  .addr .loword(perspective_m7a_m7b_%d)\n' % a)

	outfile.write('perspective_m7c_m7d_list:\n')
	for a in range(angles):
		outfile.write('  .addr .loword(perspective_m7c_m7d_%d)\n' % a)

	outfile.write('perspective_abcd_banks:\n')
	outfile.write('  .byt ^perspective_m7a_m7b_0,   ^perspective_m7c_m7d_0\n')
	outfile.write('  .byt ^perspective_m7a_m7b_64,  ^perspective_m7c_m7d_64\n')
	outfile.write('  .byt ^perspective_m7a_m7b_128, ^perspective_m7c_m7d_128\n')
	outfile.write('  .byt ^perspective_m7a_m7b_192, ^perspective_m7c_m7d_192\n')

	table_id = -1
	for a in range(angles):
		table_id += 1

		angle = (a/angles)*2*math.pi
		m7a, m7b, m7c, m7d = perspective(angle, 48, 224, 384/256, 64/256)

		outfile.write('.segment "Mode7TblAB%d"\n' % (a//64))
		outfile.write('perspective_m7a_m7b_%d:\n' % table_id)
		for i in range(len(m7a)):
			outfile.write('  .word $%.4x ;A\n' % (m7a[i]))
			outfile.write('  .word $%.4x ;B\n' % (m7b[i]))

		outfile.write('.segment "Mode7TblCD%d"\n' % (a//64))
		outfile.write('perspective_m7c_m7d_%d:\n' % table_id)
		for i in range(len(m7a)):
			outfile.write('  .word $%.4x ;C\n' % (m7c[i]))
			outfile.write('  .word $%.4x ;D\n' % (m7d[i]))

	outfile.close()
output_tables()
