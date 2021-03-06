//
//  SPKSimpleQueryEngine.m
//  GTWSPARQLEngine
//
//  Created by Gregory Williams on 9/18/13.
//  Copyright (c) 2013 Gregory Williams. All rights reserved.
//

#import "SPARQLKit.h"
#import "SPKSimpleQueryEngine.h"
#import "SPKTree.h"
#import "NSObject+NSDictionary_QueryBindings.h"
#import <GTWSWBase/GTWSWBase.h>
#import <GTWSWBase/GTWVariable.h>
#import <GTWSWBase/GTWLiteral.h>
#import "SPKExpression.h"
#import <GTWSWBase/GTWQuad.h>
#import <GTWSWBase/GTWSPARQLResultsXMLParser.h>
#import "SPKSPARQLPluginHandler.h"
#import "SPKMutableURLRequest.h"
#import "SPKTurtleParser.h"

@implementation SPKSimpleQueryEngine

- (SPKSimpleQueryEngine*) init {
    if (self = [super init]) {
        self.functionImplementations    = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSEnumerator*) evaluateHashJoin:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSMutableArray* results = [NSMutableArray array];

    id<SPKTree,GTWQueryPlan> lhsPlan    = plan.arguments[0];
    id<SPKTree,GTWQueryPlan> rhsPlan    = plan.arguments[1];
    
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:3];
    
    @autoreleasepool {
        NSMutableDictionary* hash   = [NSMutableDictionary dictionary];
        NSSet* joinVars = plan.value;
        @autoreleasepool {
            [progress becomeCurrentWithPendingUnitCount:1];
            NSEnumerator* rhs    = [self _evaluateQueryPlan:rhsPlan withModel:model];
            [progress resignCurrent];
            for (NSDictionary* result in rhs) {
                NSMutableDictionary* joinKey   = [NSMutableDictionary dictionary];
                for (id<GTWVariable> var in joinVars) {
                    NSString* v = var.value;
                    id<GTWTerm> term    = [result objectForKey:v];
                    if (term) {
                        [joinKey setObject:term forKey:v];
                    }
                }
                NSNumber* hashKey   = [NSNumber numberWithInteger:[[joinKey description] hash]];
                NSMutableArray* array   = [hash objectForKey:hashKey];
                if (!array) {
                    array   = [NSMutableArray array];
                    [hash setObject:array forKey:hashKey];
                }
                [array addObject:result];
            }
        }
//        NSLog(@"HashJoin hash has %lu buckets", [hash count]);

        @autoreleasepool {
            [progress becomeCurrentWithPendingUnitCount:1];
            NSEnumerator* lhs    = [self _evaluateQueryPlan:lhsPlan withModel:model];
            [progress resignCurrent];
            
            [progress becomeCurrentWithPendingUnitCount:1];
            for (NSDictionary* result in lhs) {
                NSMutableDictionary* joinKey   = [NSMutableDictionary dictionary];
                for (id<GTWVariable> var in joinVars) {
                    NSString* v = var.value;
                    id<GTWTerm> term    = [result objectForKey:v];
                    if (term) {
                        [joinKey setObject:term forKey:v];
                    }
                }
                NSNumber* hashKey   = [NSNumber numberWithInteger:[[joinKey description] hash]];
                NSMutableArray* array   = [hash objectForKey:hashKey];
                if (array) {
                    for (NSDictionary* r in array) {
                        NSDictionary* j = [result join: r];
                        if (j) {
                            [results addObject:j];
                        }
                    }
                }
            }
            [progress resignCurrent];
        }
    }
    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateNLJoin:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    BOOL leftJoin       = ([plan.type isEqual:kPlanNLLeftJoin]);
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:3];

    [progress becomeCurrentWithPendingUnitCount:1];
    NSEnumerator* lhs   = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    NSArray* rhs        = [[self _evaluateQueryPlan:plan.arguments[1] withModel:model] allObjects];
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    id<SPKTree> expr    = plan.treeValue;
    NSEnumerator* results   = [self joinResultsEnumerator:lhs withResults:rhs leftJoin: leftJoin filter: expr withModel:model];
    [progress resignCurrent];
    
    return results;
}

- (NSEnumerator*) evaluateMinus:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:3];

    [progress becomeCurrentWithPendingUnitCount:1];
    NSEnumerator* lhs   = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    NSArray* rhs        = [[self _evaluateQueryPlan:plan.arguments[1] withModel:model] allObjects];
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    NSMutableArray* results = [NSMutableArray array];
    for (NSDictionary* result in lhs) {
        BOOL ok = YES;
        NSSet* domResult    = [NSSet setWithArray:[result allKeys]];
        for (NSDictionary* checkResult in rhs) {
            NSSet* domCheckResult   = [NSSet setWithArray:[checkResult allKeys]];
            if ([domResult intersectsSet: domCheckResult]) {
                if ([result join:checkResult]) {
                    ok  = NO;
                    break;
                }
            }
        }
        if (ok) {
            [results addObject:result];
        }
    }
    [progress resignCurrent];

    return [results objectEnumerator];
}

- (NSEnumerator*) joinResultsEnumerator: (NSEnumerator*) lhs withResults: (NSArray*) rhs leftJoin: (BOOL) leftJoin filter: (id<SPKTree>) expr withModel: (id<GTWModel>) model {
    NSMutableArray* results = [NSMutableArray array];
    for (NSDictionary* l in lhs) {
        BOOL joined = NO;
        for (NSDictionary* r in rhs) {
            NSDictionary* j = [l join: r];
            if (j) {
                if (expr) {
                    id<GTWTerm> f   = [self.evalctx evaluateExpression:expr withResult:j usingModel: model];
                    if ([f effectiveBooleanValueWithError:nil]) {
                        joined  = YES;
                        [results addObject:j];
                    }
                } else {
                    joined  = YES;
                    [results addObject:j];
                }
            }
        }
        if (leftJoin && !joined) {
            [results addObject:l];
        }
    }
    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateAsk:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:2];
    [progress becomeCurrentWithPendingUnitCount:1];
    NSEnumerator* results   = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    NSDictionary* result    = [results nextObject];
    GTWLiteral* l   = [[GTWLiteral alloc] initWithValue:(result ? @"true" : @"false") datatype:@"http://www.w3.org/2001/XMLSchema#boolean"];
    NSDictionary* r = @{ @".bool": l };
    [progress resignCurrent];
    
    return [@[r] objectEnumerator];
}

- (NSEnumerator*) evaluateDistinct:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:2];
    [progress becomeCurrentWithPendingUnitCount:1];
    NSEnumerator* results   = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    NSMutableArray* distinct    = [NSMutableArray array];
    NSMutableSet* seen  = [NSMutableSet set];
    for (id r in results) {
        if (![seen member:r]) {
            [distinct addObject:r];
            [seen addObject:r];
        }
    }
    [progress resignCurrent];
    
    return [distinct objectEnumerator];
}

- (NSEnumerator*) evaluateProject:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:2];
    [progress becomeCurrentWithPendingUnitCount:1];
    NSArray* results   = [[self _evaluateQueryPlan:plan.arguments[0] withModel:model] allObjects];
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    NSMutableArray* projected   = [NSMutableArray arrayWithCapacity:[results count]];
    id<SPKTree> listtree   = plan.treeValue;
    NSArray* list       = listtree.arguments;
    for (NSDictionary* result in results) {
        NSMutableDictionary* testResult = [NSMutableDictionary dictionaryWithDictionary:result];
        NSMutableDictionary* newResult  = [NSMutableDictionary dictionary];
        for (id<SPKTree> treenode in list) {
            if ([treenode.type isEqual:kTreeNode]) {
                GTWVariable* v  = treenode.value;
                NSString* name  = [v value];
                if (result[name]) {
                    newResult[name]     = result[name];
                    testResult[name]    = result[name];
                }
            } else {
                NSLog(@"Unexpected plan type in evaluating project: %@", plan);
                return nil;
            }
        }
        [projected addObject:newResult];
    }
    [progress resignCurrent];
    return [projected objectEnumerator];
}

- (NSEnumerator*) evaluateQuad:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<GTWQuad> q    = plan.value;
    NSMutableArray* results = [NSMutableArray array];
    @autoreleasepool {
        [model enumerateBindingsMatchingSubject:q.subject predicate:q.predicate object:q.object graph:q.graph usingBlock:^(NSDictionary* r) {
            [results addObject:r];
        } error:nil];
    }
    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateOrder:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:2];
    [progress becomeCurrentWithPendingUnitCount:1];
    NSArray* results    = [[self _evaluateQueryPlan:plan.arguments[0] withModel:model] allObjects];
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    id<SPKTree> list    = plan.treeValue;
    NSMutableArray* orderTerms  = [NSMutableArray array];
    NSInteger i;
    for (i = 0; i < [list.arguments count]; i+=2) {
        id<SPKTree> vtree  = list.arguments[i];
        id<SPKTree> dtree  = list.arguments[i+1];
        id<GTWTerm> dirterm     = dtree.value;
        NSInteger direction     = [[dirterm value] integerValue];
        [orderTerms addObject:@{ @"expr": vtree, @"direction": @(direction) }];
    }
    
    NSArray* ordered    = [results sortedArrayUsingComparator:^NSComparisonResult(id a, id b){
        for (NSDictionary* sortdata in orderTerms) {
            id<SPKTree> expr        = sortdata[@"expr"];
            NSNumber* direction     = sortdata[@"direction"];
            id<GTWTerm> aterm       = [self.evalctx evaluateExpression:expr withResult:a usingModel: model];
            id<GTWTerm> bterm       = [self.evalctx evaluateExpression:expr withResult:b usingModel: model];
            NSComparisonResult cmp  = [aterm compare: bterm];
            if ([direction integerValue] < 0) {
                cmp = -1 * cmp;
            }
            if (cmp != NSOrderedSame)
                return cmp;
        }
        return NSOrderedSame;
    }];
    [progress resignCurrent];
    
    return [ordered objectEnumerator];
}

- (NSEnumerator*) evaluateUnion:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:3];
    [progress becomeCurrentWithPendingUnitCount:1];
    NSEnumerator* lhs    = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    NSEnumerator* rhs    = [self _evaluateQueryPlan:plan.arguments[1] withModel:model];
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    NSMutableArray* results = [NSMutableArray arrayWithArray:[lhs allObjects]];
    [results addObjectsFromArray:[rhs allObjects]];
    [progress resignCurrent];
    
    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateGroupPlan:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:3];
    id<SPKTree> groupData   = plan.treeValue;
    id<SPKTree> groupList   = groupData.arguments[0];
    id<SPKTree> aggListTree = groupData.arguments[1];
    NSArray* aggList        = aggListTree.arguments;
    NSMutableDictionary* aggregates = [NSMutableDictionary dictionary];
    for (id<SPKTree> list in aggList) {
        GTWVariable* v      = list.value;
        id<SPKTree, NSCopying> expr    = list.arguments[0];
        aggregates[expr]    = v;
    }
//    NSLog(@"grouping trees: %@", groupList.arguments);
//    NSLog(@"aggregates: %@", aggregates);

    NSMutableDictionary* resultGroups   = [NSMutableDictionary dictionary];

    [progress becomeCurrentWithPendingUnitCount:1];
    NSEnumerator* results    = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    for (NSDictionary* result in results) {
        NSMutableDictionary* groupKeyDict   = [NSMutableDictionary dictionary];
        for (id<SPKTree> g in groupList.arguments) {
            if ([g.type isEqual:kAlgebraExtend]) {
                id<SPKTree> list    = g.treeValue;
                id<SPKTree> expr    = list.arguments[0];
                id<SPKTree> tn      = list.arguments[1];
                id<GTWTerm> var = tn.value;
                id<GTWTerm> t   = [self.evalctx evaluateExpression:expr withResult:result usingModel: model];
                if (t)
                    groupKeyDict[var.value]   = t;
            } else {
                id<GTWTerm> var = g.value;
                id<GTWTerm> t   = [self.evalctx evaluateExpression:g withResult:result usingModel: model];
                if (t)
                    groupKeyDict[var.value]   = t;
            }
        }
        
        id groupKey = groupKeyDict;
        
        if (!resultGroups[groupKey]) {
            resultGroups[groupKey]   = [NSMutableArray array];
        }
        [resultGroups[groupKey] addObject:result];
    }
    [progress resignCurrent];
    
    // There is always at least one group.
    if ([resultGroups count] == 0) {
        resultGroups[@{}]   = @[];
    }
    
//    NSLog(@"-------------\nGroups:%@", resultGroups);
    
    [progress becomeCurrentWithPendingUnitCount:1];
    NSMutableArray* finalResults    = [NSMutableArray array];
    for (id groupKey in resultGroups) {
        NSArray* groupResults   = resultGroups[groupKey];
        NSMutableDictionary* result = [NSMutableDictionary dictionaryWithDictionary:groupKey];
        for (id<SPKTree> expr in aggregates) {
            GTWVariable* v  = aggregates[expr];
            id<GTWTerm> value   = [self valueOfAggregate:expr forResults:groupResults withModel:model];
            if (value) {
                result[v.value]   = value;
            }
        }
        [finalResults addObject:result];
    }
    [progress resignCurrent];
    
    return [finalResults objectEnumerator];
}

- (id<GTWTerm>) valueOfAggregate: (id<SPKTree>) expr forResults: (NSArray*) results withModel: (id<GTWModel>) model {
    if (expr.type == kExprCount) {
        NSNumber* distinct    = expr.value;
        id counter  = ([distinct integerValue]) ? [NSMutableSet set] : [NSMutableArray array];
        for (NSDictionary* result in results) {
            if ([expr.arguments count]) {
                id<GTWTerm> f   = [self.evalctx evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
                if (f)
                    [counter addObject:f];
            } else {
                [counter addObject:@(1)];
            }
        }
        return [GTWLiteral integerLiteralWithValue:[counter count]];
    } else if (expr.type == kExprGroupConcat) {
        NSArray* a  = expr.value;
        NSNumber* distinct  = a[0];
        id container  = ([distinct integerValue]) ? [NSMutableSet set] : [NSMutableArray array];
        NSString* separator = a[1];
        for (NSDictionary* result in results) {
            id<GTWTerm> t   = [self.evalctx evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
            if (t)
                [container addObject:t.value];
        }
        NSArray* array  = [container allObjects];
        return [[GTWLiteral alloc] initWithValue:[array componentsJoinedByString:separator]];
    } else if (expr.type == kExprMax || expr.type == kExprMin) {
        NSComparisonResult cmpResult    = (expr.type == kExprMax) ? NSOrderedDescending : NSOrderedAscending;
        id<GTWTerm> extrema = nil;
        for (NSDictionary* result in results) {
            id<GTWTerm> t   = [self.evalctx evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
            if (!extrema || [t compare:extrema] == cmpResult) {
                extrema = t;
            }
        }
        return extrema;
    } else if (expr.type == kExprSum || expr.type == kExprAvg) {
        NSInteger count = 0;
        id<GTWLiteral> sum    = [GTWLiteral integerLiteralWithValue:0];
        for (NSDictionary* result in results) {
            id<GTWLiteral,GTWTerm> t   = (id<GTWLiteral,GTWTerm>) [self.evalctx evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
            sum = (id<GTWLiteral>) [self.evalctx evaluateNumericExpressionOfType:kExprPlus lhs:sum rhs:t];
            if (!sum)
                break;
            count++;
        }
        if (expr.type == kExprSum) {
            return sum;
        } else {
            if (!sum)
                return nil;
            id<GTWLiteral,GTWTerm> total   = [[GTWLiteral alloc] initWithValue:[NSString stringWithFormat:@"%ld", count] datatype:@"http://www.w3.org/2001/XMLSchema#integer"];
            id<GTWTerm> avg = [self.evalctx evaluateNumericExpressionOfType:kExprDiv lhs:sum rhs:total];
            return avg;
        }
    } else if (expr.type == kExprSample) {
        id<GTWTerm> term = nil;
        for (NSDictionary* result in results) {
            term   = [self.evalctx evaluateExpression:expr.arguments[0] withResult:result usingModel: model];
            break;
        }
        return term;
    } else {
        NSLog(@"Cannot compute aggregate %@", expr.type);
        return nil;
    }
}

- (NSEnumerator*) evaluateServicePlan:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<SPKTree> list        = plan.treeValue;
    id<SPKTree> eptree      = list.arguments[0];
    id<SPKTree> silenttree  = list.arguments[1];
    id<GTWTerm> ep          = eptree.value;
    GTWLiteral* silentTerm  = silenttree.value;
    BOOL silent             = [silentTerm booleanValue];
    
    NSString* endpoint  = ep.value;
    id<SPKTree> stree   = plan.arguments[0];
    id<GTWTerm> sterm   = stree.value;
    NSString* sparql    = sterm.value;
    
    CFStringRef escaped = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)sparql, NULL, CFSTR(";?#"), kCFStringEncodingUTF8);
    NSString* query     = [NSString stringWithString:(__bridge NSString*) escaped];
    CFRelease(escaped);
    
	NSError* _error			= nil;
	NSURL* url	= [NSURL URLWithString:[NSString stringWithFormat:@"%@?query=%@", endpoint, query]];
    SPKMutableURLRequest* req   = [SPKMutableURLRequest requestWithURL:url];
	[req setValue:@"application/sparql-results+xml" forHTTPHeaderField:@"Accept"];
    
	NSData* data	= nil;
	NSHTTPURLResponse* resp	= nil;
    //	NSLog(@"request: %@", req);
	data	= [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&_error];
    //	NSLog(@"got response with %lu bytes: %@", [data length], [resp allHeaderFields]);
    //	NSLog(@"got response with %lu bytes", [data length]);
	if (data) {
        if ([resp isKindOfClass:[NSHTTPURLResponse class]] && [resp statusCode] >= 300) {
            NSInteger code	= [resp statusCode];
            //            NSLog(@"Error: (%03ld) %@\n", code, [NSHTTPURLResponse localizedStringForStatusCode:code]);
            NSDictionary* headers	= [resp allHeaderFields];
            NSString* type		= headers[@"Content-Type"];
            NSError* e;
            if ([type hasPrefix:@"text/"]) {
                NSString* body  = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (!body)
                    body    = @"(No body returned)";
                e  = [NSError errorWithDomain:@"us.kasei.sparql.store.sparql.http" code:code userInfo:@{@"description": [NSHTTPURLResponse localizedStringForStatusCode:code], @"body": body}];
            } else {
                e  = [NSError errorWithDomain:@"us.kasei.sparql.store.sparql.http" code:code userInfo:@{@"description": [NSHTTPURLResponse localizedStringForStatusCode:code], @"data": data}];
            }
            
            if (silent) {
                return [@[@{}] objectEnumerator];
            } else {
                NSLog(@"%@", e);
                return nil;
            }
        } else {
            GTWSPARQLResultsXMLParser* parser    = [[GTWSPARQLResultsXMLParser alloc] init];
            NSMutableSet* vars  = [NSMutableSet set];
            NSEnumerator* e = [parser parseResultsFromData:data settingVariables:vars];
            if (!e && silent) {
                return [@[@{}] objectEnumerator];
            } else {
                return e;
            }
        }
	} else {
        if (silent) {
            return [@[@{}] objectEnumerator];
        } else {
            NSLog(@"SPARQL Protocol HTTP error: %@", _error);
            return nil;
        }
	}
}

- (NSEnumerator*) evaluateGraphPlan:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<SPKTree> graph   = plan.treeValue;
    id<GTWTerm> term    = graph.value;
    id<SPKTree,GTWQueryPlan> subplan    = plan.arguments[0];
    NSMutableArray* graphs  = [NSMutableArray array];
    [model enumerateGraphsUsingBlock:^(id<GTWTerm> g) {
        [graphs addObject: g];
    } error:nil];
//    NSLog(@"GRAPHs: %@", graphs);
    if ([graphs count]) {
        NSProgress *progress = [NSProgress progressWithTotalUnitCount:[graphs count]];
        NSMutableArray* results = [NSMutableArray array];
        for (id<GTWTerm> g in graphs) {
            [progress becomeCurrentWithPendingUnitCount:1];
            if ([g isEqual:term]) {
                return [self evaluateQueryPlan:subplan withModel:model];
            } else if ([term isKindOfClass:[GTWVariable class]]) {
                SPKTree* list   = [[SPKTree alloc] initWithType:kTreeList arguments:@[
                                                                                      [[SPKTree alloc] initWithType:kTreeNode value:g arguments:@[]],
                                                                                      [[SPKTree alloc] initLeafWithType:kTreeNode value:term],
                                                                                      ]];
                id<SPKTree, GTWQueryPlan> extend    = (id<SPKTree, GTWQueryPlan>) [[SPKTree alloc] initWithType:kPlanExtend treeValue:list arguments:@[subplan]];
                NSEnumerator* rhs   = [self evaluateExtend:extend withModel:model];
                [results addObjectsFromArray:[rhs allObjects]];
            }
            [progress resignCurrent];
        }
        return [results objectEnumerator];
    } else {
        return [@[] objectEnumerator];
    }
}

- (NSEnumerator*) evaluateFilter:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<SPKTree> expr       = plan.treeValue;
    id<SPKTree,GTWQueryPlan> subplan    = plan.arguments[0];
    
    // TODO: _evaluateQueryPlan should be accounted for in an NSProgress
    NSArray* results    = [[self _evaluateQueryPlan:subplan withModel:model] allObjects];
    NSMutableArray* filtered   = [NSMutableArray arrayWithCapacity:[results count]];
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:[results count]];
    for (id result in results) {
        [progress becomeCurrentWithPendingUnitCount:1];
        id<GTWTerm> f   = [self.evalctx evaluateExpression:expr withResult:result usingModel: model];
        if ([f effectiveBooleanValueWithError:nil]) {
            [filtered addObject:result];
        }
        [progress resignCurrent];
    }
    return [filtered objectEnumerator];
}

- (NSEnumerator*) evaluateExtend:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<SPKTree> list    = plan.treeValue;
    id<SPKTree> expr    = list.arguments[0];
    id<SPKTree> node    = list.arguments[1];
    
    id<GTWVariable> v   = node.value;
    if ([v isKindOfClass:[GTWVariable class]]) {
        id<SPKTree,GTWQueryPlan> subplan    = plan.arguments[0];
        NSEnumerator* results       = [self _evaluateQueryPlan:subplan withModel:model];
        NSMutableArray* extended    = [NSMutableArray array];
        NSInteger counter  = 0;
        for (NSDictionary* result in results) {
            // This NSNumber counter is used so that adjacent Extend operations, as would be present from
            // multiple select expressions, will use the same count value. As a result of using this count
            // value as the resultIdentity while evaluating expressions, a single result should produce
            // the same value across multiple calls to BNODE(?var) (since the count value will be the same
            // in all extend evaluations for any given result)
            NSNumber* c     = [NSNumber numberWithInteger:counter++];
            id<GTWTerm> f   = [self.evalctx evaluateExpression:expr withResult:result usingModel: model resultIdentity:c];
            if (f) {
                NSDictionary* e = [NSMutableDictionary dictionaryWithDictionary:result];
                id<GTWTerm> value   = [e objectForKey:v.value];
                if (!value || [value isEqual:f]) {
                    [e setValue:f forKey:v.value];
                    [extended addObject:e];
                }
            } else {
                [extended addObject:result];
            }
        }
        return [extended objectEnumerator];
    } else {
        return [@[] objectEnumerator];
    }
}

- (NSEnumerator*) evaluatePathPlan:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model includeZeroLengthResults: (BOOL) zeroLength includeMoreLengthResults: (BOOL) moreLength {
    id<SPKTree> list        = plan.treeValue;
    id<SPKTree> s           = list.arguments[0];
    id<SPKTree> o           = list.arguments[1];
    id<SPKTree> ts          = list.arguments[2];
    id<SPKTree> to          = list.arguments[3];
    id<SPKTree> graphs      = list.arguments[4];
    id<GTWTerm> subj        = s.value;
    id<GTWTerm> obj         = o.value;
    NSEnumerator* r         = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    NSArray* pathResults    = [r allObjects];
    NSArray* loopResults    = pathResults;
    
    NSMutableSet* results = [NSMutableSet set];
    if (zeroLength) {
        BOOL subjVar    = [subj isKindOfClass:[GTWVariable class]];
        BOOL objVar     = [obj isKindOfClass:[GTWVariable class]];
        if (subjVar && objVar) {
            // results map both (subj, obj) to each graph node in current graph
            NSMutableSet* nodes = [NSMutableSet set];
            for (id<SPKTree> graphTree in graphs.arguments) {
                [model enumerateQuadsMatchingSubject:nil predicate:nil object:nil graph:graphTree.value usingBlock:^(id<GTWQuad> q) {
                    [nodes addObject:q.subject];
                    [nodes addObject:q.object];
                } error:nil];
            }
            for (id<GTWTerm> t in nodes) {
                NSDictionary* result    = @{subj.value: t, obj.value: t};
                [results addObject:result];
            }
        } else if (subjVar) {
            // one result: { subj -> obj }
            NSDictionary* result    = @{subj.value: obj};
            [results addObject:result];
        } else if (objVar) {
            // one result: { obj -> subj }
            NSDictionary* result    = @{obj.value: subj};
            [results addObject:result];
        } else {
            // one result (the join identity)
            [results addObject:@{}];
        }
    }
    
    NSUInteger loop         = 1;
    NSArray* resultsArray;
    if (moreLength) {
        resultsArray    = loopResults;
    } else {
        resultsArray    = pathResults;
    }
MORE_LOOP:
    if (moreLength) {
        resultsArray    = [self resultsForMorePathPlan:plan withResults:resultsArray forLength:loop withModel:model]; //zeroOrMorePathResults:pathResults forLength: loop];
    }
    NSUInteger lastCount    = [results count];
    for (NSDictionary* result in resultsArray) {
        NSMutableDictionary* newResult  = [NSMutableDictionary dictionary];
        id<GTWTerm> subjTerm    = [self.evalctx evaluateExpression:ts withResult:result usingModel: model];
        id<GTWTerm> objTerm     = [self.evalctx evaluateExpression:to withResult:result usingModel: model];
        
        BOOL ok             = YES;
        if ([subj isKindOfClass:[GTWVariable class]]) {
            newResult[subj.value]   = subjTerm;
        } else if (![subjTerm isEqual:subj]) {
            // the subject of this property path is a Term (not a variable) that doesn't match this result
            ok  = NO;
        }
        
        if ([obj isKindOfClass:[GTWVariable class]]) {
            newResult[obj.value]   = objTerm;
        } else if (![objTerm isEqual:obj]) {
            // the object of this property path is a Term (not a variable) that doesn't match this result
            ok  = NO;
        }
        
        if (ok) {
            [results addObject:newResult];
        }
    }
    if (moreLength) {
        if ([results count] != lastCount) {
            loop++;
            goto MORE_LOOP;
        }
    }
    //    NSLog(@"ZeroOrMore path results: %@", results);
    return [results objectEnumerator];
}

- (NSEnumerator*) evaluateNPSPathPlan:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<SPKTree> s   = plan.arguments[0];
    id<SPKTree> set = plan.arguments[1];
    NSSet* pset     = set.value;
    id<SPKTree> o   = plan.arguments[2];
    id<SPKTree> g   = plan.arguments[3];
    id<GTWTerm> p   = [[GTWVariable alloc] initWithValue:@".nps"];
    NSMutableSet* results = [NSMutableSet set];
    [model enumerateBindingsMatchingSubject:s.value predicate:p object:o.value graph:g.value usingBlock:^(NSDictionary* r) {
        id<GTWTerm> p   = r[@".nps"];
        if (![pset containsObject:p]) {
            NSMutableDictionary* nr    = [NSMutableDictionary dictionaryWithDictionary:r];
            [nr removeObjectForKey:@".nps"];
            [results addObject:[NSDictionary dictionaryWithDictionary:nr]];
        }
    } error:nil];
    return [results objectEnumerator];
}

- (NSArray*) resultsForMorePathPlan: (id<SPKTree, GTWQueryPlan>)plan withResults: (NSArray*) pathResults forLength: (NSUInteger) length withModel:(id<GTWModel>)model  {
    id<SPKTree> list        = plan.treeValue;
    id<SPKTree> ts          = list.arguments[2];
    id<SPKTree> to          = list.arguments[3];
    id<GTWTerm> temps       = ts.value;
    id<GTWTerm> tempo       = to.value;

    if (length == 1) {
//        NSLog(@"ZeroOrMore path results for loop #%lu: %@", length, pathResults);
        return pathResults;
    } else {
        NSEnumerator* newPathResults   = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
        
        NSMutableArray* rhsResults  = [NSMutableArray array];
        NSMutableArray* lhsResults  = [NSMutableArray array];
        GTWVariable* b = [[GTWVariable alloc] initWithValue:[NSString stringWithFormat:@".zmr%lu", self.bnodeCounter++]];
        for (NSDictionary* result in newPathResults) {
            // rename temp object to b
            NSMutableDictionary* newResult  = [NSMutableDictionary dictionaryWithDictionary:result];
            id<GTWTerm> term    = result[tempo.value];
            if (term) {
                [newResult removeObjectForKey:tempo.value];
                newResult[b.value]  = term;
            }
            [lhsResults addObject:newResult];
        }
        for (NSDictionary* result in pathResults) {
            // rename subject to b
            NSMutableDictionary* newResult  = [NSMutableDictionary dictionaryWithDictionary:result];
            id<GTWTerm> term    = result[temps.value];
            if (term) {
                [newResult removeObjectForKey:temps.value];
                newResult[b.value]  = term;
            }
            [rhsResults addObject:newResult];
        }
        NSEnumerator* e = [self joinResultsEnumerator:[lhsResults objectEnumerator] withResults:rhsResults leftJoin:NO filter:nil withModel:model];
        NSArray* a      = [e allObjects];
//        NSLog(@"ZeroOrMore path results for loop #%lu: %@", length, a);
        return a;
    }
}

- (NSEnumerator*) evaluateInsertData:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    if (![model conformsToProtocol:@protocol(GTWMutableModel)]) {
        NSLog(@"Model is not mutable");
        return nil;
    }
    NSError* error;
    id<GTWMutableModel> mmodel  = (id<GTWMutableModel>) model;
    
    for (id<SPKTree> tree in plan.arguments) {
        id<GTWQuad> q   = tree.value;
        [mmodel addQuad:q error:&error];
        if (error) {
            NSLog(@"Error removing quad: %@", error);
        }
    }

    NSNumber* r = [NSNumber numberWithBool:YES];
    return [@[r] objectEnumerator];
}

- (NSEnumerator*) evaluateLoad:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    if (![model conformsToProtocol:@protocol(GTWMutableModel)]) {
        NSLog(@"Model is not mutable");
        return nil;
    }
    NSError* error  = nil;
    id<GTWMutableModel> mmodel  = (id<GTWMutableModel>) model;
    
    id<SPKTree> list        = plan.treeValue;
    id<SPKTree> silentTree  = list.arguments[0];
    id<GTWLiteral> silent   = silentTree.value;
    id<SPKTree> urlTree     = list.arguments[1];
    id<GTWIRI> iri          = urlTree.value;
    id<SPKTree> graphTree   = list.arguments[2];
    id<GTWIRI> graph        = graphTree.value;
    // TODO: this should be checking the media type first
    Class RDFParserClass    = [SPKSPARQLPluginHandler parserForFilename:iri.value conformingToProtocol:@protocol(GTWRDFParser)];
    GTWIRI* base            = iri;
    NSURL* url              = [NSURL URLWithString:iri.value];
    SPKMutableURLRequest* req   = [SPKMutableURLRequest requestWithURL:url];
	[req setValue:@"text/turtle, text/n-triples, */*;q=0.1" forHTTPHeaderField:@"Accept"];
    
	NSHTTPURLResponse* resp	= nil;
//	NSLog(@"request: %@", req);
    NSError* e;
	NSData* data	= [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&e];
//	NSLog(@"response: %@ (%lu bytes)", resp, [data length]);
    if ([resp isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger code	= [resp statusCode];
//        NSLog(@"HTTP GET response: %03d", (int) code);
        if (code >= 300) {
            if (error) {
                NSLog(@"Error loading URL: %@", e);
            }
            if ([silent booleanValue]) {
                NSNumber* r = [NSNumber numberWithBool:YES];
                return [@[r] objectEnumerator];
            } else {
                NSLog(@"%@", [NSHTTPURLResponse localizedStringForStatusCode:code]);
                return nil;
            }
        }
    } else {
        if (error && ![silent booleanValue]) {
            NSLog(@"Error loading URL: %@", error);
            return nil;
        }
    }
    

    if (RDFParserClass == nil) {
        NSString* ct    = [[resp allHeaderFields] valueForKey:@"Content-Type"];
        if ([ct containsString:@"text/turtle"]) {
            RDFParserClass  = [SPKTurtleParser class];
        } else {
            NSLog(@"****************************** no rdf parser class for %@", ct);
            if (!ct) {
                NSLog(@"%@", resp);
            }
            return [@[] objectEnumerator];
        }
    }
    
    
    id<GTWRDFParser> parser = [[RDFParserClass alloc] initWithData:data base:base];
//    NSLog(@"parser: %@", parser);
    __block NSUInteger count    = 0;
    [parser enumerateTriplesWithBlock:^(id<GTWTriple> t) {
        GTWQuad* q  = [GTWQuad quadFromTriple:t withGraph:graph];
        NSError* e;
        count++;
        [mmodel addQuad:q error:&e];
    } error:&error];
//    NSLog(@"loaded %lu quads", count);
    if (error && ![silent booleanValue]) {
        NSLog(@"Error loading graph: %@", error);
        return nil;
    }

    NSNumber* r = [NSNumber numberWithBool:YES];
    return [@[r] objectEnumerator];
}

- (NSEnumerator*) evaluateCreate:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    if (![model conformsToProtocol:@protocol(GTWMutableModel)]) {
        NSLog(@"Model is not mutable");
        return nil;
    }
    NSError* error  = nil;
    id<GTWMutableModel> mmodel  = (id<GTWMutableModel>) model;
    
    id<SPKTree> list        = plan.treeValue;
    id<SPKTree> silentTree  = list.arguments[0];
    id<GTWLiteral> silent   = silentTree.value;
    id<SPKTree> graphTree   = list.arguments[1];
    id<GTWIRI> graph        = graphTree.value;
    [mmodel createGraph:graph error:&error];
    if (error && ![silent booleanValue]) {
        NSLog(@"Error creating graph: %@", error);
        return nil;
    }
    
    NSNumber* r = [NSNumber numberWithBool:YES];
    return [@[r] objectEnumerator];
}

- (NSEnumerator*) evaluateDrop:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    if (![model conformsToProtocol:@protocol(GTWMutableModel)]) {
        NSLog(@"Model is not mutable");
        return nil;
    }
    NSError* error;
    id<GTWMutableModel> mmodel  = (id<GTWMutableModel>) model;

    if ([plan.type isEqual:kPlanDrop]) {
        // DROP
        id<SPKTree> graphTree   = plan.treeValue;
        id<GTWIRI> graph        = graphTree.value;
//        NSLog(@"DROPing graph %@", graph);
        [mmodel dropGraph:graph error:&error];
        if (error) {
            NSLog(@"Error dropping graph: %@", error);
        }
    } else {
        // DROP ALL
        NSMutableSet* graphs    = [NSMutableSet set];
        [model enumerateGraphsUsingBlock:^(id<GTWTerm> g) {
            [graphs addObject:g];
        } error:&error];
        if (error) {
            NSLog(@"Error enumerating graphs for DROP: %@", error);
        }
        NSProgress *progress = [NSProgress progressWithTotalUnitCount:[graphs count]];
        for (id<GTWIRI> graph in graphs) {
//            NSLog(@"DROPing graph %@", graph);
            [progress becomeCurrentWithPendingUnitCount:1];
            [mmodel dropGraph:graph error:&error];
            if (error) {
                NSLog(@"Error dropping graph: %@", error);
            }
            [progress resignCurrent];
        }
    }
    NSNumber* r = [NSNumber numberWithBool:YES];
    return [@[r] objectEnumerator];
}

- (NSEnumerator*) evaluateDeleteData:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    if (![model conformsToProtocol:@protocol(GTWMutableModel)]) {
        NSLog(@"Model is not mutable");
        return nil;
    }
    NSError* error;
    id<GTWMutableModel> mmodel  = (id<GTWMutableModel>) model;
    
    for (id<SPKTree> tree in plan.arguments) {
        id<GTWQuad> q   = tree.value;
        [mmodel removeQuad:q error:&error];
        if (error) {
            NSLog(@"Error removing quad: %@", error);
        }
    }
    
    NSNumber* r = [NSNumber numberWithBool:YES];
    return [@[r] objectEnumerator];
}

- (NSEnumerator*) evaluateModifyPlan:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    id<SPKTree> delete  = plan.arguments[0];
    id<SPKTree> insert  = plan.arguments[1];
    id<SPKTree, GTWQueryPlan> subplan   = plan.arguments[2];
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:3];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    NSEnumerator* e     = [self evaluateQueryPlan:subplan withModel:model];
    NSArray* results    = [e allObjects];
    [progress resignCurrent];
    
//    NSLog(@"Modify matched results: %@", results);
    
    if (![model conformsToProtocol:@protocol(GTWMutableModel)]) {
        NSLog(@"Model is not mutable");
        return nil;
    }
    
    
    NSUInteger counter = 0;
    NSMutableSet* blanks    = [NSMutableSet set];
    for (id<SPKTree> tree in insert.arguments) {
        id<GTWStatement> st = tree.value;
        for (id<GTWTerm> term in [st allValues]) {
            if ([term isKindOfClass:[GTWBlank class]]) {
                [blanks addObject:term];
            }
        }
    }
    
    NSError* error;
    id<GTWMutableModel> mmodel  = (id<GTWMutableModel>) model;
    
//    NSLog(@"DELETE pattern: %@", delete);
    [progress becomeCurrentWithPendingUnitCount:1];
    for (NSDictionary* result in results) {
        NSMutableDictionary* mapping    = [NSMutableDictionary dictionary];
        for (NSString* varname in result) {
            GTWVariable* v  = [[GTWVariable alloc] initWithValue:varname];
            mapping[v]    = result[varname];
        }
        for (id<SPKTree> tree in delete.arguments) {
            id<GTWRewriteable> pattern  = tree.value;
            id<GTWQuad, GTWRewriteable> st   = [pattern copyReplacingValues:mapping];
            if (st) {
                if ([st isGround]) {
//                    NSLog(@"removing %@", st);
                    [mmodel removeQuad:st error:&error];
                    if (error) {
                        NSLog(@"Error removing quad: %@", error);
                    }
                }
            }
        }
    }
    [progress resignCurrent];
    
    [progress becomeCurrentWithPendingUnitCount:1];
//    NSLog(@"INSERT pattern: %@", insert);
    NSUInteger updateNumber = ++_updateOperationCounter;
    for (NSDictionary* result in results) {
        NSUInteger loopCount    = counter++;
        NSMutableDictionary* mapping    = [NSMutableDictionary dictionary];
        for (id<GTWTerm> b in blanks) {
            id<GTWTerm> nb  = [[GTWBlank alloc] initWithValue:[NSString stringWithFormat:@"b%lu.%lu.%@", updateNumber, loopCount, b.value]];
            mapping[b]      = nb;
        }
        for (NSString* varname in result) {
            GTWVariable* v  = [[GTWVariable alloc] initWithValue:varname];
            mapping[v]    = result[varname];
        }
//        NSLog(@"INSERT mapping: %@", mapping);
        for (id<SPKTree> tree in insert.arguments) {
            id<GTWRewriteable> pattern  = tree.value;
            id<GTWQuad, GTWRewriteable> st   = [pattern copyReplacingValues:mapping];
            if (st) {
                if ([st isGround]) {
//                    NSLog(@"adding %@", st);
                    [mmodel addQuad:st error:&error];
                    if (error) {
                        NSLog(@"Error adding quad: %@", error);
                    }
                }
            }
        }
    }
    [progress resignCurrent];
    
    NSNumber* r = [NSNumber numberWithBool:YES];
    return [@[r] objectEnumerator];
}

- (NSEnumerator*) evaluateConstructPlan:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:2];
    
    [progress becomeCurrentWithPendingUnitCount:1];
    NSEnumerator* results   = [self evaluateQueryPlan:plan.arguments[0] withModel:model];
    [progress resignCurrent];
    
    NSMutableArray* triples = [NSMutableArray array];
    NSArray* template       = plan.value;

    NSUInteger counter = 0;
    NSMutableSet* blanks    = [NSMutableSet set];
    for (id<GTWTriple> t in template) {
        for (id<GTWTerm> term in [t allValues]) {
            if ([term isKindOfClass:[GTWBlank class]]) {
                [blanks addObject:term];
            }
        }
    }
//    NSLog(@"pattern blanks: %@", blanks);
    [progress becomeCurrentWithPendingUnitCount:1];
    for (NSDictionary* result in results) {
        NSUInteger loopCount    = counter++;
        NSMutableDictionary* mapping    = [NSMutableDictionary dictionary];
        for (id<GTWTerm> b in blanks) {
            id<GTWTerm> nb  = [[GTWBlank alloc] initWithValue:[NSString stringWithFormat:@"b%lu-%@", loopCount, b.value]];
            mapping[b]      = nb;
        }
        for (NSString* varname in result) {
            GTWVariable* v  = [[GTWVariable alloc] initWithValue:varname];
            mapping[v]    = result[varname];
        }
//        NSLog(@"mapping: %@", mapping);
        for (id<GTWRewriteable> pattern in template) {
//            NSLog(@"-> %@", pattern);
            id<GTWTriple, GTWRewriteable> triple   = [pattern copyReplacingValues:mapping];
            if (triple) {
                if ([triple isGround]) {
                    [triples addObject:triple];
                }
            }
        }
    }
    [progress resignCurrent];
    return [triples objectEnumerator];
}

- (NSEnumerator*) evaluateSlice:(id<SPKTree, GTWQueryPlan>)plan withModel:(id<GTWModel>)model {
    NSEnumerator* results   = [self _evaluateQueryPlan:plan.arguments[0] withModel:model];
    id<SPKTree> offsetNode  = plan.arguments[1];
    id<SPKTree> limitNode   = plan.arguments[2];
    id<GTWLiteral> offset  = offsetNode.value;
    id<GTWLiteral> limit   = limitNode.value;
    NSInteger o = [offset integerValue];
    NSInteger l = [limit integerValue];
    int i;
    if (o > 0) {
        for (i = 0; i < o; i++) {
            [results nextObject];
        }
    }
    if (l < 0) {
        return results;
    } else if (l == 0) {
        return [@[] objectEnumerator];
    } else {
        NSMutableArray* slice   = [NSMutableArray array];
        NSUInteger count    = 0;
        for (id r in results) {
            count++;
            [slice addObject:r];
            if (count >= l)
                break;
        }
        return [slice objectEnumerator];
    }
}

- (NSEnumerator*) _evaluateQueryPlan: (id<SPKTree, GTWQueryPlan>) plan withModel: (id<GTWModel>) model {
    SPKTreeType type    = plan.type;
    if ([type isEqual:kPlanAsk]) {
        return [self evaluateAsk:plan withModel:model];
    } else if ([type isEqual:kPlanHashJoin]) {
        return [self evaluateHashJoin:plan withModel:model];
    } else if ([type isEqual:kPlanNLjoin] || [type isEqual:kPlanNLLeftJoin]) {
        return [self evaluateNLJoin:plan withModel:model];
    } else if ([type isEqual:kPlanMinus]) {
        return [self evaluateMinus:plan withModel:model];
    } else if ([type isEqual:kPlanDistinct]) {
        return [self evaluateDistinct:plan withModel:model];
    } else if ([type isEqual:kPlanProject]) {
        return [self evaluateProject:plan withModel:model];
    } else if ([type isEqual:kTreeQuad]) {
        return [self evaluateQuad:plan withModel:model];
    } else if ([type isEqual:kPlanOrder]) {
        return [self evaluateOrder:plan withModel:model];
    } else if ([type isEqual:kPlanUnion]) {
        return [self evaluateUnion:plan withModel:model];
    } else if ([type isEqual:kPlanFilter]) {
        return [self evaluateFilter:plan withModel:model];
    } else if ([type isEqual:kPlanExtend]) {
        return [self evaluateExtend:plan withModel:model];
    } else if ([type isEqual:kPlanSlice]) {
        return [self evaluateSlice:plan withModel:model];
    } else if ([type isEqual:kPlanGraph]) {
        return [self evaluateGraphPlan:plan withModel:model];
    } else if ([type isEqual:kPlanService]) {
        return [self evaluateServicePlan:plan withModel:model];
    } else if ([type isEqual:kPlanGroup]) {
        return [self evaluateGroupPlan:plan withModel:model];
    } else if ([type isEqual:kPlanJoinIdentity]) {
        return [@[ @{} ] objectEnumerator];
    } else if ([type isEqual:kPlanEmpty]) {
        return [@[] objectEnumerator];
    } else if ([type isEqual:kPlanZeroOrOnePath]) {
        return [self evaluatePathPlan:plan withModel:model includeZeroLengthResults:YES includeMoreLengthResults:NO];
    } else if ([type isEqual:kPlanOneOrMorePath]) {
        return [self evaluatePathPlan:plan withModel:model includeZeroLengthResults:NO includeMoreLengthResults:YES];
    } else if ([type isEqual:kPlanZeroOrMorePath]) {
        return [self evaluatePathPlan:plan withModel:model includeZeroLengthResults:YES includeMoreLengthResults:YES];
    } else if ([type isEqual:kPlanNPSPath]) {
        return [self evaluateNPSPathPlan:plan withModel:model];
    } else if ([type isEqual:kPlanConstruct]) {
        return [self evaluateConstructPlan:plan withModel:model];
    } else if ([type isEqual:kPlanModify]) {
        return [self evaluateModifyPlan:plan withModel:model];
    } else if ([type isEqual:kPlanInsertData]) {
        return [self evaluateInsertData:plan withModel:model];
    } else if ([type isEqual:kPlanDeleteData]) {
        return [self evaluateDeleteData:plan withModel:model];
    } else if ([type isEqual:kPlanDrop] || [type isEqual:kPlanDropAll]) {
        return [self evaluateDrop:plan withModel:model];
    } else if ([type isEqual:kPlanCreate]) {
        return [self evaluateCreate:plan withModel:model];
    } else if ([type isEqual:kPlanLoad]) {
        return [self evaluateLoad:plan withModel:model];
    } else if ([type isEqual:kPlanSequence]) {
        NSEnumerator* e;
        NSProgress *progress = [NSProgress progressWithTotalUnitCount:[plan.arguments count]];
        
        for (id<GTWQueryPlan> p in plan.arguments) {
            [progress becomeCurrentWithPendingUnitCount:1];
            e   = [self evaluateQueryPlan:p withModel:model];
            [progress resignCurrent];
        }
        
        if (!e) {
            // this was a no-op update sequence, which trivially succeeds
            NSNumber* r = [NSNumber numberWithBool:YES];
            e   = [@[r] objectEnumerator];
        }
        return e;
    } else if ([type isEqual:kTreeResultSet]) {
        NSArray* resultsTree    = plan.arguments;
        NSMutableArray* results = [NSMutableArray arrayWithCapacity:[resultsTree count]];
        for (id<SPKTree> r in resultsTree) {
            NSDictionary* rt  = r.value;
            NSMutableDictionary* result = [NSMutableDictionary dictionary];
            for (id<GTWTerm> k in rt) {
                id<SPKTree> v   = rt[k];
                id<GTWTerm> t   = v.value;
                result[k.value]       = t;
            }
            [results addObject:result];
        }
        return [results objectEnumerator];
    } else if ([plan.treeTypeName isEqualToString:@"PlanCustom"]) {
        NSEnumerator*(^impl)(id<SPKTree, GTWQueryPlan> plan, id<GTWModel> model)    = plan.value;
        return impl(plan, model);
    } else {
        NSLog(@"Cannot evaluate query plan type %@", [plan treeTypeName]);
    }
    return nil;
}

- (NSEnumerator*) evaluateQueryPlan: (id<SPKTree, GTWQueryPlan>) plan withModel: (id<GTWModel>) model {
    NSDictionary* impls = [self.functionImplementations copy];
    self.evalctx    = [[SPKExpressionEvaluationContext alloc] initWithFunctionImplementations:impls];
    self.evalctx.queryengine    = self;
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    [progress becomeCurrentWithPendingUnitCount:1];
    NSEnumerator* e     = [self _evaluateQueryPlan:plan withModel:model];
    [progress resignCurrent];
    return e;
}

- (void) registerFunction:(NSString*)iri withBlock:(id<GTWTerm>(^)(id<GTWQueryEngine> engine, id<GTWModel> model, NSArray* args))block {
    self.functionImplementations[iri]   = block;
}

@end
