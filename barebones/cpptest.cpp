//======================================================================================================================
//	BrownELF GCC example: C++ startup/shutdown tests
//======================================================================================================================

//----------------------------------------------------------------------------------------------------------------------

// ---------------------------------------------------------------------------------------------------------------------
//	system headers

#include <mint/sysbind.h>
#include <stdio.h>
#include <stdlib.h>		// for atexit()
#include <stdarg.h>		// for printf va_args etc.

// custom printf which can be redirected anywhere
extern "C" int debug_printf(const char *pFormat, ...);

// force GCC to keep functions that look like they might be dead-stripped due to non-use
#define USED __attribute__((used))

// =====================================================================================================================
//	Some tests for C++ constructor/destructor & atexit() sequencing
// =====================================================================================================================

USED void preinit_test(int argc, char **argv, char **envp) 
{
	debug_printf("%s\n", __FUNCTION__);
}

USED void init_test(int argc, char **argv, char **envp) 
{
	debug_printf("%s\n", __FUNCTION__);
}

USED void fini_test() 
{
	debug_printf("%s\n", __FUNCTION__);
}

// push above functions directly onto C++ init/fini lists
USED __attribute__((section(".init_array"))) __attribute__((used)) void *__init = (void *)&init_test;
USED __attribute__((section(".preinit_array"))) __attribute__((used)) void *__preinit = (void *)&preinit_test;
USED __attribute__((section(".fini_array"))) __attribute__((used)) void *__fini = (void *)&fini_test;


// alternate method: apply ctor/dtor attributes directly to functions
void  __attribute__ ((constructor)) constructor_attribute() 
{
	debug_printf("%s\n", __FUNCTION__);
}

void __attribute__ ((destructor)) destructor_attribute() 
{
	debug_printf("%s\n", __FUNCTION__);
}

// tests for atexit()
void my_atexit() 
{
	debug_printf("%s\n", __FUNCTION__);
}

void my_atexit2() 
{
	debug_printf("%s\n", __FUNCTION__);
}

// static global class instance to test for ctor/dtor sequencing on exit() or return from main()
class cppclass
{
public:

	cppclass()
	{
		debug_printf("%s\n", __FUNCTION__);
	}

	~cppclass()
	{
		debug_printf("%s\n", __FUNCTION__);
	}
};

cppclass cppclass_instance;

// =====================================================================================================================
//	program entrypoint
// =====================================================================================================================

int main(int argc, char ** argv)
{
	atexit(my_atexit);
	atexit(my_atexit2);

	debug_printf("C++ test: ready...\n");

	Crawcin();

	return 0;
}

