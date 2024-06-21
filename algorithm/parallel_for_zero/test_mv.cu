/*
 * @Author: your name
 * @Date: 2022-03-03 10:09:18
 * @LastEditTime: 2022-03-12 14:48:19
 * @LastEditors: Please set LastEditors
 * @Description: 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 * @FilePath: \git_file_graduate\HRPA_12\algorithm\parallel_for\parallel_for_harness.cpp
 */
#pragma once
#include <stdio.h>
#include <sys/time.h>
#include <string>

#include "parallel_for_zb.h"
#include "tool/initializer.h"
#include "framework/framework.h"
#include "tool/helper.h"
//#include "parallel_for_harness.hpp"
#include <omp.h>
static int length;
struct UserData_t : public Basedata_t{
public:
    UserData_t(std::vector<Matrix*>m_bf, std::vector<ArrayList*> buf
        ) : m_buffer(m_bf), v_buffer(buf){
        }

public:
    std::vector<Matrix*> m_buffer;
    std::vector<ArrayList*> v_buffer;
};

void cfor_func(Basedata_t* data){
    auto d = (loopData_t*)data;
    auto a = ((UserData_t*)(d->buffer))->m_buffer[0]->get_cdata();
    auto b = ((UserData_t*)(d->buffer))->v_buffer[0]->get_cdata();
    auto c = ((UserData_t*)(d->buffer))->v_buffer[1]->get_cdata();
    
    size_t lda = ((UserData_t*)(d->buffer))->m_buffer[0]->get_ld();
    // size_t ldb = d->v_buffer[0]->get_ld();
    // size_t ldc = d->v_buffer[1]->get_ld();
    size_t s_i = d->start;
    size_t e_i = d->end;
    size_t s_j = 0;
    size_t e_j = length;
    // std::cout << s_i << s_j << e_i << e_j << std::endl;
    #pragma omp parallel for num_threads(16)
    for(int i = s_i; i < e_i; ++i){
        double loc = 0;
        for(int j = s_j; j < e_j; ++j) {
            loc += a[i + j * lda] * b[j];
            // std::cout << a[i + j * lda] << std::endl;
        }
        c[i] = loc;
    }
}

__global__ void kernel_2DMv(size_t s_i, size_t e_i, size_t s_j, size_t e_j,
    size_t lda, size_t ldb, size_t ldc,
    size_t chunk, double* a, double* b, double* c) {
    int tid = threadIdx.x + blockIdx.x * blockDim.x;

    int start_i = s_i + tid * chunk;
    int end_i = start_i + chunk < e_i ? start_i + chunk : e_i;

    for(int i = start_i; i < end_i; ++i){
        double loc = 0.0;
        for(int j = s_j; j < e_j; ++j) {
            loc += a[i + j * lda] * b[j];
        }
        c[i] = loc;
    }  
}

void gfor_func(Basedata_t* data){
    auto d = (loopData_t*)data;
    auto a = ((UserData_t*)(d->buffer))->m_buffer[0]->get_gdata();
    auto b = ((UserData_t*)(d->buffer))->v_buffer[0]->get_gdata();
    auto c = ((UserData_t*)(d->buffer))->v_buffer[1]->get_gdata();
    
    size_t lda = ((UserData_t*)(d->buffer))->m_buffer[0]->get_ld();
    size_t s_i = d->start;
    size_t e_i = d->end;
    size_t s_j = 0;
    size_t e_j = length;
    
    int blocks_required = 1;
    int threads_per_block = 1024;
    int chunk_size = 1;
    int size = e_i - s_i;
    if(size % (threads_per_block * chunk_size)) {
        blocks_required = size / (threads_per_block * chunk_size) + 1;
    }
    else {
        blocks_required = size / (threads_per_block * chunk_size);
    }
    cudaStream_t stream_ = stream();
    kernel_2DMv<<<blocks_required, threads_per_block, 0, stream_>>>(s_i, e_i, s_j, e_j, lda, 0, 0, 
        chunk_size, a, b, c);
}

int main(int argc, char **argv){
    Framework::init();
    length = std::atoi(argv[1]);
    Matrix* data1 = new Matrix(length,length);
    ArrayList* data2 = new ArrayList(length);
    ArrayList* data3 = new ArrayList(length);
    initialize(length, data1);
    initialize(data2, length);
    initialize(data3, length);
    UserData_t* user = new UserData_t({data1}, {data2, data3});
    struct timeval start, end;
    gettimeofday(&start, NULL);
    parallel_for(new loopData_t(0, length, user), cfor_func, gfor_func);
   
    gettimeofday(&end, NULL);
    double seconds = (end.tv_sec - start.tv_sec) + 1.0e-6 * (end.tv_usec - start.tv_usec);
    std::cout << seconds << std::endl;
    
    auto da = data3->get_cdata();
    // for(int i = 0; i < length; ++i){
    //     for(int j = 0; j < length; ++j){
    //         std::cout << da[i + length*j] << " ";
    //     }
    //     std::cout << std::endl;
    // }
    delete user;
    delete data1;
    delete data2;
    delete data3;
    return 0;
}
