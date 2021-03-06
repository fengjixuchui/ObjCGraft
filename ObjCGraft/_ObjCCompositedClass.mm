//
//  _ObjCCompositedClass.mm
//  ObjCGraft
//
//  Created on 30/12/2018.
//

#import "_ObjCCompositedClass.h"

#import "_ObjCGraftResolver.h"
#import "_ObjCGraftCompositedClass.h"
#import "NSObject+ObjCGraft.h"
#import "_ObjCCompositedClassBackwardInstanceImpl.h"

namespace objcgraft {
    Class _ObjCCompositedClass::make(__unsafe_unretained Class semantic_class, const char * raw_class_name, _ObjCGraftRecordMap& graft_record_map) {
        auto cls = objc_allocateClassPair(semantic_class, raw_class_name, sizeof(void *) * _OBJC_COMPOSITED_CLASS_BACKWARD_IMPL_COUNT);
        
        objc_registerClassPair(cls);
        
        _ObjCCompositedClassInitialize(cls);
        
        auto graft_combination_list = _ObjCGraftResolver::shared().resolveGraftCombinationList(graft_record_map);
        
        _addSystemProtocols(cls);
        _addUserDefinedProtocols(cls, graft_record_map);
        _addSystemMethods(cls);
        _addUserDefinedMethods(cls, * graft_combination_list);
        
        return cls;
    }
    
    void _ObjCCompositedClass::_addSystemProtocols(__unsafe_unretained Class cls) {
        // Conforms to `_ObjCGraftCompositedClass`.
        class_addProtocol(cls, @protocol(_ObjCGraftCompositedClass));
    }
    
    void _ObjCCompositedClass::_addUserDefinedProtocols(__unsafe_unretained Class cls, _ObjCGraftRecordMap& graft_record_map) {
        for (auto& pair: graft_record_map) {
            class_addProtocol(cls, pair.first);
        }
    }
    
    void _ObjCCompositedClass::_addSystemMethods(__unsafe_unretained Class cls) {
        // Add `[NSObject -class]`
        class_addMethod(cls, @selector(class), (IMP)&_NSObjectGetClass, "@:");
        
        // Add `[NSObject -dealloc]`
        class_addMethod(cls, NSSelectorFromString(@"dealloc"), (IMP)&_NSObjectDealloc, "@:");
        
        // Add `[NSObject -respondsToSelector:]`
        class_addMethod(cls, @selector(respondsToSelector:), (IMP)&_NSObjectRespondsToSelector, "@::");
        
        // Add `[NSObject -conformsToProtocol:]`
        class_addMethod(cls, @selector(conformsToProtocol:), (IMP)&_NSObjectConformsToProtocol, "@:@");
    }
    
    void _ObjCCompositedClass::_addUserDefinedMethods(__unsafe_unretained Class cls, _ObjCGraftCombinationList& graft_combination_list) {
        Class metaClass = objc_getMetaClass(class_getName(cls));
        
        for (auto& graft_combination: graft_combination_list) {
            if (graft_combination.is_instance) {
                if (graft_combination.name == @selector(class)) {
                    _ObjCCompositedClass::setBackwardInstanceImpl(cls, graft_combination.impl, _ObjCCompositedClass::BackwardInstanceImplKind::ClassGetter);
                } else if (graft_combination.name == @selector(respondsToSelector:)) {
                    _ObjCCompositedClass::setBackwardInstanceImpl(cls, graft_combination.impl, _ObjCCompositedClass::BackwardInstanceImplKind::RespondsToSelector);
                } else if (graft_combination.name == @selector(conformsToProtocol:)) {
                    _ObjCCompositedClass::setBackwardInstanceImpl(cls, graft_combination.impl, _ObjCCompositedClass::BackwardInstanceImplKind::ConformsToProtocol);
                } else if (graft_combination.name == NSSelectorFromString(@"dealloc")) {
                    _ObjCCompositedClass::setBackwardInstanceImpl(cls, graft_combination.impl, _ObjCCompositedClass::BackwardInstanceImplKind::Dealloc);
                } else {
                    class_addMethod(cls, graft_combination.name, graft_combination.impl, graft_combination.types);
                }
            } else {
                class_addMethod(metaClass, graft_combination.name, graft_combination.impl, graft_combination.types);
            }
        }
    }
    
    void _ObjCCompositedClass::setBackwardInstanceImpl(Class cls, IMP impl, _ObjCCompositedClass::BackwardInstanceImplKind kind) {
        assert(class_conformsToProtocol(cls, @protocol(_ObjCGraftCompositedClass)));
        _ObjCCompositedClassSetBackwardInstanceImpl(cls, impl, kind);
    }
    
    IMP _ObjCCompositedClass::getBackwardInstanceImpl(Class cls, _ObjCCompositedClass::BackwardInstanceImplKind kind) {
        assert(class_conformsToProtocol(cls, @protocol(_ObjCGraftCompositedClass)));
        return _ObjCCompositedClassGetBackwardInstanceImpl(cls, kind);
    }
}
