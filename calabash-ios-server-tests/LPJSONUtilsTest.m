#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "LPJSONUtils.h"

@interface MyObject : NSObject

@property(strong, nonatomic, readonly) NSObject *object;
@property(strong, nonatomic, readonly) NSNumber *number;
@property(copy, nonatomic, readonly) NSArray *array;
@property(copy, nonatomic, readonly) NSDictionary *dictionary;
@property(strong, nonatomic, readonly) id idType;


- (void) selectorThatReturnsVoid;
- (BOOL) selectorThatReturnsBOOL;
- (NSInteger) selectorThatReturnsNSInteger;
- (CGFloat) selectorThatReturnsCGFloat;
- (char) selectorThatReturnsChar;
- (char *) selectorThatReturnsCharStar;

@end

@implementation MyObject

- (id) init {
  self = [super init];
  if (self) {
    _object = [NSObject new];
    _number = [NSNumber numberWithInt:0];
    _array = [NSArray array];
    _dictionary = [NSDictionary dictionary];
    _idType = nil;
  }
  return self;
}

- (void) selectorThatReturnsVoid { return; }
- (BOOL) selectorThatReturnsBOOL { return YES; }
- (NSInteger) selectorThatReturnsNSInteger { return 1; }
- (CGFloat) selectorThatReturnsCGFloat { return 0.0; }
- (char) selectorThatReturnsChar { return 'a'; }
- (const char *) selectorThatReturnsCharArray {
  return [@"abc" cStringUsingEncoding:NSASCIIStringEncoding];
}

- (char *) selectorThatReturnsCharStar {
  char *cString = "A c-string";
  return cString;
}

@end


@interface LPJSONUtilsTest : XCTestCase

@end

@implementation LPJSONUtilsTest

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Autoboxing

- (void) testCanAutoboxCharStar {
  char *cString = "A c-string";
  XCTAssertEqualObjects(@"A c-string", @(cString));
}

#pragma mark - dictionary:setObject:forKey

- (void) testDictionarySetObjectCanSetAnNonNilObject {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSString *key = @"key";
  NSString *object = @"object";
  [LPJSONUtils dictionary:dict setObject:object forKey:key];
  id actual = [dict objectForKey:key];
  XCTAssertEqualObjects(actual, object);
}

- (void) testDictionarySetObjectCanSetAndNilObject {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSString *key = @"key";
  NSString *object = nil;
  [LPJSONUtils dictionary:dict setObject:object forKey:key];
  id actual = [dict objectForKey:key];
  XCTAssertEqualObjects(actual, [NSNull null]);
}

#pragma mark - stringForSelector:returnValueForReceiver:


- (void) testStringForSelectorReturnValueForRecieverPointer {
  id object = [MyObject new];
  SEL selector = @selector(number);
  XCTAssertEqualObjects([LPJSONUtils stringForSelector:selector
                                returnValueEncodingForReceiver:object],
                        @"@");
}

- (void) testStringForSelectorReturnValueForRecieverVoid {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsVoid);
  XCTAssertEqualObjects([LPJSONUtils stringForSelector:selector
                                returnValueEncodingForReceiver:object],
                        @"v");
}

- (void) testStringForSelectorReturnValueForRecieverCharArray {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsCharArray);
  XCTAssertEqualObjects([LPJSONUtils stringForSelector:selector
                                returnValueEncodingForReceiver:object],
                        @"r*");
}

#pragma mark - selector:returnsPointerForReceiver:

// '@'
- (void) testSelectorReturnsPointerForObjectString {
  id object = @"object";
  SEL selector = @selector(substringToIndex:);
  XCTAssertTrue([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

// '@'
- (void) testSelectorReturnsPointerForObjectObject {
  id object = [MyObject new];
  SEL selector = @selector(number);
  XCTAssertTrue([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

// '@'
- (void) testSelectorReturnsPointerForObjectArray {
  id object = [MyObject new];
  SEL selector = @selector(array);
  XCTAssertTrue([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

// '@'
- (void) testSelectorReturnsPointerForObjectDictionary {
  id object = [MyObject new];
  SEL selector = @selector(dictionary);
  XCTAssertTrue([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

// '@'
- (void) testSelectorReturnsPointerForObjectIdType {
  id object = [MyObject new];
  SEL selector = @selector(idType);
  XCTAssertTrue([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

// 'v' - cannot be autoboxed
- (void) testSelectorReturnsPointerForObjectVoidReturn {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsVoid);
  XCTAssertFalse([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

// 'c'
- (void) testSelectorReturnsPointerForObjectBOOLReturn {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsBOOL);
  XCTAssertFalse([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

// 'i'
- (void) testSelectorReturnsPointerForObjectIntegerReturn {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsNSInteger);
  XCTAssertFalse([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

// 'f'
- (void) testSelectorReturnsPointerForObjectCGFloatReturn {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsCGFloat);
  XCTAssertFalse([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

// 'c'
- (void) testSelectorReturnsPointerForObjectCharReturn {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsChar);
  XCTAssertFalse([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

// 'r*' - can be autoboxed
- (void) testSelectorReturnsPointerForObjectCharArrayReturn {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsCharArray);
  XCTAssertFalse([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

// '*' - can be autoboxed
- (void) testSelectorReturnsPointerForObjectCharStarReturn {
  MyObject *object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsCharStar);
  XCTAssertFalse([LPJSONUtils selector:selector returnsNSObjectForReceiver:object]);
}

#pragma mark - selector:returnValueIsVoidForReceiver:

- (void) testSelectorReturnValueIsVoidForReceiverYES {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsVoid);
  XCTAssertTrue([LPJSONUtils selector:selector returnValueIsVoidForReceiver:object]);
}

- (void) testSelectorReturnValueIsVoidForReceiverNO {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsBOOL);
  XCTAssertFalse([LPJSONUtils selector:selector returnValueIsVoidForReceiver:object]);
}

#pragma mark - selector:returnValueCanBeAutoboxedForReceiver:

- (void) testSelectorReturnValueCanBeAutoboxedWithVoid {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsVoid);
  XCTAssertFalse([LPJSONUtils selector:selector returnValueCanBeAutoboxedForReceiver:object]);
}

- (void) testSelectorReturnValueCanBeAutoboxedWithPointer {
  id object = [MyObject new];
  SEL selector = @selector(number);
  XCTAssertFalse([LPJSONUtils selector:selector returnValueCanBeAutoboxedForReceiver:object]);
}

- (void) testSelectorReturnValueCanBeAutoboxedYES {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsBOOL);
  XCTAssertTrue([LPJSONUtils selector:selector returnValueCanBeAutoboxedForReceiver:object]);
}

#pragma mark - dictionary:setObject:usingSelector:receiver

- (void) testDictionarySetObjectUsingSelectorReceiverDoesNotRespondTo {
  id object = [MyObject new];
  SEL selector = NSSelectorFromString(@"receiverDoesNotRespondTo");
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSString *key = @"key";
  [LPJSONUtils dictionary:dict
          setObjectForKey:key
            usingSelector:selector
               onReceiver:object];
  XCTAssertEqualObjects([NSNull null], [dict objectForKey:key]);
}

- (void) testDictionarySetObjectUsingSelectorReceiverSelectorReturnsVoid {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsVoid);
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSString *key = @"key";
  [LPJSONUtils dictionary:dict
          setObjectForKey:key
            usingSelector:selector
               onReceiver:object];
  XCTAssertEqualObjects([NSNull null], [dict objectForKey:key]);
}

- (void) testDictionarySetObjectUsingSelectorValueIsNil {
  id object = [MyObject new];
  SEL selector = @selector(idType);
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSString *key = @"key";
  [LPJSONUtils dictionary:dict
          setObjectForKey:key
            usingSelector:selector
               onReceiver:object];
  XCTAssertEqualObjects([NSNull null], [dict objectForKey:key]);
}

- (void) testDictionarySetObjectUsingSelectorValueIsNonNil {
  MyObject *object = [MyObject new];
  SEL selector = @selector(object);
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSString *key = @"key";
  [LPJSONUtils dictionary:dict
          setObjectForKey:key
            usingSelector:selector
               onReceiver:object];
  XCTAssertEqualObjects(object.object, [dict objectForKey:key]);
}

- (void) testDictionarySetObjectUsingSelectorValueCanBeAutoBoxed {
  id object = [MyObject new];
  SEL selector = @selector(selectorThatReturnsBOOL);
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSString *key = @"key";
  XCTAssertNoThrow(
                   [LPJSONUtils dictionary:dict
                           setObjectForKey:key
                             usingSelector:selector
                                onReceiver:object]
                   );

}

@end