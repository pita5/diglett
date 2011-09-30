//
//  DGScanner.m
//  diglett
//
//  Created by Alex Gordon on 30/09/2011.
//  Copyright 2011 Fileability. All rights reserved.
//

#import "DGScanner.h"

#include <sys/stat.h>

#import "CHThreadNonLocal.h"

static inline NSTimeInterval CHTimespecToTimeInterval(struct timespec ts)
{
	return (ts.tv_sec - NSTimeIntervalSince1970) + (ts.tv_nsec / 1000000000);
}
BOOL CHDirectoryShouldBeIndexed(NSString *dirpath)
{
	// Don't index the motherfucking home directory!
	if ([dirpath isEqual:NSHomeDirectory()])
		return NO;
	
	NSArray *localVolumes = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
	NSArray *removableMedia = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];
	
	for (NSString *v in removableMedia)
	{
		NSString *vv = [v stringByStandardizingPath];
        
		if ([[dirpath lowercaseString] hasPrefix:[vv lowercaseString]])
			return NO;
	}
	
	for (NSString *v in localVolumes)
	{
		NSString *vv = [v stringByStandardizingPath];
		
		if ([dirpath isEqual:vv])
			return NO;
		if ([[dirpath lowercaseString] hasPrefix:[vv lowercaseString]])
			return YES;
	}
	
	return NO;
}


@implementation DGScanner

@synthesize indexHiddenFiles;
@synthesize indexPackages;
@synthesize isCountLimited;
@synthesize indexingCompletionBlock;
@synthesize hasStopped;

- (void)scanDirectory:(NSString *)directory database:(CHXMainDatabase *)database
{
	NSLog(@"Scan directory: %@, database: %@", directory, database);
	NSString *dirpath = CHThreadNonLocal([directory stringByStandardizingPath]);
	directory = dirpath;
	
	// Is this a non local volume or removable media?
	if (!CHDirectoryShouldBeIndexed(dirpath))
	{
		NSLog(@"Should not be indexed");
		return;
	}
	
	if (![directory hasSuffix:@"/"])
		directory = [directory stringByAppendingString:@"/"];
	
	NSMutableSet *allNonignoredPaths = CHThreadNonLocal([[NSMutableSet alloc] init]);
	NSMutableSet *allIgnoredPaths = CHThreadNonLocal([[NSMutableSet alloc] init]);
    
	// NSMutableDictionary{ generator_name, NSMutableDictionary{ path, timestamp } }
	NSMutableDictionary *passPathTimestampMappings = CHThreadNonLocal([[NSMutableDictionary alloc] init]);
	
	
	//A mapping between document file paths and when they were last changed
	NSMutableDictionary *documentPathTimestampMappings = CHThreadNonLocal([[NSMutableDictionary alloc] init]);
	
	dispatch_group_t group = dispatch_group_create();
	
	//Get all resources for that database
	dispatch_sync(database.queue, ^{
		if (!database.db)
			return;
		
		NSLog(@"databasePath : %@", [database.db databasePath]);
		
		NSString *query = @"SELECT resources.path, resources.is_ignored, passes.timestamp, passes.generator_name"
        @"FROM resources LEFT JOIN passes ON passes.resource = resources.id"
        @"WHERE resources.path LIKE ? || '%'";
		FMResultSet *results = [database.db executeQuery:query, directory];
		while ([results next]) {
			
			NSString *resourcePath = CHThreadNonLocal([[results stringForColumnIndex:0] copy]);
			BOOL resourceIsIgnored = [results boolForColumnIndex:1];
			double passTimestamp = [results doubleForColumnIndex:2];
			NSString *passGenerator = CHThreadNonLocal([[results stringForColumnIndex:3] copy]);
			
			if (![resourcePath length])
				continue;
			
			//NSLog(@"resource: %@ | %d | %lf | %@", resourcePath, resourceIsIgnored, passTimestamp, passGenerator);
			
			//If the resource has been ignored, then we know it has no passes
			if (resourceIsIgnored || ![passGenerator length])
			{
				[allIgnoredPaths addObject:resourcePath];
				continue;
			}
			
			dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
				BOOL shouldPerformPass = NO;
				
				//If the resource has an associated document, and it has been edited since the last path, then we need to perform a pass
				NSNumber *documentTimestamp = [documentPathTimestampMappings valueForKey:resourcePath];
				if (documentTimestamp && [documentTimestamp doubleValue] > passTimestamp)
					shouldPerformPass = YES;
				
				if (!shouldPerformPass)
				{
					//If the resource's file has been modified since then, we should perform a pass in that case too
					NSError *err = nil;
					
					//TODO: We should probably use stat(2) for this instead
					//NSDate *fileTimestamp = [[[NSFileManager defaultManager] attributesOfItemAtPath:resourcePath error:&err] valueForKey:NSFileModificationDate];
					//double fileTimestampDouble = [fileTimestamp timeIntervalSinceReferenceDate];
                    
					struct stat s;
					int statworked = [resourcePath fileSystemRepresentation] ? lstat([resourcePath fileSystemRepresentation], &s) : -1;
					if (statworked == 0)
					{
						double fileTimestampDoubleStat = CHTimespecToTimeInterval(s.st_mtimespec);
						//NSLog(@"fileTimestampDoubleStat %lf | %lf", fileTimestampDoubleStat, fileTimestampDoubleStat - passTimestamp);
						
						//NSLog(@"eq %d ?  diff %lf |  objc %lf |  stat %lf", fileTimestampDouble == fileTimestampDoubleStat, fileTimestampDoubleStat - fileTimestampDouble, fileTimestampDouble, fileTimestampDoubleStat);
						
						NSLog(@"ZTZZTZ %d %lf %lf %lf\n %@", shouldPerformPass, fileTimestampDoubleStat, passTimestamp, fileTimestampDoubleStat - passTimestamp, resourcePath);
						if (fileTimestampDoubleStat > passTimestamp)
							shouldPerformPass = YES;
					}
				}
				
				if (shouldPerformPass)
				{
					NSMutableSet *generatorMapping = [passPathTimestampMappings objectForKey:passGenerator];
					
					if (!generatorMapping)
						[passPathTimestampMappings setValue:[NSMutableSet setWithObject:resourcePath] forKey:passGenerator];
					else
						[generatorMapping addObject:resourcePath];
					
					
					[allNonignoredPaths addObject:resourcePath];
				}
				else
				{
					[allIgnoredPaths addObject:resourcePath];
				}
			});
			
		}
		
		[results close];
	});
	
	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
	dispatch_release(group);
	
	
	
	//NSLog(@"ignored = %@", allIgnoredPaths);
	//NSLog(@"nonignored =  %@", allNonignoredPaths);
	NSLog(@"mappings = %@", passPathTimestampMappings);
	
	NSDirectoryEnumerationOptions opts = 0;//NSDirectoryEnumerationSkipsSubdirectoryDescendants;
	if (!indexHiddenFiles)
		opts |= NSDirectoryEnumerationSkipsHiddenFiles;
	
	if (!indexPackages)
		opts |= NSDirectoryEnumerationSkipsPackageDescendants;
	
	//Recurse the directory
	NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:dirpath isDirectory:YES] includingPropertiesForKeys:nil options:opts errorHandler:NULL];
	__block NSUInteger indexCount = 0;
	
	NSUInteger maximum = 1000;
	
	NSTimeInterval observationStageStart = [NSDate timeIntervalSinceReferenceDate];
	int observationCount = 0;
	BOOL shouldSlowDown = NO;
	NSTimeInterval slowdown = 0.0;
	NSTimeInterval totalTime = 0.0;
	
	
	for (NSURL *absoluteURL in directoryEnumerator)
	{
		// Work out our slowdown
		if (observationCount == 10)
		{
			const CGFloat slowdownFactor = 4.0;
			slowdown = (slowdownFactor - 1.0) * totalTime /*([NSDate timeIntervalSinceReferenceDate] - observationStageStart) */ / observationCount;
			shouldSlowDown = YES;
		}
		
		// Only index 400 files in one shot
		if (isCountLimited && indexCount >= maximum)
			break;
		
		if ([project checkStopped])
			return;
		
		NSString *absolutePath = [absoluteURL path];
		
		//If it's an ignored path, give up
		if ([allIgnoredPaths containsObject:absolutePath])
		{
			continue;
		}
		
		//If it's not a nonignored path, we need to add it to resources and maybe pass it
		if (![allNonignoredPaths containsObject:absolutePath])
		{
			NSString *absoluteName = [absolutePath lastPathComponent];
            
			//Find out if ignored
			NSString *language = [self detectLanguageForPath:absolutePath];
			if (language == nil)
				continue;
			
			BOOL isIgnored = (language == nil);
			
			__block int64_t rid = -1;
			
			//Add to resources
			dispatch_sync(database.queue, ^{
				NSLog(@"Adding Resource | Name: %@ | Path: %@ | Language: %@ | Is Ignored? %@", absoluteName, absolutePath, language, (isIgnored ? @"Yes" : @"No")); 
				[database.db executeUpdate:@"INSERT INTO resources (name, path, language, is_ignored) VALUES (?, ?, ?, ?)", absoluteName, absolutePath, language, [NSNumber numberWithBool:isIgnored]];
				rid = [database.db lastInsertRowId];
			});
			
			//Do a pass?
			if (!isIgnored)
			{
				for (NSString *generator in [self generatorsForLanguage:language])
				{
					NSTimeInterval t = 0.0;
					if (!shouldSlowDown)
						t = [NSDate timeIntervalSinceReferenceDate];
					
					[self doPass:absolutePath generator:generator language:language database:database resourceID:rid];
					
					if (!shouldSlowDown)
						totalTime += [NSDate timeIntervalSinceReferenceDate] - t;
					
					
					indexCount++;
					observationCount++;
					
					if (indexingCompletionBlock)
						indexingCompletionBlock(((CGFloat)indexCount) / ((CGFloat)maximum), NO);
					
					//Pretty sure this is undefined behaviour...
					if (shouldSlowDown)
						[NSThread sleepForTimeInterval:slowdown];
				}
			}
			
			continue;
		}
		
		//If it's a in passPathTimestampMappings we need to run those passes
		
		for (NSString *generator in passPathTimestampMappings)
		{
			// I have no idea what any of this does now that I changed @"generator" to generator
			//...
			NSSet *mapping = [passPathTimestampMappings valueForKey:generator];
			
			if ([mapping containsObject:absolutePath])
			{
				__block int64_t rid = -1;
				__block NSString *language = nil;
				
				dispatch_sync(database.queue, ^{
					FMResultSet *rset = [database.db executeQuery:@"SELECT id, language FROM resources WHERE path = ?", absolutePath];
					if ([rset next])
					{
						rid = [rset longLongIntForColumnIndex:0];
						language = [rset stringForColumnIndex:1];
					}
					[rset close];
				});
				
				if (rid >= 1)
				{
					NSTimeInterval t = 0.0;
					if (!shouldSlowDown)
						t = [NSDate timeIntervalSinceReferenceDate];
					
					[self doPass:absolutePath generator:generator language:language database:database resourceID:rid];
					
					if (!shouldSlowDown)
						totalTime += [NSDate timeIntervalSinceReferenceDate] - t;
					
					
					
					indexCount++;
					observationCount++;
					
					if (indexingCompletionBlock)
						indexingCompletionBlock(((CGFloat)indexCount) / ((CGFloat)maximum), NO);
					
					if (shouldSlowDown)
						[NSThread sleepForTimeInterval:slowdown];
				}
			}
		}
	}
	
	if (indexingCompletionBlock)
		indexingCompletionBlock(1.0, YES);
	
	return nil;
}
- (void)doPass:(NSString *)filePath generator:(NSString *)generator language:(NSString *)language database:(CHXMainDatabase *)database resourceID:(int64_t)rid
{
	if ([generator isEqual:@"ctags"])
	{
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
			[CHXExuberantCtagsParser parsePath:filePath orContents:nil database:database language:language resourceID:rid];
		});
	}
}
- (NSString *)detectLanguageForPath:(NSString *)p
{
	if (!languages)
	{
		/*
         Ant      *.build.xml
         Asm      *.asm *.ASM *.s *.S *.A51 *.29[kK] *.[68][68][kKsSxX] *.[xX][68][68]
         Asp      *.asp *.asa
         Awk      *.awk *.gawk *.mawk
         Basic    *.bas *.bi *.bb *.pb
         BETA     *.bet
         C        *.c
         C++      *.c++ *.cc *.cp *.cpp *.cxx *.h *.h++ *.hh *.hp *.hpp *.hxx
         C#       *.cs
         Cobol    *.cbl *.cob *.CBL *.COB
         DosBatch *.bat *.cmd
         Eiffel   *.e
         Erlang   *.erl *.ERL *.hrl *.HRL
         Flex     *.as *.mxml
         Fortran  *.f *.for *.ftn *.f77 *.f90 *.f95
         HTML     *.htm *.html
         Java     *.java
         JavaScript *.js
         Lisp     *.cl *.clisp *.el *.l *.lisp *.lsp
         Lua      *.lua
         Make     *.mak *.mk [Mm]akefile GNUmakefile
         MatLab   *.m
         OCaml    *.ml *.mli
         Pascal   *.p *.pas
         Perl     *.pl *.pm *.plx *.perl
         PHP      *.php *.php3 *.phtml
         Python   *.py *.pyx *.pxd *.pxi *.scons
         REXX     *.cmd *.rexx *.rx
         Ruby     *.rb *.ruby
         Scheme   *.SCM *.SM *.sch *.scheme *.scm *.sm
         Sh       *.sh *.SH *.bsh *.bash *.ksh *.zsh
         SLang    *.sl
         SML      *.sml *.sig
         SQL      *.sql
         Tcl      *.tcl *.tk *.wish *.itcl
         Tex      *.tex
         Vera     *.vr *.vri *.vrh
         Verilog  *.v
         VHDL     *.vhdl *.vhd
         Vim      *.vim
         YACC     *.y
         */
		
		languages = [[NSMutableDictionary alloc] init];
		
#define EXTN(tolang, fromext) [languages setValue:tolang forKey:fromext]
		
		EXTN(@"Asm", @"asm");
		EXTN(@"Asm", @"s");
		EXTN(@"Asm", @"68k");
		EXTN(@"Asm", @"x86");
		EXTN(@"Asm", @"x64");
		EXTN(@"Asm", @"arm");
		
		EXTN(@"Asp", @"asp");
		EXTN(@"Asp", @"asa");
        
		EXTN(@"Awk", @"awk");
		EXTN(@"Awk", @"gawk");
		EXTN(@"Awk", @"mawk");
        
		EXTN(@"Basic", @"bas");
		EXTN(@"Basic", @"bi");
		EXTN(@"Basic", @"bb");
		EXTN(@"Basic", @"pb");
        
		EXTN(@"BETA", @"bet");
        
		EXTN(@"C", @"c");
        
		EXTN(@"C++", @"c++");
		EXTN(@"C++", @"cc");
		EXTN(@"C++", @"cp");
		EXTN(@"C++", @"cpp");
		EXTN(@"C++", @"cxx");
		EXTN(@"C++", @"h++");
		EXTN(@"C++", @"hh");
		EXTN(@"C++", @"hp");
		EXTN(@"C++", @"hpp");
		EXTN(@"C++", @"hxx");
		
		EXTN(@"C#", @"cs");
		
		EXTN(@"COBOL", @"cbl");
		EXTN(@"COBOL", @"cob");
		
		EXTN(@"DosBatch", @"bat");
		EXTN(@"DosBatch", @"cmd");
		
		EXTN(@"Eiffel", @"e");
		
		EXTN(@"Erlang", @"erl");
		EXTN(@"Erlang", @"hrl");
		
		EXTN(@"Flex", @"as");
		EXTN(@"Flex", @"mxml");
		
		EXTN(@"Fortran", @"f");
		EXTN(@"Fortran", @"for");
		EXTN(@"Fortran", @"ftn");
		EXTN(@"Fortran", @"f77");
		EXTN(@"Fortran", @"f90");
		EXTN(@"Fortran", @"f95");
		
		EXTN(@"HTML", @"html");
		EXTN(@"HTML", @"html");
		
		EXTN(@"Java", @"java");
		
		EXTN(@"JavaScript", @"js");
		
		EXTN(@"Lisp", @"cl");
		EXTN(@"Lisp", @"clisp");
		EXTN(@"Lisp", @"el");
		EXTN(@"Lisp", @"l");
		EXTN(@"Lisp", @"lisp");
		EXTN(@"Lisp", @"lsp");
		
		EXTN(@"Lua", @"lua");
		
		EXTN(@"Make", @"mak");
		EXTN(@"Make", @"mk");
		
		EXTN(@"MatLab", @"m");
		
		EXTN(@"OCaml", @"ml");
		EXTN(@"OCaml", @"mli");
		
		EXTN(@"Pascal", @"p");
		EXTN(@"Pascal", @"pas");
		
		EXTN(@"Perl", @"pl");
		EXTN(@"Perl", @"pm");
		EXTN(@"Perl", @"plx");
		EXTN(@"Perl", @"perl");
		
		EXTN(@"PHP", @"php");
		EXTN(@"PHP", @"php3");
		EXTN(@"PHP", @"phtml");
		
		EXTN(@"Python", @"py");
		EXTN(@"Python", @"rpy");
		EXTN(@"Python", @"pyx");
		EXTN(@"Python", @"pxd");
		EXTN(@"Python", @"pxi");
		EXTN(@"Python", @"scons");
		
		EXTN(@"REXX", @"cmd");
		EXTN(@"REXX", @"rexx");
		EXTN(@"REXX", @"rx");
		
		EXTN(@"Ruby", @"rb");
		EXTN(@"Ruby", @"ruby");
		
		EXTN(@"Scheme", @"scm");
		EXTN(@"Scheme", @"sm");
		EXTN(@"Scheme", @"sch");
		EXTN(@"Scheme", @"scheme");
		EXTN(@"Scheme", @"scm");
        
		EXTN(@"Sh", @"sh");
		EXTN(@"Sh", @"bsh");
		EXTN(@"Sh", @"bash");
		EXTN(@"Sh", @"csh");
		EXTN(@"Sh", @"ksh");
		EXTN(@"Sh", @"zsh");
		
		EXTN(@"SLang", @"sl");
		
		EXTN(@"SML", @"sml");
		EXTN(@"SML", @"sig");
		
		EXTN(@"SQL", @"sql");
		
		EXTN(@"Tcl", @"tcl");
		EXTN(@"Tcl", @"tk");
		EXTN(@"Tcl", @"wish");
		EXTN(@"Tcl", @"itcl");
		
		EXTN(@"Tex", @"tex");
		EXTN(@"Tex", @"latex");
		
		EXTN(@"Sh", @"sh");
		
		EXTN(@"Vera", @"vr");
		EXTN(@"Vera", @"vri");
		EXTN(@"Vera", @"vrh");
		
		EXTN(@"Verilog", @"v");
		
		EXTN(@"VHDL", @"vhdl");
		EXTN(@"VHDL", @"vhd");
		
		EXTN(@"Vim", @"vim");
		
		EXTN(@"YACC", @"y");
		
		
		//Things that probably need to be replaced with more suited utilities
		//Clojure
		//EXTN(@"Lisp", @"clj");
		
		//Arc
		//EXTN(@"Lisp", @"arc");
		
		//Objective-C
		//EXTN(@"C", @"m");
		//EXTN(@"C++", @"mm");
		EXTN(@"C++", @"h");
	}
	
	return [languages objectForKey:[[p pathExtension] lowercaseString]];
}
- (NSArray *)generatorsForLanguage:(NSString *)lang
{
	return [NSArray arrayWithObject:@"ctags"];
}
- (BOOL)checkStopped
{
	if (hasStopped)
	{
		hasStopped = NO;
		return YES;
	}
	return NO;
}

@end
