#include "BlackBoneC.h"
#include "../src/BlackBone/Process/Process.h"
#include "../src/BlackBone/Patterns/PatternSearch.h"
#include "../src/BlackBone/Process/RPC/RemoteFunction.hpp"
#include "../src/BlackBone/Syscalls/Syscall.h"

using namespace blackbone;

int32_t Process_ctor(::Process* self)
{
	if (self)
		new (self) ::Process;
	return sizeof(::Process);
}

void Process_dtor(::Process* self)
{
	if (self)
		self->~Process();
}

NTSTATUS Process_AttachByPID(::Process* self, DWORD pid, DWORD access)
{
	if (!self) return -1;
	return self->Attach(pid, access);
}

NTSTATUS Process_AttachByName(::Process* self, const wchar_t* name, DWORD access)
{
	if (!self) return -1;
	return self->Attach(name, access);
}

NTSTATUS Process_AttachByHandle(::Process* self, HANDLE hProc)
{
	if (!self) return -1;
	return self->Attach(hProc);
}

NTSTATUS Process_CreateAndAttach(::Process* self, const wchar_t* path, bool suspended, bool forceInit,
	const wchar_t* cmdLine, const wchar_t* currentDir, STARTUPINFOW* pStartup)
{
	if (!self) return -1;
	return self->CreateAndAttach(path, suspended);// , forceInit, cmdLine, currentDir, pStartup);
}

NTSTATUS Process_Detach(::Process* self)
{
	if (!self) return -1;
	return self->Detach();
}

NTSTATUS Process_EnsureInit(::Process* self)
{
	if (!self) return -1;
	return self->EnsureInit();
}

NTSTATUS Process_Suspend(::Process* self)
{
	if (!self) return -1;
	return self->Suspend();
}

NTSTATUS Process_Resume(::Process* self)
{
	if (!self) return -1;
	return self->Resume();
}

DWORD Process_pid(::Process* self)
{
	if (!self) return -1;
	return self->pid();
}

bool Process_valid(::Process* self)
{
	if (!self) return false;
	return self->valid();
}

NTSTATUS Process_Terminate(::Process* self, uint32_t code)
{
	if (!self) return -1;
	return self->Terminate(code);
}

int32_t Process_EnumHandles(::Process* self, ::HandleInfo* out)
{
	if (!self) return -1;
	auto ret = self->EnumHandles();
	if (!ret)
		return -1;
	auto val = ret.result();
	if (out && !val.empty())
	{
		for (auto i = 0u; i < val.size(); ++i)
			out[i] = val[i];
	}
	return val.size();
}

::ProcessModules* Process_modules(::Process* self)
{
	if (!self) return nullptr;
	return &self->modules();
}

const ::ModuleData* ProcessModules_GetModule(::ProcessModules* self, const wchar_t* name, ::eModSeachType search,
	::eModType type)
{
	if (!self) return nullptr;
	return self->GetModule(name, search, type).get();
}

const ::ModuleData* ProcessModules_GetMainModule(::ProcessModules* self)
{
	if (!self) return nullptr;
	return self->GetMainModule().get();
}

int32_t ProcessModules_GetAllModules(::ProcessModules* self, ::eModSeachType search, const wchar_t** outName,
	::eModType* outType, ::ModuleData** outMod)
{
	if (!self) return 0;
	auto& m = self->GetAllModules(search);
	auto i = 0u;
	for (auto& it : m)
	{
		if(outName)
			outName[i] = it.first.first.c_str();
		if(outType)
			outType[i] = it.first.second;
		if(outMod)
			outMod[i] = (::ModuleData*)it.second.get();
		++i;
	}
	return m.size();
}

bool ProcessModules_GetExport(::ProcessModules* self, const wchar_t* modName, const char* name_ord,
	::exportData* out)
{
	if (!self) return false;
	auto ret = self->GetExport(modName, name_ord);
	if(!ret)
		return false;
	*out = ret.result();
	return true;
}

NTSTATUS ProcessModules_Unload(::ProcessModules* self, ::ModuleData* hMod)
{
	if (!self) return -1;
	auto p = std::make_shared<const ::ModuleData>(*hMod);
	return self->Unload(p);
}

bool ProcessModules_Unlink(::ProcessModules* self, ::ModuleData* mod)
{
	if (!self) return false;
	return self->Unlink(*mod);
}

const ::ModuleData* ProcessModules_AddManualModule(::ProcessModules* self, ::ModuleData* mod)
{
	if (!self) return nullptr;
	return self->AddManualModule(*mod).get();
}

void ProcessModules_RemoveManualModule(::ProcessModules* self, const wchar_t* filename, ::eModType mt)
{
	if (!self) return;
	self->RemoveManualModule(filename, mt);
}

void ProcessModules_reset(::ProcessModules* self)
{
	if (!self) return;
	self->reset();
}

int32_t RemoteCall(::Process* process, const wchar_t* modName, const char* name_ord, ::eCalligConvention conv,
	::AsmVariant** argv, int32_t argc, void* ret, int32_t retSize, ::eReturnType retType, bool retIsReference)
{
	if (!process || !modName || !name_ord) return -1;
	auto exp = process->modules().GetExport(modName, name_ord);
	if (!exp)
		return -2;
	auto& _process = *process;
	ThreadPtr contextThread = nullptr;
	auto a = AsmFactory::GetAssembler(_process.core().isWow64());
	auto status = _process.remote().CreateRPCEnvironment(Worker_None, contextThread != nullptr);
	if (!NT_SUCCESS(status))
		return -3;
	auto _ptr = exp->procAddress;
	std::vector<::AsmVariant> arguments;
	for (auto i = 0; i < argc; ++i)
		arguments.push_back(*(argv[i]));
	status = _process.remote().PrepareCallAssembly(*a, _ptr, arguments, conv, retType);
	if (!NT_SUCCESS(status))
		return -4;
	uint64_t tmpResult = 0;
	status = _process.remote().ExecInNewThread((*a)->make(), (*a)->getCodeSize(), tmpResult);
	if (!NT_SUCCESS(status))
		return -5;
/*
	An overload for RemoteExec::GetCallResult is added to RemoteExec.h:

	NTSTATUS GetCallResult( void* result, size_t size, bool isReference )
	{
		if (size > sizeof( uint64_t ))
		{
			if (isReference)
				return _userData.Read( _userData.Read<uintptr_t>( RET_OFFSET, 0 ), size, result );
			else
				return _userData.Read( ARGS_OFFSET, size, result );
		}
		else
			return _userData.Read( RET_OFFSET, size, result );
	}
 */
	status = _process.remote().GetCallResult(ret, retSize, retIsReference);
	if (!NT_SUCCESS(status))
		return -6;
	for (auto& arg : arguments)
		if (arg.type == ::AsmVariant::dataPtr)
			_process.memory().Read(arg.new_imm_val, arg.size, reinterpret_cast<void*>(arg.imm_val));
	for (auto i = 0; i < argc; ++i)
		*(argv[i]) = arguments[i];
	return 0;
}

int32_t AsmVariant_ctor(::AsmVariant* self)
{
	if (self)
		new (self) ::AsmVariant(0);
	return sizeof(::AsmVariant);
}

void AsmVariant_dtor(::AsmVariant* self)
{
	if (self)
		self->~AsmVariant();
}

void AsmVariant_set_integer(::AsmVariant* self, uint64_t val, int32_t byteSize, bool isSigned)
{
	if (!self) return;
	if (isSigned)
	{
		if (byteSize == 1)
			*self = ::AsmVariant(static_cast<int8_t>(val));
		else if (byteSize == 2)
			*self = ::AsmVariant(static_cast<int16_t>(val));
		else if (byteSize == 4)
			*self = ::AsmVariant(static_cast<int32_t>(val));
		else if (byteSize == 8)
			*self = ::AsmVariant(static_cast<int64_t>(val));
	}
	else
	{
		if (byteSize == 1)
			*self = ::AsmVariant(static_cast<uint8_t>(val));
		else if (byteSize == 2)
			*self = ::AsmVariant(static_cast<uint16_t>(val));
		else if (byteSize == 4)
			*self = ::AsmVariant(static_cast<uint32_t>(val));
		else if (byteSize == 8)
			*self = ::AsmVariant(static_cast<uint64_t>(val));
	}
}

void AsmVariant_set_float(::AsmVariant* self, float val)
{
	if (!self) return;
	*self = ::AsmVariant(val);
}

void AsmVariant_set_double(::AsmVariant* self, double val)
{
	if (!self) return;
	*self = ::AsmVariant(val);
}

void AsmVariant_set_string(::AsmVariant* self, const char* val)
{
	if (!self) return;
	*self = ::AsmVariant(val);
}

void AsmVariant_set_wstring(::AsmVariant* self, const wchar_t* val)
{
	if (!self) return;
	*self = ::AsmVariant(val);
}

void AsmVariant_set_pointer(::AsmVariant* self, void* val)
{
	if (!self) return;
	*self = ::AsmVariant(val);
}

void AsmVariant_set_arbitrary_pointer(::AsmVariant* self, void* val, int32_t size)
{
	if (!self) return;
	*self = ::AsmVariant(0);
	self->set(::AsmVariant::eType::dataPtr, size, reinterpret_cast<uint64_t>(val));
}

void AsmVariant_set_arbitrary_value(::AsmVariant* self, void* val, int32_t size)
{
	if (!self) return;
	*self = ::AsmVariant(0);
	if (size <= sizeof(uintptr_t))
	{
		self->type = ::AsmVariant::eType::imm;
		self->size = size;
		memcpy(&self->imm_val64, val, size);
	}
	else
	{
		self->buf.resize(size);
		self->set(::AsmVariant::eType::dataStruct, size, reinterpret_cast<uint64_t>(self->buf.data()));
		memcpy(self->buf.data(), val, size);
	}
}
