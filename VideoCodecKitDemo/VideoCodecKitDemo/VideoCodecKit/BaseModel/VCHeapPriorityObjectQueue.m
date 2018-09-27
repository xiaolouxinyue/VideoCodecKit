//
//  VCHeapPriorityObjectQueue.m
//  VideoCodecKitDemo
//
//  Created by CmST0us on 2018/9/27.
//  Copyright © 2018年 eric3u. All rights reserved.
//

#import <pthread.h>
#import <sys/time.h>
#import <objc/runtime.h>

#import "VCHeapPriorityObjectQueue.h"

#define kVCPerformIfNeedThreadSafe(__code__) if (_isThreadSafe) { __code__;}

#define SWAP_OBJECT(__a__, __b__) NSObject *t = __a__; __a__ = __b__; __b__ = t;

static const char *kVCPriorityObjectRuntimePriorityKey = "kVCPriorityObjectRuntimePriorityKey";

@interface VCHeapPriorityObjectQueue () {
    int _size;
    int _count;
    
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
}

@property (nonatomic, strong) NSMutableArray *queue;
@end

@implementation VCHeapPriorityObjectQueue

- (NSInteger)priorityOfObject:(NSObject *)object {
    id priorityObj = objc_getAssociatedObject(object, kVCPriorityObjectRuntimePriorityKey);
    if ([priorityObj isKindOfClass:[NSNumber class]]) {
        return [priorityObj integerValue];
    }
    return -1;
}

- (void)setPriority:(NSInteger)priority
           toObject:(NSObject *)object {
    objc_setAssociatedObject(object, kVCPriorityObjectRuntimePriorityKey, @(priority), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (instancetype)initWithSize:(int)size
                isThreadSafe:(BOOL)isThreadSafe {
    self = [super init];
    if (self) {
        _isThreadSafe = isThreadSafe;
        
        kVCPerformIfNeedThreadSafe(pthread_mutex_init(&_mutex, NULL));
        kVCPerformIfNeedThreadSafe(pthread_cond_init(&_cond, NULL));
        
        _count = 0;
        _size = size;
        _queue = [[NSMutableArray alloc] initWithCapacity:_size];
    }
    return self;
}

- (void)clear {
    kVCPerformIfNeedThreadSafe(pthread_mutex_lock(&_mutex));
    
    _count = 0;
    [_queue removeAllObjects];
    kVCPerformIfNeedThreadSafe(pthread_mutex_unlock(&_mutex));
}

- (void)wakeupReader {
    if (_isThreadSafe) {
        pthread_mutex_lock(&_mutex);
        pthread_cond_signal(&_cond);
        pthread_mutex_unlock(&_mutex);
    }
}
- (BOOL)push:(NSObject *)object
    priority:(NSInteger)priority {
    kVCPerformIfNeedThreadSafe(pthread_mutex_lock(&_mutex));
    if (object == nil || [self isFull]) {
        kVCPerformIfNeedThreadSafe(pthread_mutex_unlock(&_mutex));
        return NO;
    }
    [self setPriority:priority toObject:object];
    
    [_queue insertObject:object atIndex:_count];
    [self popObjectAtIndex:_count withPriority:priority];
    
    _count ++;
    kVCPerformIfNeedThreadSafe(pthread_cond_signal(&_cond));
    kVCPerformIfNeedThreadSafe(pthread_mutex_unlock(&_mutex));
    return YES;
}

- (NSObject *)pull {
    kVCPerformIfNeedThreadSafe(pthread_mutex_lock(&_mutex));
    if (_count == 0) {
        if (_isThreadSafe == NO) {
            return NULL;
        }
        
        struct timeval tv;
        gettimeofday(&tv, NULL);
        
        struct timespec ts;
        ts.tv_sec = tv.tv_sec + 2;
        ts.tv_nsec = tv.tv_usec*1000;
        pthread_cond_timedwait(&_cond, &_mutex, &ts);
        if(_count == 0)
        {
            pthread_mutex_unlock(&_mutex);
            return NULL;
        }
    }
    
    // pop head
    NSObject *obj = _queue[0];
    _queue[0] = _queue[_count - 1];
    _count -= 1;
    
    NSInteger objPriority = [self priorityOfObject:obj];
    [self sinkObjectAtIndex:0 withPriority:objPriority];
    
    kVCPerformIfNeedThreadSafe(pthread_mutex_unlock(&_mutex));
    
    return obj;
}

// 上浮
- (void)popObjectAtIndex:(NSInteger)index
            withPriority:(NSInteger)priority {
    NSInteger objectIndex = index;
    while (objectIndex > 0) {
        NSInteger parentIndex = objectIndex / 2;
        NSInteger objectPriority = [self priorityOfObject:_queue[objectIndex]];
        NSInteger parentPriority = [self priorityOfObject:_queue[parentIndex]];
        if (objectPriority <= parentPriority) {
            break;
        }
        SWAP_OBJECT(_queue[objectIndex], _queue[parentIndex]);
        objectIndex = parentIndex;
    }
}

// 下沉
- (void)sinkObjectAtIndex:(NSInteger)index
             withPriority:(NSInteger)priority {
    NSInteger objectIndex = index;
    while (2 * objectIndex <= _count - 1) {
        NSInteger childIndex = 2 * objectIndex;
        NSInteger childLPriority = [self priorityOfObject:_queue[childIndex]];
        NSInteger childRPriority = [self priorityOfObject:_queue[childIndex + 1]];
        if (childIndex < _count - 1 && childLPriority < childRPriority) {
            childIndex += 1;
        }
        if (childLPriority >= childRPriority) {
            break;
        }
        SWAP_OBJECT(_queue[objectIndex], _queue[childIndex]);
        objectIndex = childIndex;
    }
}

- (int)count {
    return _count;
}

- (int)size {
    return _size;
}

- (BOOL)isFull {
    if (_count == _size) {
        return YES;
    }
    return NO;
}

@end
