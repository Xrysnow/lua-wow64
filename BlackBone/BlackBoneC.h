typedef long NTSTATUS;
typedef int32_t eModType;
typedef int32_t eModSeachType;
typedef int32_t eCalligConvention;
typedef int32_t eReturnType;

typedef struct Process_ { char __[528]; } Process;
typedef struct ProcessModules_ {} ProcessModules;
typedef struct ModuleData_ {} ModuleData;
typedef struct AsmVariant_ { char __[72]; } AsmVariant;

typedef struct _STARTUPINFOW {
    unsigned long   cb;
    wchar_t*  lpReserved;
    wchar_t*  lpDesktop;
    wchar_t*  lpTitle;
    unsigned long   dwX;
    unsigned long   dwY;
    unsigned long   dwXSize;
    unsigned long   dwYSize;
    unsigned long   dwXCountChars;
    unsigned long   dwYCountChars;
    unsigned long   dwFillAttribute;
    unsigned long   dwFlags;
    unsigned short    wShowWindow;
    unsigned short    cbReserved2;
    unsigned char*  lpReserved2;
    void*  hStdInput;
    void*  hStdOutput;
    void*  hStdError;
} STARTUPINFOW;


int32_t Process_ctor(Process* self);
void Process_dtor(Process* self);

NTSTATUS Process_AttachByPID(Process* self, unsigned long pid, unsigned long access);
NTSTATUS Process_AttachByName(Process* self, const wchar_t* name, unsigned long access);
NTSTATUS Process_AttachByHandle(Process* self, void* hProc);
NTSTATUS Process_CreateAndAttach(Process* self,
	const wchar_t* path,
	bool suspended,
	bool forceInit,
	const wchar_t* cmdLine,
	const wchar_t* currentDir,
	STARTUPINFOW* pStartup);
NTSTATUS Process_Detach(Process* self);
NTSTATUS Process_EnsureInit(Process* self);
NTSTATUS Process_Suspend(Process* self);
NTSTATUS Process_Resume(Process* self);
unsigned long Process_pid(Process* self);
bool Process_valid(Process* self);
NTSTATUS Process_Terminate(Process* self, uint32_t code);
//int32_t Process_EnumHandles(Process* self, HandleInfo* out);
ProcessModules* Process_modules(Process* self);

const ModuleData* ProcessModules_GetModule(ProcessModules* self,
	const wchar_t* name, eModSeachType search, eModType type);
const ModuleData* ProcessModules_GetMainModule(ProcessModules* self);
int32_t ProcessModules_GetAllModules(ProcessModules* self,
	eModSeachType search, const wchar_t** outName, eModType* outType, ModuleData** outMod);
//bool ProcessModules_GetExport(ProcessModules* self,
//	const wchar_t* modName, const char* name_ord, exportData* out);
NTSTATUS ProcessModules_Unload(ProcessModules* self,
	ModuleData* hMod);
bool ProcessModules_Unlink(ProcessModules* self,
	ModuleData* mod);
const ModuleData* ProcessModules_AddManualModule(ProcessModules* self,
	ModuleData* mod);
void ProcessModules_RemoveManualModule(ProcessModules* self,
	const wchar_t* filename, eModType mt);
void ProcessModules_reset(ProcessModules* self);

int32_t RemoteCall(Process* process, const wchar_t* modName, const char* name_ord,
	eCalligConvention conv, AsmVariant** argv, int32_t argc,
	void* ret, int32_t retSize, eReturnType retType, bool retIsReference);

//

int32_t AsmVariant_ctor(AsmVariant* self);
void AsmVariant_dtor(AsmVariant* self);

void AsmVariant_set_integer(AsmVariant* self, uint64_t val, int32_t byteSize, bool isSigned);
void AsmVariant_set_float(AsmVariant* self, float val);
void AsmVariant_set_double(AsmVariant* self, double val);
void AsmVariant_set_string(AsmVariant* self, const char* val);
void AsmVariant_set_wstring(AsmVariant* self, const wchar_t* val);
void AsmVariant_set_pointer(AsmVariant* self, void* val);
void AsmVariant_set_arbitrary_pointer(AsmVariant* self, void* val, int32_t size);
void AsmVariant_set_arbitrary_value(AsmVariant* self, void* val, int32_t size);
