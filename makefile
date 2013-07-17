all: phage-rx433.hex

phage-rx433.hex: phage-rx433.asm
	as31 -l phage-rx433.asm

clean:
	del *.hex
