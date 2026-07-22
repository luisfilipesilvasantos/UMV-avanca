#pragma once
#include <windows.h>
#include <stdint.h>

typedef void* UMC_Handle;

#ifdef UMC_EXPORTS
    #define UMC_API __declspec(dllexport)
#else
    #define UMC_API __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    size_t blockSizeBytes;
    size_t maxVramBudget;
    size_t maxRamBudget;
    size_t maxPagefileBudget;
} UMC_InitParams;

UMC_API UMC_Handle UMC_Init(const UMC_InitParams* params);
UMC_API void UMC_Destroy(UMC_Handle handle);

typedef struct {
    int id;
    char name[96];
    size_t totalVram;
    size_t freeVram;
} UMC_GpuDeviceInfo;

UMC_API size_t UMC_GetGpuDeviceCount(UMC_Handle handle);
UMC_API BOOL UMC_GetGpuDeviceInfo(UMC_Handle handle, size_t index, UMC_GpuDeviceInfo* outInfo);
UMC_API size_t UMC_GetTotalVirtualCapacity(UMC_Handle handle);
UMC_API size_t UMC_GetTotalHostRam(UMC_Handle handle);
UMC_API size_t UMC_GetAvailableHostRam(UMC_Handle handle);
UMC_API size_t UMC_GetTotalPagefile(UMC_Handle handle);
UMC_API size_t UMC_GetAvailablePagefile(UMC_Handle handle);

typedef struct {
    int tier;
    int deviceId;
    size_t physicalOffset;
    size_t size;
} UMC_BlockLocation;

UMC_API BOOL UMC_WriteBlock(UMC_Handle handle, size_t blockId, const void* data, size_t size);
UMC_API BOOL UMC_ReadBlock(UMC_Handle handle, size_t blockId, void* outData, size_t size);
UMC_API BOOL UMC_GetBlockLocation(UMC_Handle handle, size_t blockId, UMC_BlockLocation* outLocation);

#ifdef __cplusplus
}
#endif
