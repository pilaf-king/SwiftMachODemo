//
//  SwiftMethodTableModel.m
//  SwiftDemo
//
//  Created by 邓竹立 on 2021/3/1.
//

#import "SwiftMethodTableModel.h"

@implementation SwiftOverrideMethodModel

- (instancetype)initWith:(struct SwiftOverrideMethod* )overrideMethodST linkBase:(uintptr_t)linkBase{
    if (self = [super init]) {
        self.overrideClass = ((long)overrideMethodST + overrideMethodST->OverrideClass - linkBase);
        self.overrideMethod = ((long)overrideMethodST + sizeof(UInt32) + overrideMethodST->OverrideMethod - linkBase);
        self.method = ((long)overrideMethodST + 2*sizeof(UInt32) + overrideMethodST->Method - linkBase);
    }
    return self;
}

@end

@implementation SwiftMethodTableModel

@end

