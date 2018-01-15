#include "mex.h"
#include <stdbool.h>


/*
 
    mex -O columnPartialMean.c
 
//TODO
//1) DONE Error checking on input values
//2) DONE Speed comparison to Matlab
//3) DONE Allow padding output with 1 sample to avoid later concatenation


data = reshape(1:10000,1000,10);
column_I = 2;
start_I = 2;
samples_per_avg = 31;
avg_values = columnPartialMean(data,column_I,start_I,samples_per_avg,true);
 
 */

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    
    //  Format
    //  -------------------
    //  avg_values = columnPartialMean(data,column,start_index,samples_per_avg,add_sample)
    //
    //  Inputs
    //  ------
    //  start_index : 1 based
    
    if (nlhs != 1){
        mexErrMsgIdAndTxt("daq2:partial_means:n_outputs","n outputs must be 1");
    }else if (nrhs != 5){
        mexErrMsgIdAndTxt("daq2:partial_means:n_inputs","n inputs must be 4");
    }
    
    //Why didn't this work ????
    
    if (!mxIsClass(prhs[0],"double")){
        mexErrMsgIdAndTxt("daq2:partial_means:input_Type",
                "Currently input type must be double");
    }
    
    size_t n_rows;
    size_t n_columns;
    
    n_rows = mxGetM(prhs[0]);
    n_columns = mxGetN(prhs[0]);
    
    if (!mxIsDouble(prhs[1])){
        mexErrMsgIdAndTxt("daq2:partial_means:input_Type",
                "2nd input must be of type double");
    }else if (!mxIsDouble(prhs[2])){
        mexErrMsgIdAndTxt("daq2:partial_means:input_Type",
                "3rd input must be of type double");
    }else if (!mxIsDouble(prhs[3])){
        mexErrMsgIdAndTxt("daq2:partial_means:input_Type",
                "4th input must be of type double");
    }else if (!mxIsLogicalScalar(prhs[4])){
        mexErrMsgIdAndTxt("daq2:partial_means:input_Type",
                "5th input must be of type double");
    }
    
    double *input_data = mxGetPr(prhs[0]);
    size_t column_I = (size_t)mxGetScalar(prhs[1]);
    size_t start_I = (size_t)mxGetScalar(prhs[2]);
    size_t samples_per_avg = (size_t)mxGetScalar(prhs[3]);
    bool add_sample = mxIsLogicalScalarTrue(prhs[4]);
    
    
            
    //We now need to do error checking on the input values NYI
    //  column_I valid
    //  start_I valid
    //  
    
    if (column_I < 1 || column_I > n_columns){
        mexErrMsgIdAndTxt("daq2:partial_means:input_value",
                "Selected column is out of range for input data");
    }
    
    if (start_I < 1 || start_I > n_rows){
   	mexErrMsgIdAndTxt("daq2:partial_means:input_value",
                "Selected start row is out of range for input data");
    }
    
    
    size_t n_out = (n_rows - start_I + 1)/samples_per_avg;
    
    if (add_sample){
        plhs[0] = mxCreateNumericMatrix(n_out+1,1,mxDOUBLE_CLASS,mxREAL);
    }else{
        plhs[0] = mxCreateNumericMatrix(n_out,1,mxDOUBLE_CLASS,mxREAL);
    }
    
    double *output_data = mxGetPr(plhs[0]);
    
    double *p_in = &input_data[(column_I-1)*n_rows + start_I-1];
    double *p_out = output_data;
    
    if (add_sample){
        p_out++;
    }
    
    
    double norm_factor = 1/(double)(samples_per_avg);
    
    double temp_value;
    
    //The current approach adds then normalizes after the fact ...
    for (size_t i = 0; i < n_out; i++){
        temp_value = 0;
        for (size_t j = 0; j < samples_per_avg; j++){
            temp_value += *p_in;
            p_in++;
        }
        *p_out = temp_value*norm_factor;
        p_out++;
    }
  
}