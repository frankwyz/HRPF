/*
 * @Author: your name
 * @Date: 2022-03-03 10:09:18
 * @LastEditTime: 2022-03-03 14:28:05
 * @LastEditors: Please set LastEditors
 * @Description: 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 * @FilePath: \git_file_graduate\HRPA_12\algorithm\parallel_for\parallel_for_harness.cpp
 */
#pragma once
#include <stdio.h>
#include <sys/time.h>
#include <string>

#include "../algorithm/parallel_for/parallel_for_problem.h"
#include "tool/initializer.h"
#include "parallel_for_harness.h"
void cfor_func(Basedata_t* data){
    auto d = (loopData_t*)data;
    auto a = d->buffer[0]->get_cdata();
    auto b = d->buffer[1]->get_cdata();
    auto c = d->buffer[2]->get_cdata();

    size_t s = d->start;
    size_t e = d->end;

    for(int i = s; i < e; ++i){
        c[i] = a[i] + b[i];
    }
}
__global__ void kernel(size_t s, size_t e, size_t chunk, double* a, double* b, double* c){
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    int start = s + tid * chunk;
    int end = start+chunk < e ? start + chunk : e;

    for(int i = start; i < end; ++i){
        c[i] = a[i] + b[i];
    }
}

void gfor_func(Basedata_t* data){
    auto d = (loopData_t*)data;
    auto a = d->buffer[0]->get_gdata();
    auto b = d->buffer[1]->get_gdata();
    auto c = d->buffer[2]->get_gdata();

    size_t s = d->start;
    size_t e = d->end;

    int blocks_required = 1;
    int threads_per_block = 1024;
    int chunk_size = 1;
    int size = e - s;
    if(size % (threads_per_block * chunk_size)) {
        blocks_required = size / (threads_per_block * chunk_size) + 1;
    }
    else {
        blocks_required = size / (threads_per_block * chunk_size);
    }
    kernel<<<blocks_required, threads_per_block>>>(s, e, chunk_size, a, b, c);
}

int main(int argc, char **argv){
    
    std::size_t length = std::atoi(argv[1]);
    ArrayList* data1 = new ArrayList(length);
    ArrayList* data2 = new ArrayList(length);
    ArrayList* data3 = new ArrayList(length);
    initialize(data1, length);
    initialize(data2, length);
    initialize(data3, length);

    struct timeval start, end;
    gettimeofday(&start, NULL);
    parallel_for(new loopData_t(0, length, 2, 1, {data1, data2, data3}), cfor_func, gfor_func);
    gettimeofday(&end, NULL);
    double seconds = (end.tv_sec - start.tv_sec) + 1.0e-6 * (end.tv_usec - start.tv_usec);
    std::cout << seconds << std::endl;
    delete data1;
    delete data2;
    delete data3;
    return 0;
}