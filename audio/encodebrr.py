import subprocess

def encode_brr(instrument):
	source_data = instrument.props['SourceData']
	p = subprocess.Popen(
		[
			"audio/brr/gssbrr",
			str(instrument.props['Length']),
			str(instrument.props['LoopStart']),
			str(instrument.props['LoopEnd']),
			str(instrument.props['LoopEnable']),
			str(instrument.props['LoopUnroll']),
			str(instrument.props['SourceRate']),
			str(instrument.props['SourceVolume']),
			str(instrument.props['EQLow']),
			str(instrument.props['EQMid']),
			str(instrument.props['EQHigh']),
			str(instrument.props['ResampleType']),
			str(instrument.props['DownsampleFactor']),
			str(instrument.props['RampEnable']),
			str(len(source_data))
		],
		stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True)
	output, errors = p.communicate(input=source_data)
	output = output.splitlines()
	return output
