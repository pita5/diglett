/* ==========================================================================
 * arena/arena.h.in - Custom Memory Allocator Interface
 * --------------------------------------------------------------------------
 * Copyright (c) 2006  William Ahern
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to permit
 * persons to whom the Software is furnished to do so, subject to the
 * following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
 * NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
 * USE OR OTHER DEALINGS IN THE SOFTWARE.
 * ==========================================================================
 */
#ifndef ARENA_ARENA_H
#define ARENA_ARENA_H


#include <stdarg.h>	/* Be helpful with va_list */


//typedef struct arena struct arena;


extern const struct arena_options {
	size_t alignment;
	size_t blocklen;
} arena_defaults;


struct arena *arena_open(const struct arena_options *, const struct arena_prototype *);

void arena_close(struct arena *);

const struct arena_prototype *arena_export(struct arena *);

void *arena_malloc(struct arena *, size_t, size_t);

void *arena_realloc(struct arena *, void *, size_t, size_t);

void arena_free(struct arena *, void *);

void arena_mark(struct arena *, void **);

void arena_reset(struct arena *, void *);

struct arena *arena_import(const struct arena_prototype *);

const char *arena_strerror(struct arena *);

void arena_clearerr(struct arena *);

char *arena_strdup(struct arena *, const char *);

char *arena_strndup(struct arena *, const char *, size_t);

void *arena_memdup(struct arena *, const void *, size_t);

#ifndef __GNUC__
#ifndef __attribute__
#define __attribute__(x)
#endif
#endif

int arena_vasprintf(struct arena *, char **, const char *, va_list)
	__attribute__((__format__ (printf, 3, 0)));

int arena_asprintf(struct arena *, char **, const char *, ...)
	__attribute__((__format__ (printf, 3, 4)));

char *arena_vsprintf(struct arena *, const char *, va_list)
	__attribute__((__format__ (printf, 2, 0)));

char *arena_sprintf(struct arena *, const char *, ...)
	__attribute__((__format__ (printf, 2, 3)));

#endif /* ARENA_ARENA_H */

