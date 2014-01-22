//
//  SPKServiceDescriptionGenerator.m
//  SPARQLKit
//
//  Created by Gregory Williams on 1/21/14.
//  Copyright (c) 2014 Gregory Williams. All rights reserved.
//

#import "SPKServiceDescriptionGenerator.h"
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWIRI.h>
#import "NSDate+W3CDTFSupport.h"

#define PLURAL_INT_ARGS(p) (int)p, ((p > 1) ? @"s" : @"")

@implementation SPKServiceDescriptionGenerator

static void _generate_service_description ( id<GTWModel>model, id<GTWIRI> graph, NSUInteger quantile, void(^pred_cb)(NSString*, NSNumber*), void(^class_cb)(NSString*, NSNumber*) ) {
    if (!quantile)
        quantile    = 1;
	NSMutableDictionary* preds		= [[NSMutableDictionary alloc] init];
	NSMutableDictionary* classes	= [[NSMutableDictionary alloc] init];
    NSError* error;
	{
        GTWVariable* pv  = [[GTWVariable alloc] initWithValue:@"p"];
        [model enumerateBindingsMatchingSubject:nil predicate:pv object:nil graph:graph usingBlock:^(NSDictionary* result) {
            id<GTWTerm> pred    = result[@"p"];
            NSString* p         = pred.value;
			NSNumber* num       = preds[p];
			if (num == nil) {
				preds[p] = @1;
			} else {
				NSNumber* inc	= [NSNumber numberWithUnsignedLongLong:1+[num longLongValue]];
				preds[p] = inc;
			}
			return;
        } error:&error];
	}
	
	{
        GTWVariable* sv = [[GTWVariable alloc] initWithValue:@"s"];
        GTWVariable* cv = [[GTWVariable alloc] initWithValue:@"class"];
		GTWIRI* type	= [[GTWIRI alloc] initWithValue:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
        [model enumerateBindingsMatchingSubject:sv predicate:type object:cv graph:graph usingBlock:^(NSDictionary* result) {
            id<GTWTerm> class   = result[@"class"];
            NSString* p         = class.value;
			NSNumber* num	= classes[p];
			if (num == nil) {
				classes[p] = @1;
			} else {
				NSNumber* inc	= [NSNumber numberWithUnsignedLongLong:1+[num longLongValue]];
				classes[p] = inc;
			}
			return;
        } error:&error];
	}
    
	NSArray* pkeys	= [preds keysSortedByValueUsingSelector:@selector(compare:)];
	NSEnumerator* penum	= [pkeys reverseObjectEnumerator];
	int pcount	= 0;
	NSUInteger ptotal	= [pkeys count];
	NSUInteger pquant	= ptotal / quantile;
	for (id k in penum) {
		if (pcount++ > pquant)
			break;
		NSNumber* count	= preds[k];
		pred_cb(k, count);
	}
	
	NSArray* ckeys	= [classes keysSortedByValueUsingSelector:@selector(compare:)];
    
	int ccount	= 0;
	NSUInteger ctotal	= [ckeys count];
	NSUInteger cquant	= ctotal / quantile;
	NSEnumerator* cenum	= [ckeys reverseObjectEnumerator];
	for (id k in cenum) {
		if (ccount++ > cquant)
			break;
		NSNumber* count	= classes[k];
		class_cb(k, count);
	}
}

- (NSString*) serviceDescriptionStringForModel:(id<GTWModel>)model dataset:(id<GTWDataset>)dataset quantile:(NSUInteger)quantile {
    // TODO: produce output for all graphs in the dataset
    NSArray* dg         = [dataset defaultGraphs];
    id<GTWIRI> graph    = dg[0];
    
	__block NSMutableDictionary* preds		= [[NSMutableDictionary alloc] init];
	__block NSMutableDictionary* classes	= [[NSMutableDictionary alloc] init];
	_generate_service_description(
								  model,
								  graph,
								  quantile,
								  ^(NSString* pred, NSNumber* count){
									  preds[pred] = count;
								  },
								  ^(NSString* class, NSNumber* count){
									  classes[class] = count;
								  });
	NSMutableString* turtle	= [[NSMutableString alloc] init];
	
    NSError* error;
    NSUInteger count    = [model countQuadsMatchingSubject:nil predicate:nil object:nil graph:graph error:&error];
	
	[turtle appendFormat:@"@prefix sd: <http://www.w3.org/ns/sparql-service-description#> .\n"];
	[turtle appendFormat:@"@prefix void: <http://rdfs.org/ns/void#> .\n\n"];
	[turtle appendFormat:@"@prefix dcterms: <http://purl.org/dc/terms/> .\n\n"];
    
    
    NSDate* date    = [model lastModifiedDateForQuadsMatchingSubject:nil predicate:nil object:nil graph:nil error:&error];
	[turtle appendFormat:@"[] a sd:Service ;\n\tsd:endpoint <> ;\n\tsd:supportedLanguage sd:SPARQL11Query ;\n"];
	[turtle appendFormat:@"\tsd:defaultDataset [\n\t\ta sd:Dataset ;\n\t\tsd:defaultGraph <#default>\n\t\tdcterms:modified \"%@\" ;\n\t] .\n\n", [date getW3CDTFString]];
	
	[turtle appendFormat:@"<#default> a sd:Graph, void:Dataset ;\n"];
	[turtle appendFormat:@"\tvoid:triples %llu ;\n", (unsigned long long)count];
    
	NSArray* ckeys	= [classes keysSortedByValueUsingSelector:@selector(compare:)];
	NSEnumerator* cenum	= [ckeys reverseObjectEnumerator];
	for (id k in cenum) {
		NSNumber* count	= classes[k];
		[turtle appendFormat:@"\tvoid:classPartition [\n"];
		[turtle appendFormat:@"\t\tvoid:class <%@> ;\n", k];
		[turtle appendFormat:@"\t\tvoid:entities %llu ;\n", [count unsignedLongLongValue]];
		[turtle appendFormat:@"\t] ;\n"];
	}

    [turtle appendFormat:@"\n\n"];

	NSArray* pkeys	= [preds keysSortedByValueUsingSelector:@selector(compare:)];
	NSEnumerator* penum	= [pkeys reverseObjectEnumerator];
	for (id k in penum) {
		NSNumber* count	= preds[k];
		[turtle appendFormat:@"\tvoid:propertyPartition [\n"];
		[turtle appendFormat:@"\t\tvoid:property <%@> ;\n", k];
		[turtle appendFormat:@"\t\tvoid:entities %llu ;\n", [count unsignedLongLongValue]];
		[turtle appendFormat:@"\t] ;\n"];
	}
	
	[turtle appendFormat:@"\t.\n"];
	return turtle;
}

- (NSString*) lastModifiedAgo:(NSDate*)date {
    NSCalendar* cal     = [NSCalendar currentCalendar];
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit;
    NSDateComponents* comp  = [cal components:unitFlags fromDate:date toDate:[NSDate date] options:0];
    NSMutableArray* agos    = [NSMutableArray array];
    if (unitFlags & NSYearCalendarUnit && comp.year)
        [agos addObject:[NSString stringWithFormat:@"%d year%@", PLURAL_INT_ARGS(comp.year)]];
    if (unitFlags & NSMonthCalendarUnit && comp.month)
        [agos addObject:[NSString stringWithFormat:@"%d month%@", PLURAL_INT_ARGS(comp.month)]];
    if (unitFlags & NSDayCalendarUnit && comp.day)
        [agos addObject:[NSString stringWithFormat:@"%d day%@", PLURAL_INT_ARGS(comp.day)]];
    if (unitFlags & NSHourCalendarUnit && comp.hour)
        [agos addObject:[NSString stringWithFormat:@"%d hour%@", PLURAL_INT_ARGS(comp.hour)]];
    if (unitFlags & NSMinuteCalendarUnit && comp.minute)
        [agos addObject:[NSString stringWithFormat:@"%d minute%@", PLURAL_INT_ARGS(comp.minute)]];
    
    NSString* ago = [agos componentsJoinedByString:@", "];
    return ago;
}

- (void) printServiceDescriptionToFile:(FILE*)f forModel:(id<GTWModel>)model dataset:(id<GTWDataset>)dataset quantile:(NSUInteger)quantile {
    // TODO: produce output for all graphs in the dataset
    NSArray* dg         = [dataset defaultGraphs];
    id<GTWIRI> graph    = dg[0];

	__block NSMutableDictionary* preds		= [[NSMutableDictionary alloc] init];
	__block NSMutableDictionary* classes	= [[NSMutableDictionary alloc] init];
	_generate_service_description(
								  model,
								  graph,
								  quantile,
								  ^(NSString* pred, NSNumber* count){
									  preds[pred] = count;
								  },
								  ^(NSString* class, NSNumber* count){
									  classes[class] = count;
								  });
	
    NSError* error;
    NSUInteger count    = [model countQuadsMatchingSubject:nil predicate:nil object:nil graph:graph error:&error];
    NSDate* date        = [model lastModifiedDateForQuadsMatchingSubject:nil predicate:nil object:nil graph:nil error:&error];
    NSString* ago       = [self lastModifiedAgo:date];
    
    for (id<GTWTerm> g in dg) {
        fprintf(f, "Default graph : %s\n", [g.value UTF8String]);
    }
    fprintf(f, "Triples       : %lld\n", (unsigned long long)count);
    fprintf(f, "Last-Modified : %s (%s ago)\n\n", [[date getW3CDTFString] UTF8String], [ago UTF8String]);
    
	fprintf(f, "Predicates:\n");
	NSArray* pkeys	= [preds keysSortedByValueUsingSelector:@selector(compare:)];
	NSEnumerator* penum	= [pkeys reverseObjectEnumerator];
	for (id k in penum) {
		NSNumber* count	= preds[k];
		fprintf(f, "\t%8llu\t%s\n", [count unsignedLongLongValue], [k cStringUsingEncoding:NSUTF8StringEncoding]);
	}
	
	
	fprintf(f, "Classes:\n");
	NSArray* ckeys	= [classes keysSortedByValueUsingSelector:@selector(compare:)];
	NSEnumerator* cenum	= [ckeys reverseObjectEnumerator];
	for (id k in cenum) {
		NSNumber* count	= classes[k];
		fprintf(f, "\t%8llu\t%s\n", [count unsignedLongLongValue], [k cStringUsingEncoding:NSUTF8StringEncoding]);
	}
	
	return;
}

@end
