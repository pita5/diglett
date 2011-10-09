/*
*   $Id: read.c 769 2010-09-11 21:00:16Z dhiebert $
*
*   Copyright (c) 1996-2002, Darren Hiebert
*
*   This source code is released for free distribution under the terms of the
*   GNU General Public License.
*
*   This module contains low level source and tag file read functions (newline
*   conversion for source files are performed at this level).
*/

/*
*   INCLUDE FILES
*/
#include "general.h"  /* must always come first */

#include <string.h>
#include <ctype.h>

#define FILE_WRITE
#include "read.h"
#include "debug.h"
#include "entry.h"
#include "main.h"
#include "routines.h"
#include "options.h"

/*
*   DATA DEFINITIONS
*/
//inputFile File;  /* globally read through macros */
//static fpos_t StartOfLine;  /* holds deferred position of start of line */
#import "ctags_globals.h"

/*
*   FUNCTION DEFINITIONS
*/

extern void freeSourceFileResources (void)
{
	if (GSDG.File.name != NULL)
		vStringDelete (GSDG.File.name);
	if (GSDG.File.path != NULL)
		vStringDelete (GSDG.File.path);
	if (GSDG.File.source.name != NULL)
		vStringDelete (GSDG.File.source.name);
	if (GSDG.File.source.tagPath != NULL)
		eFree (GSDG.File.source.tagPath);
	if (GSDG.File.line != NULL)
		vStringDelete (GSDG.File.line);
    
    //memset(&File, sizeof(File), 0);
    GSDG.StartOfLine = 0;
}

/*
 *   Source file access functions
 */

static void setInputFileName (const char *const fileName)
{
	const char *const head = fileName;
	const char *const tail = baseFilename (head);

	if (GSDG.File.name != NULL)
		vStringDelete (GSDG.File.name);
	GSDG.File.name = vStringNewInit (fileName);

	if (GSDG.File.path != NULL)
		vStringDelete (GSDG.File.path);
	if (tail == head)
		GSDG.File.path = NULL;
	else
	{
		const size_t length = tail - head - 1;
		GSDG.File.path = vStringNew ();
		vStringNCopyS (GSDG.File.path, fileName, length);
	}
}

static void setSourceFileParameters (vString *const fileName)
{
	if (GSDG.File.source.name != NULL)
		vStringDelete (GSDG.File.source.name);
	GSDG.File.source.name = fileName;

	if (GSDG.File.source.tagPath != NULL)
		eFree (GSDG.File.source.tagPath);
	if (! Option.tagRelative || isAbsolutePath (vStringValue (fileName)))
		GSDG.File.source.tagPath = eStrdup (vStringValue (fileName));
	else
		GSDG.File.source.tagPath =
				relativeFilename (vStringValue (fileName), GSDG.TagFile.directory);

	if (vStringLength (fileName) > GSDG.TagFile.max.file)
		GSDG.TagFile.max.file = vStringLength (fileName);

	GSDG.File.source.isHeader = isIncludeFile (vStringValue (fileName));
	GSDG.File.source.language = getFileLanguage (vStringValue (fileName));
}

static boolean setSourceFileName (vString *const fileName)
{
	boolean result = FALSE;
	if (getFileLanguage (vStringValue (fileName)) != LANG_IGNORE)
	{
		vString *pathName;
		if (isAbsolutePath (vStringValue (fileName)) || GSDG.File.path == NULL)
			pathName = vStringNewCopy (fileName);
		else
			pathName = combinePathAndFile (
					vStringValue (GSDG.File.path), vStringValue (fileName));
		setSourceFileParameters (pathName);
		result = TRUE;
	}
	return result;
}

/*
 *   Line directive parsing
 */

static int skipWhite (void)
{
	int c;
	do
		c = getc (GSDG.File.fp);
	while (c == ' '  ||  c == '\t');
	return c;
}

static unsigned long readLineNumber (void)
{
	unsigned long lNum = 0;
	int c = skipWhite ();
	while (c != EOF  &&  isdigit (c))
	{
		lNum = (lNum * 10) + (c - '0');
		c = getc (GSDG.File.fp);
	}
	ungetc (c, GSDG.File.fp);
	if (c != ' '  &&  c != '\t')
		lNum = 0;

	return lNum;
}

/* While ANSI only permits lines of the form:
 *   # line n "filename"
 * Earlier compilers generated lines of the form
 *   # n filename
 * GNU C will output lines of the form:
 *   # n "filename"
 * So we need to be fairly flexible in what we accept.
 */
static vString *readFileName (void)
{
	vString *const fileName = vStringNew ();
	boolean quoteDelimited = FALSE;
	int c = skipWhite ();

	if (c == '"')
	{
		c = getc (GSDG.File.fp);  /* skip double-quote */
		quoteDelimited = TRUE;
	}
	while (c != EOF  &&  c != '\n'  &&
			(quoteDelimited ? (c != '"') : (c != ' '  &&  c != '\t')))
	{
		vStringPut (fileName, c);
		c = getc (GSDG.File.fp);
	}
	if (c == '\n')
		ungetc (c, GSDG.File.fp);
	vStringPut (fileName, '\0');

	return fileName;
}

static boolean parseLineDirective (void)
{
	boolean result = FALSE;
	int c = skipWhite ();
	DebugStatement ( const char* lineStr = ""; )

	if (isdigit (c))
	{
		ungetc (c, GSDG.File.fp);
		result = TRUE;
	}
	else if (c == 'l'  &&  getc (GSDG.File.fp) == 'i'  &&
			 getc (GSDG.File.fp) == 'n'  &&  getc (GSDG.File.fp) == 'e')
	{
		c = getc (GSDG.File.fp);
		if (c == ' '  ||  c == '\t')
		{
			DebugStatement ( lineStr = "line"; )
			result = TRUE;
		}
	}
	if (result)
	{
		const unsigned long lNum = readLineNumber ();
		if (lNum == 0)
			result = FALSE;
		else
		{
			vString *const fileName = readFileName ();
			if (vStringLength (fileName) == 0)
			{
				GSDG.File.source.lineNumber = lNum - 1;  /* applies to NEXT line */
				DebugStatement ( debugPrintf (DEBUG_RAW, "#%s %ld", lineStr, lNum); )
			}
			else if (setSourceFileName (fileName))
			{
				GSDG.File.source.lineNumber = lNum - 1;  /* applies to NEXT line */
				DebugStatement ( debugPrintf (DEBUG_RAW, "#%s %ld \"%s\"",
								lineStr, lNum, vStringValue (fileName)); )
			}

			if (Option.include.fileNames && vStringLength (fileName) > 0 &&
				lNum == 1)
			{
				tagEntryInfo tag;
				initTagEntry (&tag, baseFilename (vStringValue (fileName)));

				tag.isFileEntry     = TRUE;
				tag.lineNumberEntry = TRUE;
				tag.lineNumber      = 1;
				tag.kindName        = "file";
				tag.kind            = 'F';

				makeTagEntry (&tag);
			}
			vStringDelete (fileName);
			result = TRUE;
		}
	}
	return result;
}

/*
 *   Source file I/O operations
 */

/*  This function opens a source file, and resets the line counter.  If it
 *  fails, it will display an error message and leave the File.fp set to NULL.
 */
extern boolean fileOpen (const char *const fileName, const langType language)
{    
#ifdef VMS
	const char *const openMode = "r";
#else
	const char *const openMode = "rb";
#endif
	boolean opened = FALSE;

	/*	If another file was already open, then close it.
	 */
	if (GSDG.File.fp != NULL)
	{
		fclose (GSDG.File.fp);  /* close any open source file */
		GSDG.File.fp = NULL;
	}

	GSDG.File.fp = fopen (fileName, openMode);
	if (GSDG.File.fp == NULL)
		error (WARNING | PERROR, "cannot open \"%s\"", fileName);
	else
	{
		opened = TRUE;

		setInputFileName (fileName);
		fgetpos (GSDG.File.fp, &(GSDG.StartOfLine));
		fgetpos (GSDG.File.fp, &(GSDG.File.filePosition));
		GSDG.File.currentLine  = NULL;
		GSDG.File.lineNumber   = 0L;
		GSDG.File.eof          = FALSE;
		GSDG.File.newLine      = TRUE;

		if (GSDG.File.line != NULL)
			vStringClear (GSDG.File.line);

		setSourceFileParameters (vStringNewInit (fileName));
		GSDG.File.source.lineNumber = 0L;

		verbose ("OPENING %s as %s language %sfile\n", fileName,
				getLanguageName (language),
				GSDG.File.source.isHeader ? "include " : "");
	}
	return opened;
}

extern void fileClose (void)
{
	if (GSDG.File.fp != NULL)
	{
		/*  The line count of the file is 1 too big, since it is one-based
		 *  and is incremented upon each newline.
		 */
		if (Option.printTotals)
		{
			fileStatus *status = eStat (vStringValue (GSDG.File.name));
			addTotals (0, GSDG.File.lineNumber - 1L, status->size);
		}
		fclose (GSDG.File.fp);
		GSDG.File.fp = NULL;
	}
}

extern boolean fileEOF (void)
{
	return GSDG.File.eof;
}

/*  Action to take for each encountered source newline.
 */
static void fileNewline (void)
{
	GSDG.File.filePosition = GSDG.StartOfLine;
	GSDG.File.newLine = FALSE;
	GSDG.File.lineNumber++;
	GSDG.File.source.lineNumber++;
	DebugStatement ( if (Option.breakLine == GSDG.File.lineNumber) lineBreak (); )
	DebugStatement ( debugPrintf (DEBUG_RAW, "%6ld: ", GSDG.File.lineNumber); )
}

/*  This function reads a single character from the stream, performing newline
 *  canonicalization.
 */
static int iFileGetc (void)
{
	int	c;
readnext:
	c = getc (GSDG.File.fp);

	/*	If previous character was a newline, then we're starting a line.
	 */
	if (GSDG.File.newLine  &&  c != EOF)
	{
		fileNewline ();
		if (c == '#'  &&  Option.lineDirectives)
		{
			if (parseLineDirective ())
				goto readnext;
			else
			{
				fsetpos (GSDG.File.fp, &(GSDG.StartOfLine));
				c = getc (GSDG.File.fp);
			}
		}
	}

	if (c == EOF)
		GSDG.File.eof = TRUE;
	else if (c == NEWLINE)
	{
		GSDG.File.newLine = TRUE;
		fgetpos (GSDG.File.fp, &(GSDG.StartOfLine));
	}
	else if (c == CRETURN)
	{
		/* Turn line breaks into a canonical form. The three commonly
		 * used forms if line breaks: LF (UNIX/Mac OS X), CR (Mac OS 9),
		 * and CR-LF (MS-DOS) are converted into a generic newline.
		 */
#ifndef macintosh
		const int next = getc (GSDG.File.fp);  /* is CR followed by LF? */
		if (next != NEWLINE)
			ungetc (next, GSDG.File.fp);
		else
#endif
		{
			c = NEWLINE;  /* convert CR into newline */
			GSDG.File.newLine = TRUE;
			fgetpos (GSDG.File.fp, &(GSDG.StartOfLine));
		}
	}
	DebugStatement ( debugPutc (DEBUG_RAW, c); )
	return c;
}

extern void fileUngetc (int c)
{
	GSDG.File.ungetch = c;
}

static vString *iFileGetLine (void)
{
	vString *result = NULL;
	int c;
	if (GSDG.File.line == NULL)
		GSDG.File.line = vStringNew ();
	vStringClear (GSDG.File.line);
	do
	{
		c = iFileGetc ();
		if (c != EOF)
			vStringPut (GSDG.File.line, c);
		if (c == '\n'  ||  (c == EOF  &&  vStringLength (GSDG.File.line) > 0))
		{
			vStringTerminate (GSDG.File.line);
#ifdef HAVE_REGEX
			if (vStringLength (GSDG.File.line) > 0)
				matchRegex (GSDG.File.line, GSDG.File.source.language);
#endif
			result = GSDG.File.line;
			break;
		}
	} while (c != EOF);
	Assert (result != NULL  ||  GSDG.File.eof);
	return result;
}

/*  Do not mix use of fileReadLine () and fileGetc () for the same file.
 */
extern int fileGetc (void)
{
	int c;

	/*  If there is an ungotten character, then return it.  Don't do any
	 *  other processing on it, though, because we already did that the
	 *  first time it was read through fileGetc ().
	 */
	if (GSDG.File.ungetch != '\0')
	{
		c = GSDG.File.ungetch;
		GSDG.File.ungetch = '\0';
		return c;  /* return here to avoid re-calling debugPutc () */
	}
	do
	{
		if (GSDG.File.currentLine != NULL)
		{
			c = *(GSDG.File).currentLine++;
			if (c == '\0')
				GSDG.File.currentLine = NULL;
		}
		else
		{
			vString* const line = iFileGetLine ();
			if (line != NULL)
				GSDG.File.currentLine = (unsigned char*) vStringValue (line);
			if (GSDG.File.currentLine == NULL)
				c = EOF;
			else
				c = '\0';
		}
	} while (c == '\0');
	DebugStatement ( debugPutc (DEBUG_READ, c); )
	return c;
}

extern int fileSkipToCharacter (int c)
{
	int d;
	do
	{
		d = fileGetc ();
	} while (d != EOF && d != c);
	return d;
}

/*  An alternative interface to fileGetc (). Do not mix use of fileReadLine()
 *  and fileGetc() for the same file. The returned string does not contain
 *  the terminating newline. A NULL return value means that all lines in the
 *  file have been read and we are at the end of file.
 */
extern const unsigned char *fileReadLine (void)
{
	vString* const line = iFileGetLine ();
	const unsigned char* result = NULL;
	if (line != NULL)
	{
		result = (const unsigned char*) vStringValue (line);
		vStringStripNewline (line);
		DebugStatement ( debugPrintf (DEBUG_READ, "%s\n", result); )
	}
	return result;
}

/*
 *   Source file line reading with automatic buffer sizing
 */
extern char *readLine (vString *const vLine, FILE *const fp)
{
	char *result = NULL;

	vStringClear (vLine);
	if (fp == NULL)  /* to free memory allocated to buffer */
		error (FATAL, "NULL file pointer");
	else
	{
		boolean reReadLine;

		/*  If reading the line places any character other than a null or a
		 *  newline at the last character position in the buffer (one less
		 *  than the buffer size), then we must resize the buffer and
		 *  reattempt to read the line.
		 */
		do
		{
			char *const pLastChar = vStringValue (vLine) + vStringSize (vLine) -2;
			fpos_t startOfLine;

			fgetpos (fp, &startOfLine);
			reReadLine = FALSE;
			*pLastChar = '\0';
			result = fgets (vStringValue (vLine), (int) vStringSize (vLine), fp);
			if (result == NULL)
			{
				if (! feof (fp))
					error (FATAL | PERROR, "Failure on attempt to read file");
			}
			else if (*pLastChar != '\0'  &&
					 *pLastChar != '\n'  &&  *pLastChar != '\r')
			{
				/*  buffer overflow */
				reReadLine = vStringAutoResize (vLine);
				if (reReadLine)
					fsetpos (fp, &startOfLine);
				else
					error (FATAL | PERROR, "input line too big; out of memory");
			}
			else
			{
				char* eol;
				vStringSetLength (vLine);
				/* canonicalize new line */
				eol = vStringValue (vLine) + vStringLength (vLine) - 1;
				if (*eol == '\r')
					*eol = '\n';
				else if (*(eol - 1) == '\r'  &&  *eol == '\n')
				{
					*(eol - 1) = '\n';
					*eol = '\0';
					--vLine->length;
				}
			}
		} while (reReadLine);
	}
	return result;
}

/*  Places into the line buffer the contents of the line referenced by
 *  "location".
 */
extern char *readSourceLine (
		vString *const vLine, fpos_t location, long *const pSeekValue)
{
	fpos_t orignalPosition;
	char *result;

	fgetpos (GSDG.File.fp, &orignalPosition);
	fsetpos (GSDG.File.fp, &location);
	if (pSeekValue != NULL)
		*pSeekValue = ftell (GSDG.File.fp);
	result = readLine (vLine, GSDG.File.fp);
	if (result == NULL)
		error (FATAL, "Unexpected end of file: %s", vStringValue (GSDG.File.name));
	fsetpos (GSDG.File.fp, &orignalPosition);

	return result;
}

/* vi:set tabstop=4 shiftwidth=4: */
