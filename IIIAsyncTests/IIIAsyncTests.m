//
//  IIIAsyncTests.m
//  IIIAsync
//
//  Created by Steve Streza on 7/25/12.
//  Copyright (c) 2012 Mustacheware. All rights reserved.
//

#import "ConcurrentlyTests.h"
#import "IIIAsync.h"

@implementation IIIAsyncTests{
	NSDate *triggerStart;
	BOOL trigger;
}

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
	trigger = YES;
	triggerStart = nil;
}

- (void)tearDown
{
    // Tear-down code here.
    trigger = NO;
	triggerStart = nil;
    [super tearDown];
}

-(void)waitForTrigger{
	triggerStart = [NSDate date];
	while(trigger){
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	}
	trigger = YES;
}

-(void)trigger{
	trigger = NO;
	NSLog(@"Triggered after %g seconds", [[NSDate date] timeIntervalSinceDate:triggerStart]);
}

- (void)testIterateSerially
{
	IIIAsync *async = [IIIAsync mainThreadAsync];
	NSArray *items = @[@"Hello", @"World", @"What's up", @"not much", @"how about you", @"YOLO"];
	__block NSArray *response = nil;
	
	[async iterateSerially:items withIterator:^(id object, NSUInteger index, IIIAsyncCallback callback) {
//		NSLog(@"Object! %@", object);
		callback([object uppercaseString], nil);
	} callback:^(id result, NSError *error) {
//		NSLog(@"Done!");
		response = result;
		[self trigger];
	}];
	
	[self waitForTrigger];
	
	for(NSUInteger index = 0; index < items.count; index++){
		NSString *source = [items objectAtIndex:index];
		NSString *dest = [response objectAtIndex:index];
		
		STAssertEqualObjects([source uppercaseString], dest, @"String %i is not equal: %@ vs %@",index, source, dest);
	}
}

- (void)testIterateParallel
{
	IIIAsync *async = [IIIAsync globalAsync];
	NSArray *items = @[@"Hello", @"World", @"What's up", @"not much", @"how about you", @"YOLO"];
	
	__block NSArray *response = nil;

	[async iterateParallel:items withIterator:^(id object, NSUInteger index, IIIAsyncCallback callback) {
		callback([object uppercaseString], nil);
	} callback:^(id result, NSError *error) {
		response = result;
		[self trigger];
	}];
	
	[self waitForTrigger];
	
	for(NSUInteger index = 0; index < items.count; index++){
		NSString *source = [items objectAtIndex:index];
		NSString *dest = [response objectAtIndex:index];
		
		STAssertEqualObjects([source uppercaseString], dest, @"String %i is not equal: %@ vs %@",index, source, dest);
	}
}

#define ASSERT_STATE(ds1, de1, ds2, de2, ds3, de3) do{\
	STAssertEquals(didStart1, ds1, @"Start 1 is wrong"); \
	STAssertEquals(didStart2, ds2, @"Start 2 is wrong"); \
	STAssertEquals(didStart3, ds3, @"Start 3 is wrong"); \
	STAssertEquals(didEnd1, de1, @"End 1 is wrong"); \
	STAssertEquals(didEnd2, de2, @"End 2 is wrong"); \
	STAssertEquals(didEnd3, de3, @"End 3 is wrong"); \
}while(0)

-(void)testParallelMainThread{
	__block BOOL didStart1, didEnd1, didStart2, didEnd2, didStart3, didEnd3;
	didStart1 = didStart2 = didStart3 = didEnd1 = didEnd2 = didEnd3 = NO;
	
	IIIAsync *async = [IIIAsync mainThreadAsync];
	[async runSeries:@[^(IIIAsyncCallback callback){
		STAssertTrue([[NSThread currentThread] isMainThread], @"Not main thread");
		ASSERT_STATE(NO, NO, NO, NO, NO, NO);
		didStart1 = YES;
		ASSERT_STATE(YES, NO, NO, NO, NO, NO);
		didEnd1 = YES;
		ASSERT_STATE(YES, YES, NO, NO, NO, NO);
		callback(nil, nil);
	}, ^(IIIAsyncCallback callback){
		STAssertTrue([[NSThread currentThread] isMainThread], @"Not main thread");
		ASSERT_STATE(YES, YES, NO, NO, NO, NO);
		didStart2 = YES;
		ASSERT_STATE(YES, YES, YES, NO, NO, NO);
		didEnd2 = YES;
		ASSERT_STATE(YES, YES, YES, YES, NO, NO);
		callback(nil, nil);
	}, ^(IIIAsyncCallback callback){
		STAssertTrue([[NSThread currentThread] isMainThread], @"Not main thread");
		ASSERT_STATE(YES, YES, YES, YES, NO, NO);
		didStart3 = YES;
		ASSERT_STATE(YES, YES, YES, YES, YES, NO);
		didEnd3 = YES;
		ASSERT_STATE(YES, YES, YES, YES, YES, YES);
		callback(nil, nil);
	}] callback:^(id result, NSError *error) {
		STAssertTrue([[NSThread currentThread] isMainThread], @"Not main thread");
		ASSERT_STATE(YES, YES, YES, YES, YES, YES);
		[self trigger];
	}];
	[self waitForTrigger];
}

-(void)testSeriesBackground{
	__block BOOL didStart1, didEnd1, didStart2, didEnd2, didStart3, didEnd3;
	didStart1 = didStart2 = didStart3 = didEnd1 = didEnd2 = didEnd3 = NO;
	
	IIIAsync *async = [IIIAsync backgroundThreadAsync];
	[async runSeries:@[^(IIIAsyncCallback callback){
		STAssertFalse([[NSThread currentThread] isMainThread], @"On main thread");
		ASSERT_STATE(NO, NO, NO, NO, NO, NO);
		didStart1 = YES;
		ASSERT_STATE(YES, NO, NO, NO, NO, NO);
		didEnd1 = YES;
		ASSERT_STATE(YES, YES, NO, NO, NO, NO);
		callback(nil, nil);
	}, ^(IIIAsyncCallback callback){
		STAssertFalse([[NSThread currentThread] isMainThread], @"On main thread");
		ASSERT_STATE(YES, YES, NO, NO, NO, NO);
		didStart2 = YES;
		ASSERT_STATE(YES, YES, YES, NO, NO, NO);
		didEnd2 = YES;
		ASSERT_STATE(YES, YES, YES, YES, NO, NO);
		callback(nil, nil);
	}, ^(IIIAsyncCallback callback){
		STAssertFalse([[NSThread currentThread] isMainThread], @"On main thread");
		ASSERT_STATE(YES, YES, YES, YES, NO, NO);
		didStart3 = YES;
		ASSERT_STATE(YES, YES, YES, YES, YES, NO);
		didEnd3 = YES;
		ASSERT_STATE(YES, YES, YES, YES, YES, YES);
		callback(nil, nil);
	}] callback:^(id result, NSError *error) {
		STAssertFalse([[NSThread currentThread] isMainThread], @"On main thread");
		ASSERT_STATE(YES, YES, YES, YES, YES, YES);
		[self trigger];
	}];
	[self waitForTrigger];
}

-(void)testRunConditionals{
	IIIAsync *async = [IIIAsync backgroundThreadAsync];
	NSDate *startDate = [NSDate date];
	__block NSInteger remaining = 10000000;
	__block NSInteger count = 0;
	[async runWhileTrue:^BOOL{
		return --remaining >= 0;
	} performBlock:^(IIIAsyncCallback callback) {
		++count;
		callback(nil, nil);
	} callback:^(id result, NSError *error) {
		NSLog(@"Whee count %i in %g seconds", count, [[NSDate date] timeIntervalSinceDate:startDate]);
		[self trigger];
	}];
	
	[self waitForTrigger];
}

@end