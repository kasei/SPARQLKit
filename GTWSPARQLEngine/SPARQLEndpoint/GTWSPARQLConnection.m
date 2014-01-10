//
//  GTWSPARQLConnection.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 11/16/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "GTWSPARQLConnection.h"
#import <GTWSWBase/GTWSWBase.h>
#import "SPKSimpleQueryEngine.h"
#import "HTTPDataResponse.h"
#import "GTWSPARQLConfig.h"
#import "SPKSPARQLParser.h"
#import "SPARQLKit.h"
#import "SPKQueryPlanner.h"
#import "SPKSPARQLResultsXMLSerializer.h"
#import "SPKSPARQLResultsTextTableSerializer.h"
#import "HTTPMessage.h"
#import "HTTPErrorResponse.h"
#import "zlib.h"
#import "NSObject+SPKTree.h"
#import "GTWHTTPCachedResponse.h"
#import "GTWHTTPDataResponse.h"

static NSString* ENDPOINT_PATH    = @"/sparql";

@implementation GTWSPARQLConnection

- (NSDate*) dateFromString:(NSString*)string {
	static NSDateFormatter *df;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];
	});
    return [df dateFromString:string];
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path {
//    NSLog(@"---> %@", [request allHeaderFields]);
    GTWSPARQLConfig* cfg = (GTWSPARQLConfig*) config;
    id<GTWModel> model  = cfg.model;
    GTWDataset* dataset = cfg.dataset;
    
	NSString *filePath = [self filePathForURI:path];
	NSString *documentRoot = [config documentRoot];
	if (![filePath hasPrefix:documentRoot]) {
		// Uh oh.
		// HTTPConnection's filePathForURI was supposed to take care of this for us.
		return nil;
	}
	
	NSString *relativePath = [filePath substringFromIndex:[documentRoot length]];
    if ([relativePath isEqualToString:ENDPOINT_PATH]) {
        NSDictionary* params    = [self parseGetParams];
        NSString* query         = params[@"query"];
        if (query) {
            BOOL verbose    = NO;
            id<SPKSPARQLParser> parser  = [[SPKSPARQLParser alloc] init];
            NSError* error;
            id<SPKTree> algebra    = [parser parseSPARQLQuery:query withBaseURI:cfg.base settingPrefixes:nil error:&error];
            if (error) {
                NSLog(@"parser error: %@", error);
            }
            if (verbose) {
                NSLog(@"query:\n%@", algebra);
            }
            
            SPKQueryPlanner* planner        = [[SPKQueryPlanner alloc] init];
            NSObject<SPKTree,GTWQueryPlan>* plan   = [planner queryPlanForAlgebra:algebra usingDataset:dataset withModel: model optimize:YES options:nil];
            if (verbose) {
                NSLog(@"plan:\n%@", plan);
            }
            
            NSSet* aps  = [plan spk_accessPatterns];
//            NSLog(@"Access patterns: %@", aps);
            NSDate* lastModified    = nil;
            for (id<SPKTree> ap in aps) {
                if ([ap.type isEqual:kTreeQuad]) {
                    id<GTWQuad> q   = ap.value;
//                    NSLog(@"\nQuad -> %@", q);
                    NSDate* date    = [model lastModifiedDateForQuadsMatchingSubject:q.subject predicate:q.predicate object:q.object graph:q.graph error:&error];
                    if (date) {
                        if (!(lastModified) || [lastModified compare:date] == NSOrderedDescending) {
                            lastModified    = date;
                        }
                    }
                } else {
                    NSLog(@"*** Unexpected tree node type in access patterns list: %@", ap);
                }
            }

            NSString* ims   = [request headerField:@"If-Modified-Since"];
            if (ims) {
                NSDate* lastAccess    = [self dateFromString:ims];
                if (lastAccess && lastModified) {
//                    NSLog(@"If-Modified-Since: %@", lastAccess);
//                    NSLog(@"Last-Modified: %@", lastModified);
                    if ([lastModified compare:lastAccess] != NSOrderedDescending) {
                        HTTPDataResponse* resp     = [[GTWHTTPCachedResponse alloc] init];
                        return resp;
                    }
                }
            }
            
            NSSet* variables    = [plan inScopeVariables];
            if (verbose) {
                NSLog(@"executing query...");
            }
            id<GTWQueryEngine> engine           = [[SPKSimpleQueryEngine alloc] init];
            NSEnumerator* e                     = [engine evaluateQueryPlan:plan withModel:model];
            id<GTWSPARQLResultsSerializer> s    = [[SPKSPARQLResultsXMLSerializer alloc] init];
            
//            NSLog(@"Last-Modified: %@", lastModified);
            NSData* data        = [s dataFromResults:e withVariables:variables];
            GTWHTTPDataResponse* resp     = [[GTWHTTPDataResponse alloc] initWithData:data];
            
            if (lastModified) {
                resp.lastModified   = lastModified;
            }
            return resp;
        } else {
            return [self queryForm];
        }
	}
	
	return [super httpResponseForMethod:method URI:path];
}

- (NSObject<HTTPResponse>*) queryForm {
    // Request for /sparql without a ?query parameter
    // TODO: return a query template html form
    return [[HTTPErrorResponse alloc] initWithErrorCode:400];
}

- (NSData *)preprocessResponse:(HTTPMessage *)response {
//    NSLog(@"preprocessResponse: %@", response);
    NSString* ae    = [request headerField:@"Accept-Encoding"];
    if (ae) {
        NSRange range   = [ae rangeOfString:@"gzip" options:NSRegularExpressionSearch];
        if (range.location != NSNotFound) {
            NSMutableData* content  = [NSMutableData data];
            while (![httpResponse isDone]) {
                [content appendData:[httpResponse readDataOfLength: 1024]];
            }
            if ([content length] > 0) {
                NSData* compressed  = [GTWSPARQLConnection gzipData:content];
                if (compressed) {
                    NSDate* lastModified;
                    if ([httpResponse respondsToSelector:@selector(lastModified)]) {
                        lastModified    = [(GTWHTTPDataResponse*)httpResponse lastModified];
                    }
                    GTWHTTPDataResponse* resp   = [[GTWHTTPDataResponse alloc] initWithData:compressed];
                    if (lastModified) {
                        resp.lastModified   = lastModified;
                    }
                    httpResponse    = resp;
                    [response setHeaderField:@"Content-Encoding" value:@"gzip"];
                    NSString *contentLengthStr = [NSString stringWithFormat:@"%qu", (unsigned long long)[compressed length]];
                    [response setHeaderField:@"Content-Length" value:contentLengthStr];
                }
            }
        }
    }
    
    return [super preprocessResponse:response];
}

/**
 gzip code by Clint Harris, release into the public domain: http://www.clintharris.net/2009/how-to-gzip-data-in-memory-using-objective-c/
 */
+(NSData*) gzipData: (NSData*)pUncompressedData {
	/*
	 Special thanks to Robbie Hanson of Deusty Designs for sharing sample code
	 showing how deflateInit2() can be used to make zlib generate a compressed
	 file with gzip headers:
     
     http://deusty.blogspot.com/2007/07/gzip-compressiondecompression.html
     
	 */
    
	if (!pUncompressedData || [pUncompressedData length] == 0)
	{
		NSLog(@"%s: Error: Can't compress an empty or null NSData object.", __func__);
		return nil;
	}
    
	/* Before we can begin compressing (aka "deflating") data using the zlib
	 functions, we must initialize zlib. Normally this is done by calling the
	 deflateInit() function; in this case, however, we'll use deflateInit2() so
	 that the compressed data will have gzip headers. This will make it easy to
	 decompress the data later using a tool like gunzip, WinZip, etc.
     
	 deflateInit2() accepts many parameters, the first of which is a C struct of
	 type "z_stream" defined in zlib.h. The properties of this struct are used to
	 control how the compression algorithms work. z_stream is also used to
	 maintain pointers to the "input" and "output" byte buffers (next_in/out) as
	 well as information about how many bytes have been processed, how many are
	 left to process, etc. */
	z_stream zlibStreamStruct;
	zlibStreamStruct.zalloc    = Z_NULL; // Set zalloc, zfree, and opaque to Z_NULL so
	zlibStreamStruct.zfree     = Z_NULL; // that when we call deflateInit2 they will be
	zlibStreamStruct.opaque    = Z_NULL; // updated to use default allocation functions.
	zlibStreamStruct.total_out = 0; // Total number of output bytes produced so far
	zlibStreamStruct.next_in   = (Bytef*)[pUncompressedData bytes]; // Pointer to input bytes
	zlibStreamStruct.avail_in  = (unsigned int) [pUncompressedData length]; // Number of input bytes left to process
    
	/* Initialize the zlib deflation (i.e. compression) internals with deflateInit2().
	 The parameters are as follows:
     
	 z_streamp strm - Pointer to a zstream struct
	 int level      - Compression level. Must be Z_DEFAULT_COMPRESSION, or between
     0 and 9: 1 gives best speed, 9 gives best compression, 0 gives
     no compression.
	 int method     - Compression method. Only method supported is "Z_DEFLATED".
	 int windowBits - Base two logarithm of the maximum window size (the size of
     the history buffer). It should be in the range 8..15. Add
     16 to windowBits to write a simple gzip header and trailer
     around the compressed data instead of a zlib wrapper. The
     gzip header will have no file name, no extra data, no comment,
     no modification time (set to zero), no header crc, and the
     operating system will be set to 255 (unknown).
	 int memLevel   - Amount of memory allocated for internal compression state.
     1 uses minimum memory but is slow and reduces compression
     ratio; 9 uses maximum memory for optimal speed. Default value
     is 8.
	 int strategy   - Used to tune the compression algorithm. Use the value
     Z_DEFAULT_STRATEGY for normal data, Z_FILTERED for data
     produced by a filter (or predictor), or Z_HUFFMAN_ONLY to
     force Huffman encoding only (no string match) */
    int initError = deflateInit2(&zlibStreamStruct, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY);
	if (initError != Z_OK)
	{
		NSString *errorMsg = nil;
		switch (initError)
		{
			case Z_STREAM_ERROR:
				errorMsg = @"Invalid parameter passed in to function.";
				break;
			case Z_MEM_ERROR:
				errorMsg = @"Insufficient memory.";
				break;
			case Z_VERSION_ERROR:
				errorMsg = @"The version of zlib.h and the version of the library linked do not match.";
				break;
			default:
				errorMsg = @"Unknown error code.";
				break;
		}
		NSLog(@"%s: deflateInit2() Error: \"%@\" Message: \"%s\"", __func__, errorMsg, zlibStreamStruct.msg);
		return nil;
	}
    
	// Create output memory buffer for compressed data. The zlib documentation states that
	// destination buffer size must be at least 0.1% larger than avail_in plus 12 bytes.
	NSMutableData *compressedData = [NSMutableData dataWithLength:[pUncompressedData length] * 1.01 + 12];
    
	int deflateStatus;
	do
	{
		// Store location where next byte should be put in next_out
		zlibStreamStruct.next_out = (Bytef*) [compressedData mutableBytes] + zlibStreamStruct.total_out;
        
		// Calculate the amount of remaining free space in the output buffer
		// by subtracting the number of bytes that have been written so far
		// from the buffer's total capacity
		zlibStreamStruct.avail_out = (unsigned int) ([compressedData length] - zlibStreamStruct.total_out);
        
		/* deflate() compresses as much data as possible, and stops/returns when
		 the input buffer becomes empty or the output buffer becomes full. If
		 deflate() returns Z_OK, it means that there are more bytes left to
		 compress in the input buffer but the output buffer is full; the output
		 buffer should be expanded and deflate should be called again (i.e., the
		 loop should continue to rune). If deflate() returns Z_STREAM_END, the
		 end of the input stream was reached (i.e.g, all of the data has been
		 compressed) and the loop should stop. */
		deflateStatus = deflate(&zlibStreamStruct, Z_FINISH);
        
	} while ( deflateStatus == Z_OK );
    
	// Check for zlib error and convert code to usable error message if appropriate
	if (deflateStatus != Z_STREAM_END)
	{
		NSString *errorMsg = nil;
		switch (deflateStatus)
		{
			case Z_ERRNO:
				errorMsg = @"Error occured while reading file.";
				break;
			case Z_STREAM_ERROR:
				errorMsg = @"The stream state was inconsistent (e.g., next_in or next_out was NULL).";
				break;
			case Z_DATA_ERROR:
				errorMsg = @"The deflate data was invalid or incomplete.";
				break;
			case Z_MEM_ERROR:
				errorMsg = @"Memory could not be allocated for processing.";
				break;
			case Z_BUF_ERROR:
				errorMsg = @"Ran out of output buffer for writing compressed bytes.";
				break;
			case Z_VERSION_ERROR:
				errorMsg = @"The version of zlib.h and the version of the library linked do not match.";
				break;
			default:
				errorMsg = @"Unknown error code.";
				break;
		}
		NSLog(@"%s: zlib error while attempting compression: \"%@\" Message: \"%s\"", __func__, errorMsg, zlibStreamStruct.msg);
        
		// Free data structures that were dynamically created for the stream.
		deflateEnd(&zlibStreamStruct);
        
		return nil;
	}
	// Free data structures that were dynamically created for the stream.
	deflateEnd(&zlibStreamStruct);
	[compressedData setLength: zlibStreamStruct.total_out];
    if (NO) {
        if ([compressedData length] < 1024) {
            NSLog(@"%s: Compressed file from %lu B to %lu B", __func__, [pUncompressedData length], [compressedData length]);
        } else {
            NSLog(@"%s: Compressed file from %lu KB to %lu KB", __func__, [pUncompressedData length]/1024, [compressedData length]/1024);
        }
    }
    
	return compressedData;
}

@end
