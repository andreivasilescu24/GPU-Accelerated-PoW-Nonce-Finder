# GPU Kernel Implementation for Nonce Search in Blockchain Mining

## Memory Allocation and Setup

To begin, I allocated GPU memory for the variables needed during kernel execution:

- **Correct Nonce**: Memory was allocated to store the correct nonce when found.
- **Resultant Hash**: Memory was allocated to store the hash resulting from the correct nonce.
- **Block Content**: Memory was allocated for the initial `block_content` (composed of the previous block's hash and the Merkle root hash). This content was copied from the host to the GPU memory to be passed as a kernel parameter.

### Configuration of Blocks and Threads

After experimenting with different configurations, I chose to use **64 blocks with 512 threads each**, as this provided the best performance. Other tested configurations included **128 blocks with 256 threads** and **128 blocks with 512 threads**.

Based on the number of blocks and threads, I calculated the number of nonces each thread would need to verify, ensuring an even workload distribution. This value was also copied to GPU memory.

Additionally, a **flag** variable was allocated to signal when a valid nonce is found. When a thread finds a valid nonce, it sets this flag to 1, notifying all other threads to stop searching.

---

## Kernel Function Parameters

The kernel function receives the following parameters:

- `block_content`: The block content passed from the host.
- Pointers to GPU memory for:
  - The resultant hash.
  - The correct nonce.
  - The flag indicating a valid nonce.
- The number of nonces each thread should check.
- The difficulty hash, which is used for validation.

Each thread computes its **Thread ID** based on its `blockId`, `blockDim`, and `threadId`. Using this ID, the thread calculates the starting nonce for its search range, ensuring each thread covers a unique portion of the nonce space.

---

## Local Thread Memory and Execution Flow

Each thread initializes local variables:

- **`block_hash`**: Stores the calculated hash for the current nonce.
- **`block_content`**: A copy of the initial block content, which is concatenated with the current nonce during each iteration to compute the hash.

### Search Loop

The search loop operates as follows:

1. **Flag Check**: The thread first checks if the flag is set to 1. If it is, the thread terminates since another thread has already found a valid nonce.
2. **Hash Calculation**: If the flag is not set, the thread:
   - Computes the hash using the current nonce.
   - Validates the hash against the difficulty target.
3. **Valid Nonce Found**:
   - If a valid hash is found and the flag is still unset, the thread:
     - Uses `atomicExch` to set the flag to 1.
     - Stores the valid hash and nonce in the designated GPU memory.
     - Terminates its execution.

---

## Post-Kernel Execution

After all threads complete execution, the valid nonce and hash are copied back from the GPU to the host. These values are then printed to a CSV file for record-keeping.

Finally, all memory allocated on the GPU and host is deallocated to free up resources.
