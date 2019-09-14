#pragma once
#include "../src/BlackBone/Process/Process.h"

#ifdef BLACKBONEC_EXPORTS
#define BB_API __declspec(dllexport)
#else
#define BB_API __declspec(dllimport)
#endif

using Process = blackbone::Process;
using HandleInfo = blackbone::HandleInfo;
using ProcessModules = blackbone::ProcessModules;
using ModuleData = blackbone::ModuleData;
using exportData = blackbone::exportData;
using AsmVariant = blackbone::AsmVariant;
using ProcessThreads = blackbone::ProcessThreads;
using Thread = blackbone::Thread;

using eModType = blackbone::eModType;
using eModSeachType = blackbone::eModSeachType;
using eCalligConvention = blackbone::eCalligConvention;
using eReturnType = blackbone::eReturnType;

#ifdef __cplusplus
extern "C"{
#endif

	BB_API int32_t Process_ctor(Process* self);
	BB_API void Process_dtor(Process* self);

	BB_API NTSTATUS Process_AttachByPID(Process* self, DWORD pid, DWORD access);
	BB_API NTSTATUS Process_AttachByName(Process* self, const wchar_t* name, DWORD access);
	BB_API NTSTATUS Process_AttachByHandle(Process* self, HANDLE hProc);
	BB_API NTSTATUS Process_CreateAndAttach(Process* self,
		const wchar_t* path,
		bool suspended,
		bool forceInit,
		const wchar_t* cmdLine,
		const wchar_t* currentDir,
		STARTUPINFOW* pStartup);
	BB_API NTSTATUS Process_Detach(Process* self);
	BB_API NTSTATUS Process_EnsureInit(Process* self);
	BB_API NTSTATUS Process_Suspend(Process* self);
	BB_API NTSTATUS Process_Resume(Process* self);
	BB_API DWORD Process_pid(Process* self);
	BB_API bool Process_valid(Process* self);
	BB_API NTSTATUS Process_Terminate(Process* self, uint32_t code);
	BB_API int32_t Process_EnumHandles(Process* self, HandleInfo* out);
	BB_API ProcessModules* Process_modules(Process* self);

	BB_API bool Process_MemoryRead(Process* self, uint64_t src, void* dst, uint32_t size);
	BB_API bool Process_MemoryWrite(Process* self, void* src, uint64_t dst, uint32_t size);
	BB_API uint64_t Process_MemoryAllocate(Process* self, uint32_t size);
	BB_API bool Process_MemoryFree(Process* self, uint64_t addr);

	BB_API const ModuleData* ProcessModules_GetModule(ProcessModules* self,
		const wchar_t* name, eModSeachType search, eModType type);
	BB_API const ModuleData* ProcessModules_GetMainModule(ProcessModules* self);
	BB_API int32_t ProcessModules_GetAllModules(ProcessModules* self,
		eModSeachType search, const wchar_t** outName, eModType* outType, ModuleData** outMod);
	BB_API bool ProcessModules_GetExport(ProcessModules* self,
		const wchar_t* modName, const char* name_ord, exportData* out);
	BB_API NTSTATUS ProcessModules_Unload(ProcessModules* self,
		ModuleData* hMod);
	BB_API bool ProcessModules_Unlink(ProcessModules* self,
		ModuleData* mod);
	BB_API const ModuleData* ProcessModules_AddManualModule(ProcessModules* self,
		ModuleData* mod);
	BB_API void ProcessModules_RemoveManualModule(ProcessModules* self,
		const wchar_t* filename, eModType mt);
	BB_API void ProcessModules_reset(ProcessModules* self);

	BB_API int32_t RemoteCall(Process* process, const wchar_t* modName, const char* name_ord,
		eCalligConvention conv, AsmVariant** argv, int32_t argc,
		void* ret, int32_t retSize, eReturnType retType, bool retIsReference, bool inNewThread);

	//

	BB_API int32_t AsmVariant_ctor(AsmVariant* self);
	BB_API void AsmVariant_dtor(AsmVariant* self);

	BB_API void AsmVariant_set_integer(AsmVariant* self, uint64_t val, int32_t byteSize, bool isSigned);
	BB_API void AsmVariant_set_float(AsmVariant* self, float val);
	BB_API void AsmVariant_set_double(AsmVariant* self, double val);
	BB_API void AsmVariant_set_string(AsmVariant* self, const char* val);
	BB_API void AsmVariant_set_wstring(AsmVariant* self, const wchar_t* val);
	BB_API void AsmVariant_set_pointer(AsmVariant* self, void* val);
	BB_API void AsmVariant_set_arbitrary_pointer(AsmVariant* self, void* val, int32_t size);
	BB_API void AsmVariant_set_arbitrary_value(AsmVariant* self, void* val, int32_t size);

#ifdef __cplusplus
}
#endif
