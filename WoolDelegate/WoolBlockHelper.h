//
//  WoolBlockHelper.h
//  WoolDelegate
//
//  Created by Joshua Caswell on 12/12/11.
//

#ifndef WoolDelegate_WoolBlockHelper_h
#define WoolDelegate_WoolBlockHelper_h

/* The information in this header largely duplicates the private Blocks header
 * defining the ABI for Blocks. While the ABI is an implementation detail, it
 * is a _compile-time_ detail. An executable will not break in the field.
 */

/* Below code thanks very much to Mike Ash's MABlockForwarding project
 * https://github.com/mikeash/MABlockForwarding and
 * http://www.mikeash.com/pyblog/friday-qa-2011-10-28-generic-block-proxying.html
 */

struct BlockDescriptor
{
    unsigned long reserved;
    unsigned long size;
    void *rest[1];
};

struct Block
{
    void *isa;
    int flags;
    int reserved;
    void *invoke;
    struct BlockDescriptor *descriptor;
};

enum {
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE =     (1 << 30), 
};

// Return the block's invoke function pointer.
static void * BlockIMP(id block)
{
    return ((struct Block *)block)->invoke;
}


// Return a C string representing the block's signature; NSMethodSignature
// can use this.
static const char * BlockSig(id blockObj){
    struct Block *block = (void *)blockObj;
    struct BlockDescriptor *descriptor = block->descriptor;
    
    assert(block->flags & BLOCK_HAS_SIGNATURE);
    
    int index = 0;
    if(block->flags & BLOCK_HAS_COPY_DISPOSE)
        index += 2;
    
    return descriptor->rest[index];
}

/* End code from Mike Ash */


#endif /* WoolDelegate_WoolBlockHelper_h */