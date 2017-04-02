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
extern int debug_printf(const char *pFormat, ...);

// force GCC to keep functions that look like they might be dead-stripped due to non-use
#define USED __attribute__((used))

// =====================================================================================================================
//	Some tests for atexit() sequencing
// =====================================================================================================================

void my_atexit() 
{
	debug_printf("%s\n", __FUNCTION__);
}

void my_atexit2() 
{
	debug_printf("%s\n", __FUNCTION__);
}

// =====================================================================================================================
//	program entrypoint
// =====================================================================================================================

int main(int argc, char ** argv)
{
	atexit(my_atexit);
	atexit(my_atexit2);

	debug_printf("C test: ready...\n");

	Crawcin();

	return 0;
}

