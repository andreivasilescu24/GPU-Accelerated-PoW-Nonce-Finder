#include <stdio.h>
#include <stdint.h>
#include "../include/utils.cuh"
#include <string.h>
#include <stdlib.h>
#include <inttypes.h>

__global__ void findNonce(BYTE* block_content, BYTE* block_hash, BYTE* difficulty_hash, int* num_nonces_each_thread, uint64_t* nonce, int* nonce_found_flag) {
	int my_tid = blockIdx.x * blockDim.x + threadIdx.x;
	uint64_t starting_nonce = 1 + my_tid * (*num_nonces_each_thread);

	int len_initial_block_content = d_strlen((const char*) block_content);

	char *nonce_str;
	cudaMalloc((void**) &nonce_str, NONCE_SIZE);

	int len_nonce;

	BYTE local_block_hash[BLOCK_SIZE];
	BYTE local_block_content[BLOCK_SIZE];
	d_strcpy((char*) local_block_content, (const char*) block_content);

	for (uint64_t i = starting_nonce; i < starting_nonce + *num_nonces_each_thread && i <= MAX_NONCE; ++i) {
		if (*nonce_found_flag) {
			cudaFree((void*) nonce_str);
			return;
		}

		len_nonce = intToString(i, nonce_str);
		
		d_strcpy((char*) local_block_content + len_initial_block_content, (const char*) nonce_str);
		apply_sha256(local_block_content, len_initial_block_content + len_nonce, local_block_hash, 1);

		if (compare_hashes(local_block_hash, difficulty_hash) <= 0 && !(*nonce_found_flag)) {
			atomicExch(nonce_found_flag, 1);
			d_strcpy((char*) block_hash, (const char*) local_block_hash);

			*nonce = i;
			cudaFree((void*) nonce_str);
			return;
		}
	}
}

int main(int argc, char **argv) {
	BYTE hashed_tx1[SHA256_HASH_SIZE], hashed_tx2[SHA256_HASH_SIZE], hashed_tx3[SHA256_HASH_SIZE], hashed_tx4[SHA256_HASH_SIZE],
			tx12[SHA256_HASH_SIZE * 2], tx34[SHA256_HASH_SIZE * 2], hashed_tx12[SHA256_HASH_SIZE], hashed_tx34[SHA256_HASH_SIZE],
			tx1234[SHA256_HASH_SIZE * 2], top_hash[SHA256_HASH_SIZE], block_content[BLOCK_SIZE];

	size_t current_length;

	// Top hash
	apply_sha256(tx1, strlen((const char*)tx1), hashed_tx1, 1);
	apply_sha256(tx2, strlen((const char*)tx2), hashed_tx2, 1);
	apply_sha256(tx3, strlen((const char*)tx3), hashed_tx3, 1);
	apply_sha256(tx4, strlen((const char*)tx4), hashed_tx4, 1);
	strcpy((char *)tx12, (const char *)hashed_tx1);
	strcat((char *)tx12, (const char *)hashed_tx2);
	apply_sha256(tx12, strlen((const char*)tx12), hashed_tx12, 1);
	strcpy((char *)tx34, (const char *)hashed_tx3);
	strcat((char *)tx34, (const char *)hashed_tx4);
	apply_sha256(tx34, strlen((const char*)tx34), hashed_tx34, 1);
	strcpy((char *)tx1234, (const char *)hashed_tx12);
	strcat((char *)tx1234, (const char *)hashed_tx34);
	apply_sha256(tx1234, strlen((const char*)tx34), top_hash, 1);

	// prev_block_hash + top_hash
	strcpy((char*)block_content, (const char*)prev_block_hash);
	strcat((char*)block_content, (const char*)top_hash);
	current_length = strlen((char*) block_content);

	uint64_t *nonce = 0;
	cudaMalloc((void**)&nonce, sizeof(uint64_t));

	BYTE* block_hash;
	cudaMalloc((void**)&block_hash, BLOCK_SIZE);

	BYTE* block_content_device;
	cudaMalloc((void**)&block_content_device, BLOCK_SIZE);
	cudaMemcpy(block_content_device, block_content, current_length + 1, cudaMemcpyHostToDevice);

	// get the number of nonces each thread will check
	int *num_nonces_each_thread;
	cudaMalloc((void**) &num_nonces_each_thread, sizeof(int));

	int num_threads = 512;
	size_t blocks_no = 64;

	int num_nonces_aux;
	if ((int)(MAX_NONCE) % ((int)blocks_no * (int)num_threads) == 0) {
		num_nonces_aux = MAX_NONCE / (blocks_no * num_threads);
	} else {
		num_nonces_aux = MAX_NONCE / (blocks_no * num_threads);
		++num_nonces_aux;
	}

	cudaMemcpy((void*) num_nonces_each_thread, (void*) &num_nonces_aux, sizeof(int), cudaMemcpyHostToDevice);
	
	BYTE* difficulty_hash;
	cudaMalloc((void**)&difficulty_hash, SHA256_HASH_SIZE);
	cudaMemcpy(difficulty_hash, DIFFICULTY, SHA256_HASH_SIZE, cudaMemcpyHostToDevice);

	int* nonce_found_flag;
	cudaMalloc((void**) &nonce_found_flag, sizeof(int));
	cudaMemset(nonce_found_flag, 0, sizeof(int));
	
	cudaEvent_t start, stop;
	startTiming(&start, &stop);
	
	findNonce<<<blocks_no, num_threads>>>(block_content_device, block_hash, difficulty_hash, num_nonces_each_thread, nonce, nonce_found_flag);
	cudaDeviceSynchronize();
	
	float seconds = stopTiming(&start, &stop);

	BYTE* block_hash_host = (BYTE*) malloc(BLOCK_SIZE);
	cudaMemcpy(block_hash_host, block_hash, BLOCK_SIZE, cudaMemcpyDeviceToHost);

	uint64_t nonce_host;
	cudaMemcpy(&nonce_host, nonce, sizeof(uint64_t), cudaMemcpyDeviceToHost);

	// free GPU memory
	cudaFree(block_hash);
	cudaFree(block_content_device);
	cudaFree(difficulty_hash);
	cudaFree(nonce);
	cudaFree(nonce_found_flag);
	cudaFree(num_nonces_each_thread);

	printResult(block_hash_host, nonce_host, seconds);

	free(block_hash_host);

	return 0;
}
