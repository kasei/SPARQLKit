#include <pthread.h>
#include <librdf.h>
#include <CoreFoundation/CoreFoundation.h>
#import "SPARQLEngine.h"
#import "GTWMemoryQuadStore.h"
#import "GTWRedlandTripleStore.h"
#import "GTWTurtleParser.h"
#import "GTWQuad.h"
#import "GTWRasqalSPARQLParser.h"
#import "GTWQuadModel.h"
#import "GTWTripleModel.h"
#import "GTWVariable.h"
#import "GTWQueryPlanner.h"
#import "GTWAddressBookTripleStore.h"
#import "GTWQueryDataset.h"
#import "GTWRedlandParser.h"
#import "GTWExpression.h"
#import "NSObject+NSDictionary_QueryBindings.h"

rasqal_world* rasqal_world_ptr;
librdf_world* librdf_world_ptr;
raptor_world* raptor_world_ptr;

int loadFile (id<GTWMutableQuadStore> store, NSString* filename, NSString* base) {
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
    
    
    
    GTWIRI* graph       = [[GTWIRI alloc] initWithIRI:@"http://graph.kasei.us/"];
    GTWIRI* baseuri     = [[GTWIRI alloc] initWithIRI:base];
    GTWTurtleParser* p  = [[GTWTurtleParser alloc] initWithLexer:l base: baseuri];
    if (p) {
        //    NSLog(@"parser: %p\n", p);
        [p enumerateTriplesWithBlock:^(id<GTWTriple> t) {
            GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:graph];
            [store addQuad:q error:nil];
        } error:nil];
    } else {
        NSLog(@"Could not construct parser");
    }
    
    return 0;
}

int run(NSString* filename, NSString* base) {
    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];
    loadFile(store, filename, base);
    
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

int run2(NSString* filename, NSString* base) {
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

int run3(NSString* filename, NSString* base) {
    NSFileHandle* fh        = [NSFileHandle fileHandleForReadingAtPath:filename];
    NSData* data            = [fh readDataToEndOfFile];
    id<GTWRDFParser> parser = [[GTWRedlandParser alloc] initWithData:data inFormat:@"turtle" WithRaptorWorld:raptor_world_ptr];
    {
        __block NSUInteger count    = 0;
        [parser enumerateTriplesWithBlock:^(id<GTWTriple> t){
            count++;
            NSLog(@"-> %@\n", t);
        } error:nil];
        NSLog(@"%lu total quads\n", count);
    }
    
//    NSLog(@"%@", store);
    return 0;
}

static NSArray* evaluateQueryPlan ( GTWTree* plan, id<GTWModel> model ) {
    GTWTreeType type    = plan.type;
    if (type == kPlanNLjoin) {
        NSMutableArray* results = [NSMutableArray array];
        NSArray* lhs    = evaluateQueryPlan(plan.arguments[0], model);
        NSArray* rhs    = evaluateQueryPlan(plan.arguments[1], model);
        for (NSDictionary* l in lhs) {
            for (NSDictionary* r in rhs) {
                NSDictionary* j = [l join: r];
                if (j) {
                    [results addObject:j];
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
            [orderTerms addObject:@{ @"variable": variable, @"direction": [NSNumber numberWithInteger:direction] }];
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
    } else {
        NSLog(@"Cannot evaluate query plan type %@", [plan treeTypeName]);
    }
    return nil;
}

int runQuery(NSString* query, NSString* filename, NSString* base) {
//    GTWMemoryQuadStore* store   = [[GTWMemoryQuadStore alloc] init];
//    loadFile(store, filename, base);
//    GTWQuadModel* model         = [[GTWQuadModel alloc] initWithQuadStore:store];
    
    GTWIRI* abGraph = [[GTWIRI alloc] initWithIRI: @"http://example.org/"];
    GTWAddressBookTripleStore* store    = [[GTWAddressBookTripleStore alloc] init];
    GTWTripleModel* model   = [[GTWTripleModel alloc] initWithTripleStore:store usingGraphName: abGraph];
    
    GTWQueryDataset* dataset    = [[GTWQueryDataset alloc] initDatasetWithDefaultGraphs:@[abGraph]];
    
    id<GTWSPARQLParser> parser  = [[GTWRasqalSPARQLParser alloc] initWithRasqalWorld:rasqal_world_ptr];
    GTWTree* algebra    = [parser parserSPARQL:query withBaseURI:base];
    NSLog(@"query:\n%@", algebra);
    GTWQueryPlanner* planner    = [[GTWQueryPlanner alloc] init];
    GTWTree* plan       = [planner queryPlanForAlgebra:algebra usingDataset:dataset optimize: YES];
    NSLog(@"plan:\n%@", plan);
    
    if (YES) {
        NSLog(@"executing query...");
        NSArray* results    = evaluateQueryPlan(plan, model);
        for (id r in results) {
            NSLog(@"result: %@\n", r);
        }
    }
    
    if (YES) {
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

int main(int argc, const char * argv[]) {
	rasqal_world_ptr	= rasqal_new_world();
	if(!rasqal_world_ptr || rasqal_world_open(rasqal_world_ptr)) {
		fprintf(stderr, "*** rasqal_world init failed\n");
		return(1);
	}
	librdf_world_ptr	= librdf_new_world();
    //	librdf_world_set_error(librdf_world_ptr, NULL, _librdf_error_cb);
	raptor_world_ptr = rasqal_world_get_raptor(rasqal_world_ptr);
    
    NSString* filename  = [NSString stringWithFormat:@"%s", argv[1]];
    NSString* base      = [NSString stringWithFormat:@"%s", argv[2]];
    if (!(filename && base)) {
        NSLog(@"no filename and base URI specified");
        return 1;
    }
    
    if (NO) {
        run(filename, base);
    } else if (NO) {
        run2(filename, base);
    } else if (NO) {
        run3(filename, base);
    } else {
    //    NSString* query = @"SELECT DISTINCT ?s ?p WHERE { ?s a <http://xmlns.com/foaf/0.1/Person> ; ?p ?o } ORDER BY ?p DESC(?s)";
    //    NSString* query = @"SELECT * WHERE { ?s a <http://xmlns.com/foaf/0.1/Person> ; <http://xmlns.com/foaf/0.1/name> ?name ; ?p ?o }";
    //    NSString* query = @"SELECT * WHERE { ?s a <http://xmlns.com/foaf/0.1/Person> ; <http://xmlns.com/foaf/0.1/name> ?name }";
//        NSString* query = @"PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?mbox WHERE { ?s <http://xmlns.com/foaf/0.1/name> 'Gregory Williams' ; foaf:mbox_sha1sum ?mbox . FILTER(ISIRI(?s)) } ORDER BY ASC(?s) DESC(?mbox)";
        NSString* query = @"PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?s ?mbox WHERE { ?s <http://xmlns.com/foaf/0.1/name> 'Gregory Williams' ; foaf:mbox_sha1sum ?mbox . } ORDER BY ?mbox";
//        NSString* query = @"PREFIX foaf: <http://xmlns.com/foaf/0.1/> SELECT ?mbox WHERE { ?s <http://xmlns.com/foaf/0.1/name> 'Gregory Williams' . FILTER(ISURI(?s)) }";
    //    NSString* query = @"SELECT * WHERE { ?s a <http://xmlns.com/foaf/0.1/Person> }";
        runQuery(query, filename, @"http://query-base.example.com/");
    }
    
    NSLog(@"entering runloop...\n");
    int i;
    for (i = 0; i < 1; i++) {
        sleep(1);
    }
    NSLog(@"done\n");
}

