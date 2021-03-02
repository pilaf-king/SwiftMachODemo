//
//  WBOCTest.m
//  SwiftDemo
//
//  Created by 邓竹立 on 2021/2/26.
//

#import "WBOCTest.h"
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>
#import "SwiftDefines.h"
#import "SwiftMethodTableModel.h"

@implementation WBOCTest

+ (void)load{
    NSLog(@"_mh_execute_header = %lu",((uintptr_t)&_mh_execute_header));
}

+ (void)replace:(id)obj0 methodIndex0:(int)mInx0 withClass:(id)obj1 methodIndex1:(int)mInx1{
    
    NSString *className0 = NSStringFromClass([obj0 class]);
    NSString *className1 = NSStringFromClass([obj1 class]);
    
    NSArray *methods0 = [self findMethodTable:className0].vTable;
    NSArray *methods1 = [self findMethodTable:className1].vTable;
    
    if (methods0.count >= mInx0 &&
        methods1.count >= mInx1) {
    
        uintptr_t imp0 = [methods0[mInx0] unsignedIntegerValue];
        uintptr_t imp1 = [methods1[mInx1] unsignedIntegerValue];

        void *p0 = (__bridge void*)obj0;

        struct SwiftClass* swiftClass = (struct SwiftClass * )p0;

        UInt32 classObjectSize = swiftClass->classObjectSize;
        UInt32  classObjectAddressPoint = swiftClass->classObjectAddressPoint;

        int sizeOfVTable = (classObjectSize - classObjectAddressPoint) - 10 * sizeof(NSInteger);
        int totalVTableSize = sizeOfVTable / sizeof(NSInteger);
        
        for (int i = 0 ; i < totalVTableSize; i++) {
            uintptr_t tmp = (uintptr_t)swiftClass + (10 + i) * sizeof(NSInteger);
            uintptr_t funcAddress = (uintptr_t)*(void **)tmp;
            if (funcAddress == imp0) {
                memset((void*)tmp, 0, sizeof(NSInteger));
                memcpy((void*)tmp, &imp1, sizeof(NSInteger));
                break;
            }
        }
        return;
    }
}

+ (void)replace:(id)class{
    
}

+ (SwiftMethodTableModel *)findMethodTable:(NSString *)class{
        
    SwiftMethodTableModel *methodTableModel = [SwiftMethodTableModel new];
    //获取__swift5_types 数据
    NSUInteger textTypesSize = 0;
    char *types = getsectdata("__TEXT", "__swift5_types", &textTypesSize);
    uintptr_t exeHeader = (uintptr_t)(&_mh_execute_header);
    const struct segment_command_64 *linkedit =  getsegbyname("__LINKEDIT");
    
    //计算linkBase
    uintptr_t linkBase = linkedit->vmaddr-linkedit->fileoff;
    
    //遍历__swift5_types，内部包含class、struct、enum
    NSUInteger location = 0;
    
    for (int i = 0; i < textTypesSize / sizeof(UInt32); i++) {
        
        //计算出当前正在遍历的4字节在Mach-O文件中的偏移
        uintptr_t offset = (uintptr_t)types + location - linkBase;
        
        location += sizeof(uint32_t);
        
        //exeHeader 是当前运行APP的起始地址，exeHeader + offset 就能得到那4个字节在内存中的地址
        uintptr_t address = exeHeader + offset;
        
        //从内存中获取那4字节的内容
        UInt32 content = (UInt32)*(UInt32*)address;
        
        //mach-O中记录的是虚拟地址，content + offset 是Swift的相对寻址方式，得到的是虚拟地址，因此需要 - linkBase即为类描述的偏移地址
        uintptr_t typeOffset = content + offset - linkBase;
        
        //计算出类的描述在内存中的位置
        uintptr_t typeAddress = exeHeader + typeOffset;
        
        //不是类，则不处理
        struct SwiftType *type = (struct SwiftType *)typeAddress;
        if ((type->Flag & 0x1f) != SwiftKindClass ){
            continue;
        }
        
        NSMutableArray *vTable = @[].mutableCopy;
        NSMutableArray *ovTable = @[].mutableCopy;

        //按SwiftType 结构去解析内存
        struct SwiftBaseType *baseType = (struct SwiftBaseType *)typeAddress;
    
        uintptr_t classNameOffset = typeOffset + baseType->Name + 8;
        
        char *className = (char *)(exeHeader + classNameOffset);
        NSString *name = [NSString stringWithFormat:@"%s",className];
        uintptr_t parentOffset = typeOffset + 1 * 4 + baseType->Parent - linkBase;
        SwiftKind kind = SwiftKindUnknown;
        while (kind != SwiftKindModule) {

            uintptr_t parent = exeHeader + parentOffset;

            struct SwiftBaseType *parentType = (struct SwiftBaseType *)parent;
            kind = parentType->Flag;
            
            uintptr_t parentNameContent = parentType->Name;
            uintptr_t parentNameOffset = parentOffset + 2 * 4 + parentNameContent;
                        
            char *parentName = (char *)(exeHeader + parentNameOffset);
            name = [NSString stringWithFormat:@"%s.%@",parentName,name];
            
            uintptr_t parentOffsetContent = parentType->Parent - linkBase;
            parentOffset = parentOffset + 1 * 4 + parentOffsetContent;
        }
        
        if (![class isEqualToString:name]) {
            continue;
        }
        
        //遍历Vtable和overrideTable
        BOOL hasVtable = [self hasVTable:baseType];
        BOOL hasOverrideTable = [self hasOverrideTable:baseType];
        BOOL hasSingletonMetadataInitialization = [self hasSingletonMetadataInitialization:baseType];
        short genericSize = [self addPlaceholderWithGeneric:typeOffset];
        if (!hasVtable && !hasOverrideTable ) {continue;}
        
        uintptr_t location = typeOffset + sizeof(struct SwiftClassTypeNoMethods) + 8 + (hasSingletonMetadataInitialization?12:0) + genericSize + linkBase;

        if ([self hasVTable:baseType]) {
            UInt32* methodNum = (UInt32*)location;
            uintptr_t methodLocation = 0;
            for (int j = 0; j < *methodNum; j ++) {
                uintptr_t methodOffset = location + methodLocation;
                uintptr_t methodAddress = exeHeader + methodOffset;
                
                struct SwiftMethod *methodType = (struct SwiftMethod *)methodAddress;
                uintptr_t imp = ((long)methodType + sizeof(UInt32) + methodType->Offset - linkBase);
                [vTable addObject:@(imp)];
                methodLocation += sizeof(struct SwiftMethod);
            }
        }
        if ([self hasOverrideTable:baseType]) {
            UInt32* methodNum = (UInt32*)location;
            uintptr_t methodLocation = 0;
            for (int j = 0; j < *methodNum; j ++) {
                uintptr_t methodOffset = location + methodLocation;
                uintptr_t methodAddress = exeHeader + methodOffset;
                
                struct SwiftOverrideMethod *methodType = (struct SwiftOverrideMethod *)methodAddress;
                SwiftOverrideMethodModel *model = [[SwiftOverrideMethodModel alloc] initWith:methodType linkBase:linkBase];
                [ovTable addObject:model];
                methodLocation += sizeof(struct SwiftMethod);
            }
        }
        
        methodTableModel.vTable = vTable.copy;
        methodTableModel.overrideTable = ovTable.copy;
        
    }
    return methodTableModel;
}


#pragma mark Flag
+ (BOOL)hasVTable:(struct SwiftBaseType*)type{
    if ((type->Flag & 0x80000000) == 0x80000000) {return YES;}
    return NO;
}

+ (BOOL)hasOverrideTable:(struct SwiftBaseType*)type{
    if ((type->Flag & 0x40000000) == 0x40000000) {return YES;}
    return NO;
}

+ (BOOL)isGenericType:(struct SwiftBaseType*)type{
    if ( (type->Flag & 0x80 )) {return YES;}
    return NO;
}

+ (BOOL)isGeneric:(struct SwiftType*)type{
    if ( (type->Flag & 0x80 )) {return YES;}
    return NO;
}

+ (BOOL)hasSingletonMetadataInitialization:(struct SwiftBaseType*)type{
    if ( (type->Flag & 0x00010000 )) {return YES;}
    return NO;
}

+ (SwiftMethodKind)getSwiftMethodKind:(struct SwiftMethod*)method{
    SwiftMethodKind kind = (SwiftMethodKind)(method->Flag&SwiftMethodTypeKind);
    return kind;
}

+ (SwiftMethodType)getSwiftMethodType:(struct SwiftMethod*)method{
    SwiftMethodType type = SwiftMethodTypeKind;
    if ((method->Flag&SwiftMethodTypeInstance) == SwiftMethodTypeInstance) {
        type = SwiftMethodTypeInstance;
    }else if ((method->Flag&SwiftMethodTypeDynamic) == SwiftMethodTypeDynamic){
        type = SwiftMethodTypeDynamic;
    }else if ((method->Flag&SwiftMethodTypeExtraDiscriminator) == SwiftMethodTypeExtraDiscriminator){
        type = SwiftMethodTypeExtraDiscriminator;
    }
    return type;
}

+ (SwiftKind)getSwiftType:(struct SwiftType*)type{
    //读低五位判断类型
    if ((type->Flag & 0x1f) == SwiftKindClass) {
        return SwiftKindClass;
    }else if ((type->Flag & 0x3) == SwiftKindProtocol){
        return SwiftKindProtocol;
    }else if((type->Flag & 0x1f) == SwiftKindStruct){
        return SwiftKindStruct;
    }else if((type->Flag & 0x1f) == SwiftKindEnum){
        return SwiftKindEnum;
    }else if((type->Flag & 0x0f) == SwiftKindModule){
        return SwiftKindModule;
    }
    
    return SwiftKindUnknown;
}

+ (short)addPlaceholderWithGeneric:(unsigned long long)typeOffset{
    
    struct SwiftType* swiftType = (struct SwiftType* )((uintptr_t)(&_mh_execute_header) + typeOffset);
        
    if (![self isGeneric:swiftType]) {
        return 0;
    }
    //非class 不处理
    if ([self getSwiftType:swiftType] != SwiftKindClass) {
        return 0;
    }
    
    short paramsCount = 0;
    short requeireCount = 0;
    void *p0 = (void *)((uintptr_t)(&_mh_execute_header) + typeOffset + 13 * 4);
    void *p1 = (void *)((uintptr_t)(&_mh_execute_header) + typeOffset + 13 * 4 + 2);

    memcpy(&paramsCount, p0, sizeof(short));
    memcpy(&paramsCount, p1, sizeof(short));
    
    //4字节对齐
    short pandding = (unsigned)-paramsCount & 3;
    
    return (1 * 4 + 4 + 4 + paramsCount + pandding + 3 * 4 * (requeireCount) + 4);
}

@end
