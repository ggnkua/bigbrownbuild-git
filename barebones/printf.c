//======================================================================================================================
//	BrownELF example: printf redirection
//======================================================================================================================

// ---------------------------------------------------------------------------------------------------------------------
//	system headers

#include <mint/sysbind.h>

#include <stdarg.h>
#include <stdio.h>

// ---------------------------------------------------------------------------------------------------------------------

int debug_printf(const char *pFormat, ...)
{
	char buf[4096];
	int len = 0;
	va_list pArg;
	va_start(pArg, pFormat);
	len = vsnprintf(buf, 1000, pFormat, pArg);
	va_end(pArg);

	// route to TOS console if display is not locked for graphics
	//if (!g_displaylocked)
	{
		char *pscan = buf;
		while (*pscan)
		{
			unsigned short c = *pscan++;
			if (c == 10) 
				Bconout(2, 13);
			Bconout(2, c);
		}
	}

	//steem_print(buf);
	//hatari_natfeats_print(buf);
	//engine_print(buf);

	return len;
}
