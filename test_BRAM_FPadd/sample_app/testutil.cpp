// ----------------------------------------------------------------------
// Copyright (c) 2016, The Regents of the University of California All
// rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
// 
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
// 
//     * Redistributions in binary form must reproduce the above
//       copyright notice, this list of conditions and the following
//       disclaimer in the documentation and/or other materials provided
//       with the distribution.
// 
//     * Neither the name of The Regents of the University of California
//       nor the names of its contributors may be used to endorse or
//       promote products derived from this software without specific
//       prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL REGENTS OF THE
// UNIVERSITY OF CALIFORNIA BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
// OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
// TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
// DAMAGE.
// ----------------------------------------------------------------------
#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include "timer.h"
#include "riffa.h"
#include <algorithm>
#include <bitset>
#include <cstdlib>
#include <ctime>
#include <cmath>
#include <vector>
#include <string>
#include <sstream>
#include <fstream>
#include <bits/stdc++.h>
#include <sys/time.h>
#include "omp.h"

/*    std::string binary = std::bitset<8>(128).to_string(); //to binary
    std::cout<<binary<<"\n";

    unsigned long decimal = std::bitset<8>(binary).to_ulong();
    std::cout<<decimal<<"\n";*/

using namespace std;

int float_to_bits(float f)
{
	return bitset<sizeof f*8>(*(long unsigned int*)(&f)).to_ulong();
}

string float_to_str(float f)
{
	return bitset<sizeof f*8>(*(long unsigned int*)(&f)).to_string();
}

int Binary2Hex( string Binary );
float str_to_float( string Binary );
void ErrorStat(float* diff_vec, float* ref_vec, int size);


int main(int argc, char** argv) {
	fpga_t * fpga;
	fpga_info_list info;
	int option;
	int i;
	int id;
	int chnl;
	int sent;
	int recvd;
	unsigned int * sendBuffer;
	unsigned int * recvBuffer;
	GET_TIME_INIT(3);
	srand(time(NULL));

	if (argc < 2) {
		printf("Usage: %s <option>\n", argv[0]);
		return -1;
	}

	option = atoi(argv[1]);

	if (option == 0) {	// List FPGA info
		// Populate the fpga_info_list struct
		if (fpga_list(&info) != 0) {
			printf("Error populating fpga_info_list\n");
			return -1;
		}
		printf("Number of devices: %d\n", info.num_fpgas);
		for (i = 0; i < info.num_fpgas; i++) {
			printf("%d: id:%d\n", i, info.id[i]);
			printf("%d: num_chnls:%d\n", i, info.num_chnls[i]);
			printf("%d: name:%s\n", i, info.name[i]);
			printf("%d: vendor id:%04X\n", i, info.vendor_id[i]);
			printf("%d: device id:%04X\n", i, info.device_id[i]);
		}
	}
	else if (option == 1) { // Reset FPGA
		if (argc < 3) {
			printf("Usage: %s %d <fpga id>\n", argv[0], option);
			return -1;
		}

		id = atoi(argv[2]);

		// Get the device with id
		fpga = fpga_open(id);
		if (fpga == NULL) {
			printf("Could not get FPGA %d\n", id);
			return -1;
	    }

		// Reset
		fpga_reset(fpga);

		// Done with device
        fpga_close(fpga);
	}
	else if (option == 2) { // Send data, receive data
		if (argc != 3) {
			printf("Usage: %s %d <num_of_data> \n", argv[0], option);
			return -1;
		}
		
		int numData	= min(65536, atoi(argv[2])); //65536;//atoi(argv[4]);
		id 		= 0;//atoi(argv[2]);
		chnl 	= 0;// atoi(argv[3]);
		
		struct  timeval t_start;
		struct  timeval t_end;
		
		// Get the device with id
		fpga = fpga_open(id);
		if (fpga == NULL) {
			printf("Could not get FPGA %d\n", id);
			return -1;
	    }

		int* input_memory   = new int [numData];
		int* receive_memory = new int [numData];
		
		
		float* input_float    = new float [numData];
		float* receive_float  = new float [numData];
		float* golden_output  = new float [numData];
		
		//---------------------------------------------------------------------------//
		
		for(i = 0; i < numData; i++) {
			float _value = (float)rand()/(float)(RAND_MAX/1024);
			input_memory[i] = float_to_bits(_value);
			input_float[i] 	= _value;
		}
		
		for(i = 0; i < numData; i++) {
			if(i%4==0) {
				golden_output[i] = ((input_float[i]+input_float[i+1])+(input_float[i+2]+input_float[i+3]));
			}
			else {
				golden_output[i] = 0;
			}
		}
		
		//---------------------------------------------------------------------------//
		
		double fpga_ms = 0;
		cout<<"Start sending data ..."<<endl;
		
		int r_offset = 0;	// rOff in chnl_test.v
		
		//===============================SEND====================================//
		//fpga_reset(fpga);
		
		GET_TIME_VAL(1);			
		sent = fpga_send(fpga, chnl, input_memory, numData, r_offset, 1, 25000);
				
		recvd = fpga_recv(fpga, chnl, receive_memory, numData, 25000);
		GET_TIME_VAL(2);
		fpga_ms += (TIME_VAL_TO_MS(2) - TIME_VAL_TO_MS(1));
		
		//=======================================================================//
		// Reset
		fpga_reset(fpga);
		// Done with device
        fpga_close(fpga);

		// Display some data
		cout<<"Send Words: "<<sent<<endl;
		
		for (i = 0; i < numData; i++) 
		{
			float reci_float = str_to_float(bitset<32>(receive_memory[i]).to_string());
			receive_float[i] = reci_float;
		}
		
		for (i = 0; i < min(100,numData); i++) 
		{
			cout<<"recvBuffer["<<i<<"]: "<<receive_float[i]<<";\t\t ";
			cout<<"goldBuffer["<<i<<"]: "<<golden_output[i]<<endl;
		}
		printf("\n");
		
		cout<<"Sent    Data (words) = "<<sent<<endl;
		cout<<"Receive Data (words) = "<<recvd<<endl;
		//all_sent *= 4.0;
		
		// Check the data
		if (recvd != 0) {
			ErrorStat(receive_float, golden_output, numData);
			//float ms = 1000*(end-start);//1000*(t_end.tv_sec-t_start.tv_sec)+0.001*(t_end.tv_usec-t_start.tv_usec);
			
			printf("FPGA send bw: %f MB/s %fms\n",
				sent*4.0/1024/1024/(fpga_ms/1000.0), (fpga_ms ));
		}
	}

	return 0;
}

//=============================================================================================================================//

void ErrorStat(float* diff_vec, float* ref_vec, int size)
{
	int stat_vec[6];//0.1, 1, 2, 5, 10, >10
	for(int i = 0 ; i < 6 ; i++){ stat_vec[i] = 0;}
	float may_difference = 0;
	float may_diff_vec, may_ref_vec;
	float may_percent_difference = 0;
	float may_diff_per, may_ref_per;
	for(int i = 0 ; i < size ; i++)
	{
		if(abs(diff_vec[i]-ref_vec[i])<1e-10)
		{
			stat_vec[0] += 1;
			continue;
		}
		if(may_difference < abs(diff_vec[i]-ref_vec[i]))
		{
			may_difference = abs(diff_vec[i]-ref_vec[i]);
			may_diff_vec   = diff_vec[i];
			may_ref_vec    = ref_vec[i];
		}
		if(may_percent_difference < abs(diff_vec[i]-ref_vec[i])/abs(ref_vec[i]))
		{
			may_percent_difference = abs(diff_vec[i]-ref_vec[i])/abs(ref_vec[i]);
			may_diff_per   = diff_vec[i];
			may_ref_per    = ref_vec[i];
		}
		
		float diff = abs(diff_vec[i]/ref_vec[i]-1);
		if(diff <= 0.001)		stat_vec[0] += 1;
		else if(diff <= 0.01)	stat_vec[1] += 1;
		else if(diff <= 0.02)	stat_vec[2] += 1;
		else if(diff <= 0.05)	stat_vec[3] += 1;
		else if(diff <= 0.1)	stat_vec[4] += 1;
		else					stat_vec[5] += 1;
	}
	cout<<"========================================================\n";
	cout<<"===                   Statistic                      ===\n";
	cout<<"========================================================\n";
	cout<<"Difference less than 0.1% = "<<stat_vec[0]<<"\t("<<((float)stat_vec[0]/size)*100<<"%)\n";
	cout<<"Difference less than 1%   = "<<stat_vec[1]<<"\t("<<((float)stat_vec[1]/size)*100<<"%)\n";
	cout<<"Difference less than 2%   = "<<stat_vec[2]<<"\t("<<((float)stat_vec[2]/size)*100<<"%)\n";
	cout<<"Difference less than 5%   = "<<stat_vec[3]<<"\t("<<((float)stat_vec[3]/size)*100<<"%)\n";
	cout<<"Difference less than 10%  = "<<stat_vec[4]<<"\t("<<((float)stat_vec[4]/size)*100<<"%)\n";
	cout<<"Difference more than 10%  = "<<stat_vec[5]<<"\t("<<((float)stat_vec[5]/size)*100<<"%)\n";
	cout<<"========================================================\n";
	cout<<"Maximum Difference        = "<<may_difference<<endl;
	cout<<"Diff Vector               = "<<may_diff_vec<<endl;
	cout<<"Ref  Vector               = "<<may_ref_vec<<endl;
	cout<<"========================================================\n";
	cout<<"Maximum % Difference      = "<<may_percent_difference<<"%"<<endl;
	cout<<"Diff Vector               = "<<may_diff_per<<endl;
	cout<<"Ref  Vector               = "<<may_ref_per<<endl;
	cout<<"========================================================\n";
}

// Convert the 32-bit binary encoding into hexadecimal
int Binary2Hex( string Binary )
{
    bitset<32> set(Binary);      
    int hex = set.to_ulong();
     
    return hex;
}
// Convert the 32-bit binary into the decimal
float str_to_float( string Binary )
{
    int HexNumber = Binary2Hex( Binary );
 
    bool negative  = !!(HexNumber & 0x80000000);
    int  exponent  =   (HexNumber & 0x7f800000) >> 23;    
    int sign = negative ? -1 : 1;
 
    // Subtract 127 from the exponent
    exponent -= 127;
 
    // Convert the mantissa into decimal using the
    // last 23 bits
    int power = -1;
    float total = 0.0;
    for ( int i = 0; i < 23; i++ )
    {
        int c = Binary[ i + 9 ] - '0';
        total += (float) c * (float) pow( 2.0, power );
        power--;
    }
    total += 1.0;

    float value = sign * (float) pow( 2.0, exponent ) * total;
 
    return value;
}

/*
void ErrorStat(float* diff_vec, float* ref_vec, int size)
{
	int stat_vec[6];//0.1, 1, 2, 5, 10, >10
	for(int i = 0 ; i < 6 ; i++){ stat_vec[i] = 0;}
	float may_difference = 0;
	float may_diff_vec, may_ref_vec;
	int row, sys;
	float may_percent_difference = 0;
	float may_diff_per, may_ref_per;
	for(int i = 0 ; i < size ; i++)
	{
		if(abs(diff_vec[i]-ref_vec[i])<1e-10)
		{
			stat_vec[0] += 1;
			continue;
		}
		if(may_difference < abs(diff_vec[i]-ref_vec[i]))
		{
			may_difference = abs(diff_vec[i]-ref_vec[i]);
			may_diff_vec   = diff_vec[i];
			may_ref_vec    = ref_vec[i];
			row = i/512; sys = i%512;
		}
		if(may_percent_difference < abs(diff_vec[i]-ref_vec[i])/abs(ref_vec[i]))
		{
			may_percent_difference = abs(diff_vec[i]-ref_vec[i])/abs(ref_vec[i]);
			may_diff_per   = diff_vec[i];
			may_ref_per    = ref_vec[i];
		}
		
		float diff = abs(diff_vec[i]/ref_vec[i]-1);
		if(diff <= 0.001)		stat_vec[0] += 1;
		else if(diff <= 0.01)	stat_vec[1] += 1;
		else if(diff <= 0.02)	stat_vec[2] += 1;
		else if(diff <= 0.05)	stat_vec[3] += 1;
		else if(diff <= 0.1)	stat_vec[4] += 1;
		else					stat_vec[5] += 1;
	}
	cout<<"========================================================\n";
	cout<<"===                   Statistic                      ===\n";
	cout<<"========================================================\n";
	cout<<"Difference less than 0.1% = "<<stat_vec[0]<<"\t("<<((float)stat_vec[0]/size)*100<<"%)\n";
	cout<<"Difference less than 1%   = "<<stat_vec[1]<<"\t("<<((float)stat_vec[1]/size)*100<<"%)\n";
	cout<<"Difference less than 2%   = "<<stat_vec[2]<<"\t("<<((float)stat_vec[2]/size)*100<<"%)\n";
	cout<<"Difference less than 5%   = "<<stat_vec[3]<<"\t("<<((float)stat_vec[3]/size)*100<<"%)\n";
	cout<<"Difference less than 10%  = "<<stat_vec[4]<<"\t("<<((float)stat_vec[4]/size)*100<<"%)\n";
	cout<<"Difference more than 10%  = "<<stat_vec[5]<<"\t("<<((float)stat_vec[5]/size)*100<<"%)\n";
	cout<<"========================================================\n";
	cout<<"Maximum Difference        = "<<may_difference<<endl;
	cout<<"(Row, Sys)                = ("<<row<<", "<<sys<<")"<<endl;
	cout<<"Diff Vector               = "<<may_diff_vec<<endl;
	cout<<"Ref  Vector               = "<<may_ref_vec<<endl;
	cout<<"========================================================\n";
	cout<<"Maximum % Difference      = "<<may_percent_difference<<"%"<<endl;
	cout<<"Diff Vector               = "<<may_diff_per<<endl;
	cout<<"Ref  Vector               = "<<may_ref_per<<endl;
	cout<<"========================================================\n";
}

void WriteDiffMap(string outPath, float* write_vec1, float* write_vec2, int size)
{
	ofstream out;
	out.open(outPath);
	for(int i = 0 ; i < size ; i++)
	{
		stringstream ss;
		int _num = Binary2Hex(float_to_str(abs(write_vec1[i]-write_vec2[i])));
		ss << hex << setw(8) << setfill('0')  << _num;
		out<<ss.str()<<endl;
	}
}

void WriteMap(string outPath, float* write_vec1, int size)
{
	ofstream out;
	out.open(outPath);
	for(int i = 0 ; i < size ; i++)
	{
		stringstream ss;
		int _num = Binary2Hex(float_to_str(write_vec1[i]));
		ss << hex << setw(8) << setfill('0')  << _num;
		out<<ss.str()<<endl;
	}
}

// Convert the 32-bit binary encoding into hexadecimal
int Binary2Hex( string Binary )
{
    bitset<32> set(Binary);      
    int hex = set.to_ulong();
     
    return hex;
}
// Convert the 32-bit binary into the decimal
float str_to_float( string Binary )
{
    int HexNumber = Binary2Hex( Binary );
 
    bool negative  = !!(HexNumber & 0x80000000);
    int  exponent  =   (HexNumber & 0x7f800000) >> 23;    
    int sign = negative ? -1 : 1;
 
    // Subtract 127 from the exponent
    exponent -= 127;
 
    // Convert the mantissa into decimal using the
    // last 23 bits
    int power = -1;
    float total = 0.0;
    for ( int i = 0; i < 23; i++ )
    {
        int c = Binary[ i + 9 ] - '0';
        total += (float) c * (float) pow( 2.0, power );
        power--;
    }
    total += 1.0;

    float value = sign * (float) pow( 2.0, exponent ) * total;
 
    return value;
}
*/