//
//  ViewController.m
//  SwiftToolDemo
//
//  Created by 邓竹立 on 2020/11/13.
//

#import "ViewController.h"
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>
#import <objc/runtime.h>

struct SwiftType {
    uint32_t Flag;
    uint32_t Parent;
};

struct SwiftMethod {
    uint32_t Kind;
    uint32_t Offset;
};

//没有Vtable 的话使用此结构体会错误
struct SwiftClassType {
    uint32_t Flag;
    uint32_t Parent;
    int32_t  Name;
    int32_t  AccessFunction;
    int32_t  FieldDescriptor;
    int32_t  SuperclassType;
    uint32_t MetadataNegativeSizeInWords;
    uint32_t MetadataPositiveSizeInWords;
    uint32_t NumImmediateMembers;
    uint32_t NumFields;
    uint32_t Unknow1;
    uint32_t Offset;
    uint32_t NumMethods;
};

//OverrideTable结构如下，紧随VTable后4字节为OverrideTable数量，再其后为此结构数组
struct SwiftOverrideMethod {
    struct SwiftClassType *OverrideClass;
    struct SwiftMethod *OverrideMethod;
    struct SwiftMethod *Method;
};


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self test];
    
}

- (void)test{
    
    NSLog(@"DEMO 只做技术研究用，不保证方案可行");
    
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
        
        /**
         下面的代码最令人困惑，大家紧跟注释
         sizeof(uint32_t )== 4
         location 其实可以通过 i * sizeof(uint32_t) 来代替，就不改了。其作用是记录当前要获取__swift5_types中第几个4字节
         */
        
        //计算出当前正在遍历的4字节在Mach-O文件中的偏移
        uintptr_t offset = (uintptr_t)types + location - linkBase;
        
        //exeHeader 是当前运行APP的起始地址，exeHeader + offset 就能得到那4个字节在内存中的地址
        uintptr_t address = exeHeader + offset;
        
        //从内存中获取那4字节的内容
        UInt32 content = (UInt32)*(void **)address;
        
        //mach-O中记录的是虚拟地址，content + offset 是Swift的相对寻址方式，得到的是虚拟地址，因此需要 - linkBase即为类描述的偏移地址
        uintptr_t typeOffset = content + offset - linkBase;
        
        //计算出类的描述在内存中的位置
        uintptr_t typeAddress = exeHeader + typeOffset;
        
        //按SwiftType 结构去解析内存
        struct SwiftType *type = (struct SwiftType *)typeAddress;
        
        //0x80000050 只是个常规值，低5位可以代表32类型
        /**
         // Kinds of context descriptor.
         enum class ContextDescriptorKind : uint8_t {
         /// This context descriptor represents a module.
         Module = 0,
         
         /// This context descriptor represents an extension.
         Extension = 1,
         
         /// This context descriptor represents an anonymous possibly-generic context
         /// such as a function body.
         Anonymous = 2,
         
         /// This context descriptor represents a protocol context.
         Protocol = 3,
         
         /// This context descriptor represents an opaque type alias.
         OpaqueType = 4,
         
         /// First kind that represents a type of any sort.
         Type_First = 16,
         
         /// This context descriptor represents a class.
         Class = Type_First,
         
         /// This context descriptor represents a struct.
         Struct = Type_First + 1,
         
         /// This context descriptor represents an enum.
         Enum = Type_First + 2,
         
         /// Last kind that represents a type of any sort.
         Type_Last = 31,
         };
         */
        //0x80000050 只是个常规值，高2字节共16位代表是否有Vtable等
        /**
         /// Flags for nominal type context descriptors. These values are used as the
         /// kindSpecificFlags of the ContextDescriptorFlags for the type.
         class TypeContextDescriptorFlags : public FlagSet<uint16_t> {
         enum {
         // All of these values are bit offsets or widths.
         // Generic flags build upwards from 0.
         // Type-specific flags build downwards from 15.
         
         /// Whether there's something unusual about how the metadata is
         /// initialized.
         ///
         /// Meaningful for all type-descriptor kinds.
         MetadataInitialization = 0,
         MetadataInitialization_width = 2,
         
         /// Set if the type has extended import information.
         ///
         /// If true, a sequence of strings follow the null terminator in the
         /// descriptor, terminated by an empty string (i.e. by two null
         /// terminators in a row).  See TypeImportInfo for the details of
         /// these strings and the order in which they appear.
         ///
         /// Meaningful for all type-descriptor kinds.
         HasImportInfo = 2,
         
         /// Set if the type descriptor has a pointer to a list of canonical
         /// prespecializations.
         HasCanonicalMetadataPrespecializations = 3,
         
         // Type-specific flags:
         
         /// The kind of reference that this class makes to its resilient superclass
         /// descriptor.  A TypeReferenceKind.
         ///
         /// Only meaningful for class descriptors.
         Class_ResilientSuperclassReferenceKind = 9,
         Class_ResilientSuperclassReferenceKind_width = 3,
         
         /// Whether the immediate class members in this metadata are allocated
         /// at negative offsets.  For now, we don't use this.
         Class_AreImmediateMembersNegative = 12,
         
         /// Set if the context descriptor is for a class with resilient ancestry.
         ///
         /// Only meaningful for class descriptors.
         Class_HasResilientSuperclass = 13,
         
         /// Set if the context descriptor includes metadata for dynamically
         /// installing method overrides at metadata instantiation time.
         Class_HasOverrideTable = 14,
         
         /// Set if the context descriptor includes metadata for dynamically
         /// constructing a class's vtables at metadata instantiation time.
         ///
         /// Only meaningful for class descriptors.
         Class_HasVTable = 15,
         };
         
         */
        
        //比较有用的低5位和高16位，中间位用来表示version、是否唯一、泛型等，暂不关心
        /**回顾下，0x80000050的低5位为1 0 0 0 0 == 16 == ContextDescriptorKind.class，
         高16位为 1 0 0 0 0 0 0 0 0 0 0 0 0 0   TypeContextDescriptorFlags.Class_HasVTable == YES
         所以0x80000050的意思是具有VTable的类
         */
        if ((type->Flag & 0x80000050) == 0x80000050) {//tmp
            struct SwiftClassType *classType = (struct SwiftClassType *)typeAddress;
            UInt32 methodNum = classType->NumMethods;
            uintptr_t classNameOffset = typeOffset + classType->Name + 8;
            char *className = (char *)(exeHeader + classNameOffset);
            NSLog(@"%s 类 有%u个函数",className,(unsigned int)methodNum);
            
            //数量可能与你写的代码个数不同，因为属性会自动生成getter setter ，还有其他自动的函数。通过函数的前4字节可以确定函数类型
            
            uintptr_t methodLocation = 0;
            for (int j = 0; j < methodNum; j ++) {
                uintptr_t methodOffset = typeOffset + sizeof(struct SwiftClassType) + methodLocation;
                uintptr_t methodAddress = exeHeader + methodOffset;
                
                struct SwiftMethod *methodType = (struct SwiftMethod *)methodAddress;
                //只调用我们自己写的3个方法
                if (methodType -> Kind == 0x10) {
                    IMP imp = (IMP)((long)methodType + sizeof(UInt32) + methodType->Offset - linkBase);
                    imp();
                }
                
                methodLocation += sizeof(struct SwiftMethod);
            }
        }
        location += sizeof(uint32_t);
    }
}

@end
