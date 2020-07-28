def circle(radius, length):
	width = [0]*224
	def putpixel(x, y):
		if y >= len(width):
			return
		width[y] = max(width[y], x)

	x = 0
	y = radius
	d = 3 - 2 * radius

	putpixel(x, y)
	putpixel(y, x)
	while y >= x:
		x += 1
		if d > 0:
			y -= 1
			d = d + 4 * (x-y) + 10
		else:
			d = d + 4 * x + 6
		putpixel(x, y)
		putpixel(y, x)

	if length:
		if 0 in width:
			print("  .byt %d" % width.index(0))
		else:
			print("  .byt 224")
	else:
		print("  ; Radius %d" % radius)
		for i in width:
			print("  .byt %d" % min(255, i))

#circle(340) maximum that covers the screen

frames = 30
for i in range(frames):
	radius = int(340 / frames * i)
	circle(radius, False)
print("--- LENGTHS START HERE ---")
for i in range(frames):
	radius = int(340 / frames * i)
	circle(radius, True)
