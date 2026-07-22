# UMC Improvement Plan - Priority Implementation Roadmap

## Overview
This plan provides a focused, step-by-step roadmap to make UMC production-ready and effective. Each phase has clear acceptance criteria and specific file targets.

**Current Status**: Core functionality works, but needs optimization and production hardening.
**Target**: Stable, performant unified memory system for real-world AI workloads.

---

## Phase 1: Critical Performance Fixes (1-2 weeks)
**Priority**: CRITICAL - These fixes directly impact real-world performance.

### 1.1 Fix Inefficient Block Lookup in umc_free()
**File**: `umc_client.cpp` (lines 226-235)
**Problem**: Linear search through 10,000 blocks is O(n) and slow.
**Solution**: Add reverse mapping from physical pointer to block ID.

**Implementation**:
```cpp
// Add to VirtualGpuMemory class (VirtualGpuMemory.h):
std::unordered_map<size_t, size_t> m_ptrToBlockId; // physical offset -> block ID

// Update allocateBlockPhysical to populate mapping:
m_ptrToBlockId[outLocation.physicalOffset] = blockId;

// Update umc_free to use O(1) lookup:
void umc_free(void* ptr, size_t size, int device, void* stream) {
    if (!ptr) return;
    static VirtualGpuMemory* vgm = getGlobalInstance();
    if (!vgm) return;
    
    size_t physOffset = reinterpret_cast<size_t>(ptr);
    auto it = vgm->m_ptrToBlockId.find(physOffset);
    if (it != vgm->m_ptrToBlockId.end()) {
        vgm->freeBlockPhysical(it->second);
        vgm->m_ptrToBlockId.erase(it);
    }
}
```

**Acceptance Criteria**:
- Block deallocation is O(1) instead of O(n)
- No performance degradation with thousands of allocations
- All existing tests pass

### 1.2 Implement Proper Garbage Collection
**File**: `VirtualGpuMemory.h/cpp`
**Problem**: No cleanup of unused blocks, memory leaks possible.
**Solution**: Add reference counting and automatic cleanup.

**Implementation**:
```cpp
// Add to BlockLocation struct:
std::atomic<uint32_t> refcount{0};

// Add functions to VirtualGpuMemory:
void incrementRefcount(size_t blockId);
void decrementRefcount(size_t blockId);
void cleanupUnreferencedBlocks();

// Update allocation/deallocation paths to manage refcounts
```

**Acceptance Criteria**:
- Blocks are freed when refcount reaches zero
- No memory leaks in long-running applications
- Memory usage stays within configured budgets

### 1.3 Add Block Pool Management
**File**: `VirtualGpuMemory.cpp`
**Problem**: Frequent allocation/deallocation causes fragmentation.
**Solution**: Implement block pooling for each tier.

**Implementation**:
```cpp
// Add pool structures:
struct BlockPool {
    std::vector<void*> freeBlocks;
    std::mutex mutex;
};

BlockPool vramPool;
BlockPool ramPool;
BlockPool pagefilePool;

// Modify allocation to reuse from pool first
void* allocateFromPool(MemoryTier tier);
void returnToPool(MemoryTier tier, void* ptr);
```

**Acceptance Criteria**:
- Reduced allocation overhead
- Less memory fragmentation
- Measurable performance improvement in allocation benchmarks

---

## Phase 2: Async I/O Implementation (2-3 weeks)
**Priority**: HIGH - Critical for SSD performance and system responsiveness.

### 2.1 Implement I/O Completion Ports (IOCP)
**File**: Create new `AsyncIOManager.h/cpp`
**Problem**: Current synchronous I/O blocks the system during pagefile operations.
**Solution**: Windows IOCP for asynchronous SSD operations.

**Implementation**:
```cpp
class AsyncIOManager {
public:
    AsyncIOManager();
    ~AsyncIOManager();
    
    bool initialize(size_t numThreads = 4);
    bool readAsync(size_t offset, void* buffer, size_t size, 
                   std::function<void(bool)> callback);
    bool writeAsync(size_t offset, const void* buffer, size_t size,
                    std::function<void(bool)> callback);
    
private:
    HANDLE m_iocpHandle;
    std::vector<std::thread> m_workerThreads;
    HANDLE m_hFileMapping;
    std::atomic<bool> m_running;
};
```

**Integration Points**:
- Replace `MapViewOfFile` calls in `VirtualGpuMemory::readBlock()`/`writeBlock()`
- Add async variants: `readBlockAsync()`, `writeBlockAsync()`
- Update block migration to use async transfers

**Acceptance Criteria**:
- SSD I/O doesn't block main thread
- Measured throughput: SSD→RAM ≥ 2 GB/s on NVMe
- Multiple concurrent I/O operations scale properly

### 2.2 Implement Async CUDA Stream Management
**File**: `VirtualGpuMemory.cpp` (lines 143-151)
**Problem**: Basic stream management, no advanced async operations.
**Solution**: Dedicated stream pool for async transfers.

**Implementation**:
```cpp
class CudaStreamPool {
public:
    cudaStream_t getStream(int deviceId);
    void returnStream(int deviceId, cudaStream_t stream);
    void synchronizeAll(int deviceId);
    
private:
    std::unordered_map<int, std::queue<cudaStream_t>> m_streamPools;
    std::mutex m_mutex;
};

// Use in migration functions:
cudaStream_t stream = streamPool.getStream(deviceId);
cudaMemcpyAsync(dst, src, size, direction, stream);
// Register callback when complete
```

**Acceptance Criteria**:
- Multiple concurrent CUDA transfers
- No blocking on memory migrations
- Improved throughput for overlapping operations

---

## Phase 3: PyTorch Integration Refinement (1-2 weeks)
**Priority**: HIGH - Primary integration point for ComfyUI and other AI apps.

### 3.1 Improve CUDAPluggableAllocator Implementation
**File**: `umc_client.cpp` (lines 161-236)
**Problem**: Basic implementation, no proper size alignment or tracking.
**Solution**: Full-featured allocator with proper memory management.

**Implementation**:
```cpp
struct AllocationInfo {
    size_t size;
    int device;
    std::vector<size_t> blockIds;
};

std::unordered_map<void*, AllocationInfo> m_allocations;

void* umc_alloc(size_t size, int device, void* stream) {
    // Proper size alignment to block size
    const size_t BLOCK_SIZE = 4 * 1024 * 1024;
    size_t numBlocks = (size + BLOCK_SIZE - 1) / BLOCK_SIZE;
    
    // Allocate contiguous blocks
    std::vector<size_t> blockIds;
    for (size_t i = 0; i < numBlocks; ++i) {
        size_t blockId = allocateNextBlock(device);
        if (blockId == SIZE_MAX) {
            // Cleanup and return null
            cleanupBlocks(blockIds);
            return nullptr;
        }
        blockIds.push_back(blockId);
    }
    
    void* ptr = getBasePointer(blockIds[0]);
    m_allocations[ptr] = {size, device, blockIds};
    return ptr;
}

void umc_free(void* ptr, size_t size, int device, void* stream) {
    auto it = m_allocations.find(ptr);
    if (it != m_allocations.end()) {
        for (size_t blockId : it->second.blockIds) {
            freeBlock(blockId);
        }
        m_allocations.erase(it);
    }
}
```

**Acceptance Criteria**:
- Handles allocations larger than single block
- Proper cleanup of multi-block allocations
- No memory leaks
- Compatible with PyTorch's allocator interface

### 3.2 Add PyTorch Integration Tests
**File**: Create `test_pytorch_integration.py`
**Problem**: No validation that PyTorch integration works correctly.
**Solution**: Comprehensive test suite for PyTorch allocator.

**Implementation**:
```python
import torch
import unittest

class TestUMCPyTorchIntegration(unittest.TestCase):
    def test_basic_allocation(self):
        """Test basic tensor allocation with UMC"""
        # Enable UMC allocator
        from torch.cuda.memory import CUDAPluggableAllocator
        allocator = CUDAPluggableAllocator('umc_client.dll', 'umc_alloc', 'umc_free')
        torch.cuda.memory.change_current_allocator(allocator)
        
        # Allocate tensor
        tensor = torch.randn(1000, 1000, device='cuda')
        self.assertIsNotNone(tensor)
        
    def test_large_model_allocation(self):
        """Test allocation larger than VRAM"""
        # Allocate model larger than available VRAM
        # Verify it succeeds without OOM
        
    def test_memory_cleanup(self):
        """Test that memory is properly freed"""
        # Allocate and deallocate multiple times
        # Verify no memory leaks
```

**Acceptance Criteria**:
- All PyTorch allocation patterns work correctly
- Large model allocations succeed
- No memory leaks in repeated allocation/deallocation cycles

---

## Phase 4: Monitoring and Telemetry (1-2 weeks)
**Priority**: MEDIUM - Essential for production debugging and optimization.

### 4.1 Implement Structured Logging
**File**: Create `UMCLogger.h/cpp`
**Problem**: Current console output is not structured or persistent.
**Solution**: Thread-safe structured logging system.

**Implementation**:
```cpp
enum class LogLevel { DEBUG, INFO, WARNING, ERROR };

class UMCLogger {
public:
    static void log(LogLevel level, const std::string& message);
    static void logAllocation(size_t blockId, MemoryTier tier, size_t size);
    static void logMigration(size_t blockId, MemoryTier from, MemoryTier to);
    static void logEviction(size_t blockId, MemoryTier from);
    
private:
    static std::mutex s_mutex;
    static std::ofstream s_logFile;
};
```

**Log Events**:
- Block allocations (tier, size, timestamp)
- Block migrations (from tier, to tier, latency)
- Evictions (block ID, reason)
- Thrashing detection events
- Memory budget status

**Acceptance Criteria**:
- All major operations logged with timestamps
- Logs written to file for analysis
- Thread-safe logging
- Configurable log levels

### 4.2 Add Real-Time Monitoring UI
**File**: Create `UMCMonitor.cpp` (simple console UI)
**Problem**: No visibility into system state during operation.
**Solution**: Real-time memory usage display.

**Implementation**:
```cpp
class MemoryMonitor {
public:
    void startDisplay();
    void updateDisplay();
    void stopDisplay();
    
private:
    void displayStats();
    std::thread m_displayThread;
    std::atomic<bool> m_running;
};

// Display format:
// UMC Memory Monitor
// =================
// VRAM:    8.2 GB / 12.0 GB (68%)
// RAM:     16.5 GB / 32.0 GB (52%)
// Pagefile: 128 MB / 256 MB (50%)
// 
// Active Blocks: 2048
// Migrations/sec: 12
// Thrashing: NO
```

**Acceptance Criteria**:
- Real-time memory usage display
- Updates every second
- Shows tier distribution and performance metrics
- Clean shutdown on exit

---

## Phase 5: Advanced Features (2-3 weeks)
**Priority**: MEDIUM - Improves performance for complex workloads.

### 5.1 Implement Predictive Prefetch Scheduler
**File**: Create `PrefetchScheduler.h/cpp`
**Problem**: Current prefetch is reactive, not predictive.
**Solution**: ML-based or pattern-based prefetch prediction.

**Implementation**:
```cpp
class PrefetchScheduler {
public:
    void recordAccess(size_t blockId, uint64_t timestamp);
    std::vector<size_t> predictNextBlocks(size_t windowSize = 10);
    void schedulePrefetch(const std::vector<size_t>& blockIds, MemoryTier targetTier);
    
private:
    struct AccessPattern {
        size_t blockId;
        uint64_t timestamp;
    };
    
    std::deque<AccessPattern> m_accessHistory;
    std::unordered_map<size_t, std::vector<size_t>> m_transitionGraph;
    
    void buildTransitionGraph();
    std::vector<size_t> getLikelyNextBlocks(size_t currentBlock);
};
```

**Acceptance Criteria**:
- Reduces page faults by predicting accesses
- Measurable reduction in access latency
- Doesn't cause excessive prefetching

### 5.2 Add Working Set Estimation
**File**: Already in `VirtualGpuMemory.h` (line 97), needs implementation
**Problem**: Function declared but not fully implemented.
**Solution**: Complete working set estimation algorithm.

**Implementation**:
```cpp
std::pair<size_t, std::vector<size_t>> VirtualGpuMemory::estimateWorkingSet(int windowSize) {
    std::unordered_set<size_t> workingSet;
    
    // Analyze recent access history
    for (auto it = m_accessHistory.rbegin(); it != m_accessHistory.rend() && windowSize > 0; ++it, --windowSize) {
        workingSet.insert(it->second);
    }
    
    // Calculate total size
    size_t totalSize = 0;
    std::vector<size_t> blockIds(workingSet.begin(), workingSet.end());
    
    for (size_t blockId : blockIds) {
        auto it = m_blockMap.find(blockId);
        if (it != m_blockMap.end()) {
            totalSize += it->second.size;
        }
    }
    
    return {totalSize, blockIds};
}
```

**Acceptance Criteria**:
- Accurately estimates working set size
- Returns list of frequently accessed blocks
- Used for intelligent prefetch decisions

---

## Phase 6: Production Hardening (1-2 weeks)
**Priority**: MEDIUM - Required for stable production use.

### 6.1 Comprehensive Error Handling
**File**: Multiple files, add error handling throughout
**Problem**: Limited error handling, potential crashes.
**Solution**: Robust error handling with recovery.

**Implementation**:
- Add error codes enum
- Wrap all API calls in try-catch
- Add graceful degradation paths
- Implement recovery procedures for common failures

**Error Codes**:
```cpp
enum class UMCError {
    SUCCESS = 0,
    OUT_OF_MEMORY,
    INITIALIZATION_FAILED,
    INVALID_PARAMETER,
    CUDA_ERROR,
    IO_ERROR,
    INTERNAL_ERROR
};
```

**Acceptance Criteria**:
- No crashes on common error conditions
- Graceful degradation when resources exhausted
- Clear error messages for debugging

### 6.2 Configuration System
**File**: Create `UMCConfig.h/cpp`
**Problem**: Hard-coded values, no runtime configuration.
**Solution**: File-based configuration system.

**Implementation**:
```cpp
struct UMCConfig {
    size_t blockSizeBytes = 4 * 1024 * 1024;
    size_t vramBudgetPercent = 80;
    size_t ramBudgetPercent = 50;
    size_t pagefileBudgetMB = 256;
    bool enablePrefetch = true;
    bool enableThrashingDetection = true;
    int logLevel = 1; // INFO
};

class ConfigManager {
public:
    static bool loadFromFile(const std::string& path);
    static bool saveToFile(const std::string& path);
    static UMCConfig& getConfig();
};
```

**Config File Format (JSON)**:
```json
{
    "blockSizeBytes": 4194304,
    "vramBudgetPercent": 80,
    "ramBudgetPercent": 50,
    "pagefileBudgetMB": 256,
    "enablePrefetch": true,
    "enableThrashingDetection": true,
    "logLevel": 1
}
```

**Acceptance Criteria**:
- Configuration loaded from file at startup
- Runtime configuration changes supported
- Default values for missing config

---

## Phase 7: Testing and Validation (Ongoing)
**Priority**: HIGH - Required throughout development.

### 7.1 Unit Tests
**File**: Create test files using Google Test framework
**Components to test**:
- VirtualGpuMemory core functions
- Block allocation and deallocation
- Tier migration logic
- LRU eviction algorithm
- Thrashing detection

### 7.2 Integration Tests
**File**: Create integration test suite
**Test scenarios**:
- End-to-end model loading
- ComfyUI workflow simulation
- Multi-GPU scenarios
- Long-running stability tests

### 7.3 Performance Benchmarks
**File**: Create `benchmark_umc.cpp`
**Metrics to measure**:
- Allocation/deallocation throughput
- Tier migration latency
- SSD→RAM→VRAM throughput
- Overall system overhead vs native PyTorch

**Target Performance** (from spec):
- SSD→RAM: ≥ 2 GB/s
- RAM→VRAM: ≥ 10 GB/s
- Allocation overhead: < 5% vs native

---

## Implementation Order Summary

**Week 1-2**: Phase 1 (Critical Performance Fixes)
**Week 3-5**: Phase 2 (Async I/O Implementation)  
**Week 6-7**: Phase 3 (PyTorch Integration Refinement)
**Week 8-9**: Phase 4 (Monitoring and Telemetry)
**Week 10-12**: Phase 5 (Advanced Features)
**Week 13-14**: Phase 6 (Production Hardening)
**Ongoing**: Phase 7 (Testing and Validation)

## Success Criteria

**Phase 1 Complete**: 
- Block operations are O(1)
- No memory leaks in stress tests
- 50%+ performance improvement in allocation benchmarks

**Phase 2 Complete**:
- Async I/O doesn't block main thread
- Meets throughput targets (2 GB/s SSD, 10 GB/s RAM→VRAM)
- Scales with concurrent operations

**Phase 3 Complete**:
- PyTorch integration passes all tests
- ComfyUI runs without OOM on large workflows
- No memory leaks in PyTorch allocator

**Phase 4 Complete**:
- Structured logging for all operations
- Real-time monitoring UI functional
- Logs useful for debugging production issues

**Phase 5 Complete**:
- Predictive prefetch reduces page faults by 30%+
- Working set estimation accurate within 10%
- Measurable performance improvement in real workloads

**Phase 6 Complete**:
- No crashes on error conditions
- Configuration system works end-to-end
- Production-ready stability

**Overall Success**:
- ComfyUI runs complex workflows on RTX 3060 without OOM
- Performance overhead < 20% vs native (acceptable for functionality gained)
- System stable for 24+ hour continuous operation
- Clear documentation and usage examples

---

## Notes for Coder

1. **Focus on one phase at a time** - Don't jump between phases
2. **Test each change thoroughly** before moving to next
3. **Maintain backward compatibility** where possible
4. **Document any API changes** in corresponding header files
5. **Run existing tests after each change** to ensure no regressions
6. **Profile performance** before and after optimizations
7. **Keep code simple and readable** - prefer clarity over cleverness
8. **Add comments for complex logic** - future maintenance depends on it

**Starting Point**: Begin with Phase 1.1 (fix block lookup in umc_free) as it's the highest impact single change.
