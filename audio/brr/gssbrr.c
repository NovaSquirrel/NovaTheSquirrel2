/*
	Code taken from snesgss - 2014?
	adapted by NovaSquirrel - 2022
*/
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include "brr.cpp"
#include "brr_encoder.cpp"
#include "3band_eq.h"

unsigned char *BRRTemp = NULL;	// The actual BRR encoded sample
int BRRTempAllocSize = 0;
int BRRTempSize = 0;	//actual encoded sample size in bytes
int BRRTempLoop = -1;

struct instrumentStruct {
	short *source;
	int source_rate;
	int source_volume;

	int length;

	int loop_start;
	int loop_end;
	bool loop_enable;
	bool loop_unroll;

	int resample_type;
	int downsample_factor;
	bool ramp_enable;

	int eq_low;
	int eq_mid;
	int eq_high;
};

float get_volume_scale(int vol) {
	if(vol<128) return 1.0f+(float)(vol-128)/128.0f; else return 1.0f+(float)(vol-128)/64.0f;
}

void BRREncode(struct instrumentStruct *ins) {
	const char resample_list[]="nlcsb";
	int i,smp,ptr,off,blocks,src_length,new_length,sum;
	int new_loop_start,padding,loop_size,new_loop_size;
	int src_loop_start,src_loop_end;
	short *source,*sample,*temp;
	float volume,s,delta,fade,ramp;
	bool loop_enable,loop_flag,end_flag;
	char resample_type;
	float scale;
	EQSTATE eq;
	double in_sample,out_sample,band_low,band_high,rate;

	if(BRRTemp)	{
		free(BRRTemp);
		BRRTemp=NULL;
		BRRTempSize=0;
		BRRTempLoop=-1;
	}

	//get the source sample, downsample it if needed
	src_length=ins->length;
	if(!ins->source||src_length<16) return;//sample is shorter than one BRR block
	source=(short*)malloc(src_length*sizeof(short));
	memcpy(source,ins->source,src_length*sizeof(short));

	//apply EQ if it is not reset, before any downsampling, as it needed to compensate downsampling effects as well
	if(ins->eq_low!=0||ins->eq_mid!=0||ins->eq_high!=0) {
		rate=ins->source_rate;

		band_low=rate/50.0;//880 for 44100
		band_high=rate/8.82;//5000 for 44100

		init_3band_state(&eq,band_low,band_high,rate);

		eq.lg = (double)(64+ins->eq_low)/64.0f;
		eq.mg = (double)(64+ins->eq_mid)/64.0f;
		eq.hg = (double)(64+ins->eq_high)/64.0f;

		for(i=0;i<src_length;++i) {
			in_sample=(double)source[i]/32768.0;

			out_sample=do_3band(&eq,in_sample);

			out_sample*=32768.0;

			if(out_sample<-32768) out_sample=-32768;
			if(out_sample> 32767) out_sample= 32767;

			source[i]=(short int)out_sample;
		}
	}

	//get scale factor for downsampling

	resample_type=resample_list[ins->resample_type];

	src_loop_start=ins->loop_start;
	src_loop_end  =ins->loop_end+1;//loop_end is the last sample of the loop, to calculate length it needs to be next to the last

	switch(ins->downsample_factor) {
		case 1:  scale=.5f;  break;
		case 2:  scale=.25f; break;
		default: scale=1.0f;
	}

	if(scale!=1.0f) {
		new_length=((float)src_length*scale);

		source=resample(source,src_length,new_length,resample_type);

		src_length    =new_length;
		src_loop_start=((float)src_loop_start*scale);
		src_loop_end  =((float)src_loop_end  *scale);
	}

	//align the sample as required
	loop_enable=ins->loop_enable;

	if(!loop_enable) {//no loop, just pad the source with zeroes to 16-byte boundary
		new_length=(src_length+15)/16*16;
		sample=(short*)malloc(new_length*sizeof(short));
		ptr=0;
		for(i=0;i<src_length;++i) sample[ptr++]=source[i];
		for(i=src_length;i<new_length;++i) sample[ptr++]=0;//pad with zeroes
		BRRTempLoop=-1;
	} else {
		if(!ins->loop_unroll) {//resample the loop part, takes less memory, but lower quality of the loop
			new_loop_start=(src_loop_start+15)/16*16;//align the loop start point to 16 samples
			padding=new_loop_start-src_loop_start;//calculate padding, how many zeroes to insert at beginning
			loop_size=src_loop_end-src_loop_start;//original loop length
			new_loop_size=loop_size/16*16;//calculate new loop size, aligned to 16 samples
			if((loop_size&15)>=8) new_loop_size+=16;//align to closest point, to minimize detune
			new_length=new_loop_start+new_loop_size;//calculate new source length
			sample=(short*)malloc(new_length*sizeof(short));
			ptr=0;
			for(i=0;i<padding;++i) sample[ptr++]=0;//add the padding bytes
			for(i=0;i<src_loop_start;++i) sample[ptr++]=source[i];//copy the part before loop
			if(new_loop_size==loop_size) {//just copy the loop part
				for(i=0;i<new_loop_size;++i) sample[ptr++]=source[src_loop_start+i];
			} else {
				temp=(short*)malloc(loop_size*sizeof(short));//temp copy of the looped part, as resample function frees up the source
				memcpy(temp,&source[src_loop_start],loop_size*sizeof(short));
				temp=resample(temp,loop_size,new_loop_size,resample_type);
				for(i=0;i<new_loop_size;++i) sample[ptr++]=temp[i];
				free(temp);
			}

			BRRTempLoop=new_loop_start/16;//loop point in blocks
		} else {//unroll the loop, best quality in trade for higher memory use
			new_loop_start=(src_loop_start+15)/16*16;//align the loop start point to 16 samples
			padding=new_loop_start-src_loop_start;//calculate padding, how many zeroes to insert at beginning
			loop_size=src_loop_end-src_loop_start;//original loop length
			new_length=new_loop_start;
			sample=(short*)malloc(new_length*sizeof(short));
			ptr=0;
			for(i=0;i<padding;++i) sample[ptr++]=0;//add the padding bytes
			for(i=0;i<src_loop_start;++i) sample[ptr++]=source[i];//copy the part before loop
			while(1) {
				if(new_length<ptr+loop_size) {
					new_length=ptr+loop_size;
					sample=(short*)realloc(sample,new_length*sizeof(short));
				}
				for(i=0;i<loop_size;++i) sample[ptr++]=source[src_loop_start+i];
				new_length=ptr;
				if(!(new_length&15)||new_length>=65536) break;
			}
			BRRTempLoop=new_loop_start/16;//loop point in blocks
		}
	}
	free(source);

	//apply volume
	volume=get_volume_scale(ins->source_volume);
	for(i=0;i<new_length;++i) {
		smp=(int)(((float)sample[i])*volume);
		if(smp<-32768) smp=-32768;
		if(smp> 32767) smp= 32767;
		sample[i]=smp;
	}

	//smooth out the loop transition

	if(loop_enable&&ins->ramp_enable) {
		ptr=new_length-16;

		fade=1.0f;
		ramp=0.0f;
		delta=((float)sample[new_loop_start])/16.0f;

		for(i=0;i<16;++i) {
			s=(float)sample[ptr];

			s=s*fade+ramp;
			fade-=1.0f/16.0f;
			ramp+=delta;

			sample[ptr++]=(short)s;
		}
	}

	/////////////////////////////////////////////////////////////////
	//convert to brr
	BRRTempAllocSize=16384;

	BRRTemp=(unsigned char*)malloc(BRRTempAllocSize);

	ptr=0;
	off=0;

	blocks=new_length/16;

	sum=0;

	//add initial block if there is any non-zero value in the first sample block
	//it is not clear if it is really needed

	for(i=0;i<16;++i) sum+=sample[i];

	if(sum) {
		memset(BRRTemp+ptr,0,9);

		if(loop_enable) BRRTemp[0]=0x02;//loop flag is always set for a looped sample

		ptr+=9;
	}

	//this ia a magic line
	ADPCMBlockMash(sample+(blocks-1)*16,false,true);
	//prevents clicks at the loop point and sound glitches somehow
	//tested few times it really affects the result
	//it seems that it caused by the squared error calculation in the function

	for(i=0;i<blocks;++i) {
		loop_flag=loop_enable&&((i==BRRTempLoop)?true:false);//loop flag is only set for the loop position
		end_flag =(i==blocks-1)?true:false;//end flag is set for the last block
		memset(BRR,0,9);
		ADPCMBlockMash(sample+off,loop_flag,end_flag);
		if(loop_enable) BRR[0]|=0x02;//loop flag is always set for a looped sample
		if(end_flag)  BRR[0]|=0x01;//end flag
		memcpy(BRRTemp+ptr,BRR,9);
		off+=16;
		ptr+=9;
		if(ptr>=BRRTempAllocSize-9) {
			BRRTempAllocSize+=16384;
			BRRTemp=(unsigned char*)realloc(BRRTemp,BRRTempAllocSize);
		}
	}
	free(sample);
	BRRTempSize=ptr;//actual encoded sample size in bytes
	if(sum&&BRRTempLoop>=0) ++BRRTempLoop;
}

int gss_hex_to_byte(char n) {
	if(n>='0'&&n<='9') return n-'0';
	if(n>='a'&&n<='f') return n-'a'+10;
	if(n>='A'&&n<='F') return n-'A'+10;
	return -1;
}

short *hex_to_source(const char *hex) {
	int length = strlen(hex);
	short *out = malloc(length/2);
	for(int i=0; i<length/4; i++) {
		out[i]  = gss_hex_to_byte(*(hex++)) << 12;
		out[i] |= gss_hex_to_byte(*(hex++)) << 8;
		out[i] |= gss_hex_to_byte(*(hex++)) << 4;
		out[i] |= gss_hex_to_byte(*(hex++)) << 0;
	}
	return out;
}

int main(int argc, char *argv[]) {
	if (argc != 15) {
		puts("Syntax: gssbrr length loop_start loop_end loop_enable loop_unroll souce_rate source_volume eq_low eq_mid eq_high resample_type downsample_factor ramp_enable source");
		return -1;
	}
	struct instrumentStruct instrument;
	instrument.length            = strtol(argv[1],  NULL, 10);
	instrument.loop_start        = strtol(argv[2],  NULL, 10);
	instrument.loop_end          = strtol(argv[3],  NULL, 10);
	instrument.loop_enable       = strtol(argv[4],  NULL, 10);
	instrument.loop_unroll       = strtol(argv[5],  NULL, 10);
	instrument.source_rate       = strtol(argv[6],  NULL, 10);
	instrument.source_volume     = strtol(argv[7],  NULL, 10);
	instrument.eq_low            = strtol(argv[8],  NULL, 10);
	instrument.eq_mid            = strtol(argv[9],  NULL, 10);
	instrument.eq_high           = strtol(argv[10], NULL, 10);
	instrument.resample_type     = strtol(argv[11], NULL, 10);
	instrument.downsample_factor = strtol(argv[12], NULL, 10);
	instrument.ramp_enable       = strtol(argv[13], NULL, 10);
	instrument.source            = hex_to_source(argv[14]);
	BRREncode(&instrument);

	printf("%d\n%d\n", BRRTempSize, (BRRTempLoop>0?(BRRTempLoop*9):BRRTempLoop));
	for(int i=0; i< BRRTempSize; i++) {
		printf("%.2x", BRRTemp[i]);
	}
	putchar('\n');
	return 0;
}
