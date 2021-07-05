#!/usr/bin/env python3
import math

def output_tables():
	angles = 256

	outfile = open("src/sincos_data.s", "w")

	outfile.write('; This is automatically generated. Edit "makesincos.py" instead\n')
	outfile.write('.export MathSinTable, MathCosTable\n')
	outfile.write('MathCosTable = MathSinTable + %d*2\n' % (angles//4))
	outfile.write('.segment "C_ActorData"\n')
	outfile.write('MathSinTable:\n')

	for angle in range(angles + angles//4):
		a = (angle/angles)*2*math.pi
		v = (int(round(math.sin(a)*0x4000)))
		outfile.write('  .word .loword(%d)\n' % v)
	outfile.close()

output_tables()
