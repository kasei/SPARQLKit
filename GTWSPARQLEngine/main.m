#include <pthread.h>
#include <librdf.h>
#include <CoreFoundation/CoreFoundation.h>
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWTriple.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWDataset.h>
#import "GTWSPARQLEngine.h"
#import "GTWMemoryQuadStore.h"
#import "GTWRedlandTripleStore.h"
#import "GTWTurtleParser.h"
#import "GTWRasqalSPARQLParser.h"
#import "GTWQuadModel.h"
#import "GTWTripleModel.h"
#import "GTWQueryPlanner.h"
#import "GTWRedlandParser.h"
#import "GTWExpression.h"
#import "NSObject+NSDictionary_QueryBindings.h"
#import "GTWSPARQLTestHarness.h"
#import "GTWSPARQLDataSourcePlugin.h"
#import "GTWSPARQLDataSourcePlugin.h"

rasqal_world* rasqal_world_ptr;
librdf_world* librdf_world_ptr;
raptor_world* raptor_world_ptr;

NSString* fileContents (NSString* filename) {
    NSFileHandle* fh    = [NSFileHandle fileHandleForReadingAtPath:filename];
    NSData* data        = [fh readDataToEndOfFile];
    NSString* string    = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}

int loadRDFFromFileIntoStore (id<GTWMutableQuadStore> store, NSString* filename, NSString* base) {
    NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
    GTWTurtleLexer* l   = [[GTWTurtleLexer alloc] initWithFileHandle:fh];
    
    if (NO) {
        GTWTurtleToken* t;
        while ((t = [l getToken])) {
            NSLog(@"token: %@\n", t);
        }
        return 0;
    }
    
    //    [store addIndexType: @"term" value:@[@"subject", @"predicate"] synchronous:YES error: nil];
    
    
    
    GTWIRI* graph       = [[GTWIRI alloc] initWithIRI:base];
    GTWIRI* baseuri     = [[GTWIRI alloc] initWithIRI:base];
    GTWTurtleParser* p  = [[GTWTurtleParser alloc] initWithLexer:l base: baseuri];
    if (p) {
        //    NSLog(@"parser: %p\n", p);
        [p enumerateTriplesWithBlock:^(id<GTWTriple> t) {
            GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:graph];
            NSLog(@"%@", q);
            [store addQuad:q error:nil];
        } error:nil];
    } else {
        NSLog(@"Could not construct parser");
    }
    
    return 0;
}

int run_memory_quad_store_example(NSString* filename, NSString* base) {
    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];
    loadRDFFromFileIntoStore(store, filename, base);
    
    GTWIRI* rdftype = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    GTWIRI* greg    = [[GTWIRI alloc] initWithIRI:@"http://kasei.us/about/foaf.xrdf#greg"];
    GTWIRI* type  =[[GTWIRI alloc] initWithIRI:@"http://www.mindswap.org/2003/vegetarian.owl#Vegetarian"];
    
    NSLog(@"Graphs:\n");
    [store enumerateGraphsUsingBlock:^(id<GTWTerm> g){
        NSLog(@"-> %@\n", g);
    } error:nil];
    NSLog(@"\n\n");
    
    //    {
    //        __block NSUInteger count    = 0;
    //        NSLog(@"Quads:\n");
    //        [store enumerateQuadsMatchingSubject:greg predicate:rdftype object:nil graph:nil usingBlock:^(id<GTWQuad> q){
    //            count++;
    //            NSLog(@"-> %@\n", q);
    //        } error:nil];
    //        NSLog(@"%lu total quads\n", count);
    //    }
    //
    //
    //    GTWQuad* q  = [[GTWQuad alloc] initWithSubject:greg predicate:rdftype object:type graph:graph];
    //    [store removeQuad:q error:nil];
    //
    //
    //
    //    {
    //        __block NSUInteger count    = 0;
    //        NSLog(@"Quads:\n");
    //        [store enumerateQuadsMatchingSubject:greg predicate:rdftype object:nil graph:nil usingBlock:^(NSObject<GTWQuad>* q){
    //            count++;
    //            NSLog(@"-> %@\n", q);
    //            //            NSLog(@"      subject -> %@\n", [q valueForKey: @"subject"]);
    //        } error:nil];
    //        NSLog(@"%lu total quads\n", count);
    //    }
    
    //    [store addIndexType: @"term" value:@[@"subject", @"predicate"] synchronous:YES error: nil];
    //    [store addIndexType: @"term" value:@[@"object"] synchronous:YES error: nil];
    //    [store addIndexType: @"term" value:@[@"graph", @"subject"] synchronous:YES error: nil];
    NSLog(@"%@", store);
    //    NSLog(@"best index for S___: %@\n", [store bestIndexForMatchingSubject:greg predicate:nil object:nil graph:nil]);
    //    NSLog(@"best index for ___G: %@\n", [store bestIndexForMatchingSubject:nil predicate:nil object:nil graph:greg]);
    //    NSLog(@"best index for SPO_: %@\n", [store bestIndexForMatchingSubject:greg predicate:rdftype object:type graph:nil]);
    //    NSLog(@"best index for S_O_: %@\n", [store bestIndexForMatchingSubject:greg predicate:nil object:type graph:nil]);
    return 0;
}

int run_redland_triple_store_example (NSString* filename, NSString* base) {
	librdf_world* librdf_world_ptr	= librdf_new_world();
    GTWRedlandTripleStore* store    = [[GTWRedlandTripleStore alloc] initWithName:@"db1" redlandPtr:librdf_world_ptr];
    NSFileHandle* fh    = [NSFileHandle fileHandleForReadingAtPath:filename];
    GTWTurtleLexer* l   = [[GTWTurtleLexer alloc] initWithFileHandle:fh];
    
    GTWIRI* graph       = [[GTWIRI alloc] initWithIRI:@"http://graph.kasei.us/"];
    GTWIRI* baseuri     = [[GTWIRI alloc] initWithIRI:base];
    GTWTurtleParser* p  = [[GTWTurtleParser alloc] initWithLexer:l base: baseuri];
    //    NSLog(@"parser: %p\n", p);
    if (p) {
        id<GTWTriple> t   = nil;
        while ((t = [p nextObject])) {
            [store addTriple:t error:nil];
        }
        //        NSLog(@"%lu total triples", count);
    } else {
        NSLog(@"Could not construct parser");
    }
    
    GTWIRI* rdftype = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    GTWIRI* greg    = [[GTWIRI alloc] initWithIRI:@"http://kasei.us/about/foaf.xrdf#greg"];
    GTWIRI* type  =[[GTWIRI alloc] initWithIRI:@"http://www.mindswap.org/2003/vegetarian.owl#Vegetarian"];
    
    {
        __block NSUInteger count    = 0;
        NSLog(@"Quads:\n");
        [store enumerateTriplesMatchingSubject:greg predicate:rdftype object:nil usingBlock:^(id<GTWTriple> t){
            count++;
            NSLog(@"-> %@\n", t);
        } error:nil];
        NSLog(@"%lu total quads\n", count);
    }

    librdf_free_world(librdf_world_ptr);
//    NSLog(@"%@", store);
    return 0;
}

int run_redland_parser_example (NSString* filename, NSString* base) {
    NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
    NSData* data            = [fh readDataToEndOfFile];
    id<GTWRDFParser> parser = [[GTWRedlandParser alloc] initWithData:data inFormat:@"turtle" WithRaptorWorld:raptor_world_ptr];
    {
        __block NSUInteger count    = 0;
        NSError* error  = nil;
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t){
            count++;
            NSLog(@"-> %@\n", t);
        } error:&error];
        if (error) {
            NSLog(@"parser error: %@", error);
        }
        NSLog(@"%lu total quads\n", count);
    }
    
//    NSLog(@"%@", store);
    return 0;
}

static NSArray* evaluateQueryPlan ( GTWTree* plan, id<GTWModel> model ) {
    GTWTreeType type    = plan.type;
    if (type == kPlanNLjoin) {
        NSLog(@"****************** join value: %@", plan.value);
        BOOL leftJoin   = (plan.value && [plan.value isEqualToString:@"left"]);
        NSMutableArray* results = [NSMutableArray array];
        NSArray* lhs    = evaluateQueryPlan(plan.arguments[0], model);
        NSArray* rhs    = evaluateQueryPlan(plan.arguments[1], model);
        for (NSDictionary* l in lhs) {
            for (NSDictionary* r in rhs) {
                NSDictionary* j = [l join: r];
                if (j) {
                    [results addObject:j];
                } else if (leftJoin) {
                    [results addObject:l];
                }
            }
        }
        return results;
    } else if (type == kPlanDistinct) {
        NSArray* results    = evaluateQueryPlan(plan.arguments[0], model);
        NSMutableArray* distinct    = [NSMutableArray array];
        NSMutableSet* seen  = [NSMutableSet set];
        for (id r in results) {
            if (![seen member:r]) {
                [distinct addObject:r];
                [seen addObject:r];
            }
        }
        return distinct;
    } else if (type == kPlanProject) {
        NSArray* results    = evaluateQueryPlan(plan.arguments[0], model);
        NSMutableArray* projected   = [NSMutableArray arrayWithCapacity:[results count]];
        GTWTree* listtree   = plan.value;
        NSArray* list       = listtree.arguments;
        for (id r in results) {
            NSMutableDictionary* result = [NSMutableDictionary dictionary];
            for (GTWTree* treenode in list) {
                GTWVariable* v  = treenode.value;
                NSString* name  = [v value];
                if (r[name]) {
                    result[name]    = r[name];
                }
            }
            [projected addObject:result];
        }
        return projected;
    } else if (type == kTreeTriple) {
        id<GTWTriple> t    = plan.value;
        NSMutableArray* results = [NSMutableArray array];
        [model enumerateBindingsMatchingSubject:t.subject predicate:t.predicate object:t.object graph:nil usingBlock:^(NSDictionary* r) {
            [results addObject:r];
        } error:nil];
        return results;
    } else if (type == kTreeQuad) {
        id<GTWQuad> q    = plan.value;
        NSMutableArray* results = [NSMutableArray array];
        [model enumerateBindingsMatchingSubject:q.subject predicate:q.predicate object:q.object graph:q.graph usingBlock:^(NSDictionary* r) {
            [results addObject:r];
        } error:nil];
        return results;
    } else if (type == kPlanOrder) {
        NSArray* results    = evaluateQueryPlan(plan.arguments[0], model);
        GTWTree* list       = plan.value;
        NSMutableArray* orderTerms  = [NSMutableArray array];
        NSInteger i;
        for (i = 0; i < [list.arguments count]; i+=2) {
            GTWTree* vtree  = list.arguments[i];
            GTWTree* dtree  = list.arguments[i+1];
            id<GTWTerm> dirterm     = dtree.value;
            id<GTWTerm> variable    = vtree.value;
            NSInteger direction     = [[dirterm value] integerValue];
            [orderTerms addObject:@{ @"variable": variable, @"direction": @(direction) }];
        }
        
        NSArray* ordered    = [results sortedArrayUsingComparator:^NSComparisonResult(id a, id b){
            for (NSDictionary* sortdata in orderTerms) {
                id<GTWTerm> variable    = sortdata[@"variable"];
                NSNumber* direction      = sortdata[@"direction"];
                id<GTWTerm> aterm       = a[variable.value];
                id<GTWTerm> bterm       = b[variable.value];
                NSComparisonResult cmp  = [aterm compare: bterm];
                if ([direction integerValue] < 0) {
                    cmp = -1 * cmp;
                }
                if (cmp != NSOrderedSame)
                    return cmp;
            }
            return NSOrderedSame;
        }];
        return ordered;
    } else if (type == kPlanUnion) {
        NSArray* lhs    = evaluateQueryPlan(plan.arguments[0], model);
        NSArray* rhs    = evaluateQueryPlan(plan.arguments[1], model);
        NSMutableArray* results = [NSMutableArray arrayWithArray:lhs];
        [results addObjectsFromArray:rhs];
        return results;
    } else if (type == kPlanFilter) {
        GTWTree* expr       = plan.value;
        GTWTree* subplan    = plan.arguments[0];
        NSArray* results    = evaluateQueryPlan(subplan, model);
        NSMutableArray* filtered   = [NSMutableArray arrayWithCapacity:[results count]];
        for (id result in results) {
            id<GTWTerm> f   = [GTWExpression evaluateExpression:expr WithResult:result];
            //            NSLog(@"-> %@", f);
            if ([f respondsToSelector:@selector(booleanValue)] && [(id<GTWLiteral>)f booleanValue]) {
                [filtered addObject:result];
            }
        }
        return filtered;
    } else if (type == kPlanExtend) {
        GTWTree* list       = plan.value;
        GTWTree* node       = list.arguments[0];
        GTWTree* expr       = list.arguments[1];
        id<GTWVariable> v   = node.value;
        GTWTree* subplan    = plan.arguments[0];
        NSArray* results    = evaluateQueryPlan(subplan, model);
        NSMutableArray* extended   = [NSMutableArray arrayWithCapacity:[results count]];
        for (id result in results) {
            id<GTWTerm> f   = [GTWExpression evaluateExpression:expr WithResult:result];
            NSDictionary* e = [NSMutableDictionary dictionaryWithDictionary:result];
            [e setValue:f forKey:v.value];
            [extended addObject:e];
        }
        return extended;
    } else {
        NSLog(@"Cannot evaluate query plan type %@", [plan treeTypeName]);
    }
    return nil;
}

int printResultsTable ( FILE* f, NSArray* results, NSSet* variables ) {
    NSArray* vars       = [[variables objectEnumerator] allObjects];
    int i;
    unsigned long* col_widths = alloca(sizeof(unsigned long) * [variables count]);
    NSUInteger count    = [vars count];
    for (i = 0; i < count; i++) {
        NSString* vname = [vars[i] value];
        col_widths[i]   = [vname length];
    }
    for (NSDictionary* r in results) {
        for (i = 0; i < count; i++) {
            NSString* vname = [vars[i] value];
            id<GTWTerm> t   = r[vname];
            if (t) {
                NSString* value = [t description];
                col_widths[i]   = MAX(col_widths[i], [value length]);
            }
        }
    }
    
    NSUInteger total    = 2;
    for (i = 0; i < count; i++) {
        NSLog(@"column %d width: %lu\n", i, col_widths[i]);
        total   += col_widths[i] + 3;
    }
    NSLog(@"total width: %lu\n", total);
    
    for (i = 1; i < total; i++) fwrite("-", 1, 1, stdout); fprintf(stdout, "\n");
    fprintf(stdout, "| ");
    for (i = 0; i < count; i++) {
        NSString* vname = [vars[i] value];
        fprintf(stdout, "%-*s | ", (int) col_widths[i], [vname UTF8String]);
    }
    fprintf(stdout, "\n");
    for (i = 1; i < total; i++) fwrite("-", 1, 1, stdout); fprintf(stdout, "\n");
    for (NSDictionary* r in results) {
        fprintf(stdout, "| ");
        for (i = 0; i < count; i++) {
            NSString* vname = [vars[i] value];
            id<GTWTerm> t   = r[vname];
            NSString* value = t ? [t description] : @"";
            fprintf(stdout, "%-*s | ", (int) col_widths[i], [value UTF8String]);
        }
        fprintf(stdout, "\n");
    }
    for (i = 1; i < total; i++) fwrite("-", 1, 1, stdout); fprintf(stdout, "\n");
    return 0;
}

int runQueryWithModelAndDataset (NSString* query, NSString* base, id<GTWModel> model, id<GTWDataset> dataset) {
    
    id<GTWSPARQLParser> parser  = [[GTWRasqalSPARQLParser alloc] initWithRasqalWorld:rasqal_world_ptr];
    GTWTree* algebra    = [parser parserSPARQL:query withBaseURI:base];
    if (YES) {
        NSLog(@"query:\n%@", algebra);
    }
    
    GTWQueryPlanner* planner    = [[GTWQueryPlanner alloc] init];
    GTWTree* plan       = [planner queryPlanForAlgebra:algebra usingDataset:dataset optimize: YES];
    if (YES) {
        NSLog(@"plan:\n%@", plan);
    }
    
    if (YES) {
        [plan computeProjectVariables];
    }
    
    NSLog(@"executing query...");
    NSArray* results    = evaluateQueryPlan(plan, model);
    NSSet* variables    = [plan annotationForKey:kUsedVariables];
    printResultsTable(stdout, results, variables);
    
    if (NO) {
        NSSet* variables    = [plan annotationForKey:kUsedVariables];
        NSLog(@"plan variables: %@", variables);
    }
    
    //    GTWIRI* greg    = [[GTWIRI alloc] initWithIRI:@"http://kasei.us/about/foaf.xrdf#greg"];
    //    GTWIRI* rdftype = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
    //    GTWIRI* person  = [[GTWIRI alloc] initWithIRI:@"http://xmlns.com/foaf/0.1/Person"];
    //    GTWIRI* p       = [[GTWIRI alloc] initWithIRI:@"http://xmlns.com/foaf/0.1/name"];
    
    
    //    __block NSUInteger count    = 0;
    //    NSLog(@"enumerating quads...");
    //    [model enumerateQuadsMatchingSubject:nil predicate:nil object:nil graph:nil usingBlock:^(id<GTWQuad> q){
    //        NSLog(@"%3ld -> %@", ++count, q);
    //    } error:nil];
    
    
    //
    //    GTWVariable* name   = [[GTWVariable alloc] initWithName:@"name"];
    //    [model enumerateBindingsMatchingSubject:nil predicate:p object:name graph:nil usingBlock:^(NSDictionary* d){
    //        NSLog(@"result %3ld: %@\n", ++count, d);
    //    } error:nil];
    
    return 0;
}

int runQuery(NSString* query, NSString* filename, NSString* base) {
    GTWIRI* graph = [[GTWIRI alloc] initWithIRI: base];
    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];

    {
        NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
        NSData* data            = [fh readDataToEndOfFile];
        id<GTWRDFParser> parser = [[GTWRedlandParser alloc] initWithData:data inFormat:@"guess" WithRaptorWorld:raptor_world_ptr];
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
            GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:graph];
            [store addQuad:q error:nil];
        } error:nil];
    }
    
//    loadFile(store, filename, base, @"rdfxml");
    GTWQuadModel* model         = [[GTWQuadModel alloc] initWithQuadStore:store];
//    GTWAddressBookTripleStore* store    = [[GTWAddressBookTripleStore alloc] init];
//    GTWTripleModel* model   = [[GTWTripleModel alloc] initWithTripleStore:store usingGraphName: graph];
    GTWDataset* dataset    = [[GTWDataset alloc] initDatasetWithDefaultGraphs:@[graph]];
    return runQueryWithModelAndDataset(query, base, model, dataset);
}

int main(int argc, const char * argv[]) {
    srand([[NSDate date] timeIntervalSince1970]);
	rasqal_world_ptr	= rasqal_new_world();
	if(!rasqal_world_ptr || rasqal_world_open(rasqal_world_ptr)) {
		fprintf(stderr, "*** rasqal_world init failed\n");
		return(1);
	}
	librdf_world_ptr	= librdf_new_world();
    //	librdf_world_set_error(librdf_world_ptr, NULL, _librdf_error_cb);
	raptor_world_ptr = rasqal_world_get_raptor(rasqal_world_ptr);
    
    // ------------------------------------------------------------------------------------------------------------------------
    NSMutableDictionary* datasources    = [NSMutableDictionary dictionary];
    NSArray* datasourcelist = [GTWSPARQLDataSourcePlugin loadAllPlugins];
    for (Class d in datasourcelist) {
        [datasources setObject:d forKey:[d description]];
//        NSDictionary* dict = [NSDictionary dictionary];
//        NSLog(@"%@", [[d alloc] initWithDictionary:dict]);
    }
    // ------------------------------------------------------------------------------------------------------------------------
    
    
    if (argc == 1) {
        fprintf(stderr, "Usage:\n");
        fprintf(stderr, "    %s query QUERY-STRING data.rdf\n", argv[0]);
        fprintf(stderr, "    %s queryfile query.rq data.rdf\n", argv[0]);
        fprintf(stderr, "    %s test triple\n", argv[0]);
        fprintf(stderr, "    %s test quad\n", argv[0]);
        fprintf(stderr, "    %s test endpoint\n", argv[0]);
        fprintf(stderr, "    %s test parser data.rdf base-uri\n", argv[0]);
        fprintf(stderr, "    %s testsuite\n", argv[0]);
        fprintf(stderr, "    %s sources\n", argv[0]);
        fprintf(stderr, "\n");
        exit(1);
    }
    
    if (!strcmp(argv[1], "query")) {
        NSString* query     = [NSString stringWithFormat:@"%s", argv[2]];
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[3]];
        runQuery(query, filename, @"http://query-base.example.com/");
    } else if (!strcmp(argv[1], "queryfile")) {
        NSString* query     = fileContents([NSString stringWithFormat:@"%s", argv[2]]);
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[3]];
        runQuery(query, filename, @"http://query-base.example.com/");
    } else if (!strcmp(argv[1], "sources")) {
        fprintf(stdout, "Available data sources:\n");
        for (id s in datasources) {
            fprintf(stdout, "- %s\n", [[datasources[s] description] UTF8String]);
        }
    } else if (!strcmp(argv[1], "test")) {
        NSString* filename  = [NSString stringWithFormat:@"%s", argv[2]];
        NSString* base      = [NSString stringWithFormat:@"%s", argv[3]];
        if (!strcmp(argv[2], "parser")) {
            run_redland_parser_example(filename, base);
        } else if (!strcmp(argv[2], "endpoint")) {
            NSDictionary* dict              = @{@"endpoint": @"http://myrdf.us/sparql11"};
            id<GTWTripleStore> store        = [[[datasources objectForKey:@"GTWSPARQLProtocolStore"] alloc] initWithDictionary:dict];
            GTWVariable* s  = [[GTWVariable alloc] initWithName:@"s"];
            GTWVariable* o  = [[GTWVariable alloc] initWithName:@"o"];
            GTWIRI* rdftype = [[GTWIRI alloc] initWithIRI:@"http://www.w3.org/1999/02/22-rdf-syntax-ns#type"];
            NSError* error  = nil;
            [store enumerateTriplesMatchingSubject:s predicate:rdftype object:o usingBlock:^(id<GTWTriple> t) {
                ;
            } error:&error];
            if (error) {
                NSLog(@"error: %@", error);
            }
        } else if (!strcmp(argv[2], "triple")) {
            run_redland_triple_store_example(filename, base);
        } else {
            run_memory_quad_store_example(filename, base);
        }
    } else if (!strcmp(argv[1], "testsuite")) {
        GTWSPARQLTestHarness* harness   = [[GTWSPARQLTestHarness alloc] init];
        harness.runEvalTests    = NO;
        [harness runTestsFromManifest:@"/Users/greg/data/prog/git/perlrdf/RDF-Query/xt/dawg11/manifest-all.ttl"];
    }
}

