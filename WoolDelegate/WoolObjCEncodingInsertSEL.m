//
//  WoolObjCEncodingInsertSEL.m
//
//  Copyright (c) 2012 Joshua Caswell.

#import "WoolObjCEncoding.h"

/*
 * Modify the passed-in encoding string to include the encoding for a
 * SEL in its second slot. The encoding string from a Block lacks that element.
 */
char * encoding_createWithInsertedSEL(const char * original_encoding)
{
    // This doesn't account for negative offsets, although it's not clear
    // when those might crop up. According to bbum, the offsets are meaningless 
    // anyways.
    static char * SELenc = @encode(SEL);
    NSUInteger alignedSELsize;
    NSGetSizeAndAlignment(SELenc, NULL, &alignedSELsize);
    size_t len_SELenc = strlen(SELenc);
    
    // The new string will need to be the length of the old one plus
    // the length of a SEL's encode string plus the difference between the
    // string lengths of the old and new stack sizes (max 1) plus the 
    // length of the new biggest offset (which is a maximum of 1 longer
    // than the current biggest offset, which is extremely likely to be
    // two digits). Call that 4 bytes just to be safe.
    size_t len_new_string;
    len_new_string = strlen(original_encoding) + strlen(SELenc) + 5;
    
    char * new_encoding = calloc(len_new_string, sizeof(char));
    // Keep track of current end of construction
    char * new_enc_p = new_encoding;
    
    // Place return type in new string
    new_enc_p = encoding_getReturnType(original_encoding, new_enc_p, len_new_string);
    
    // Get stack length and increment it
    int stack_size = encoding_stackSize(original_encoding);
    stack_size += alignedSELsize;
    // Put it into the string
    size_t len_stack_size = log10(stack_size) + 1;
    snprintf(new_enc_p, len_stack_size + 1, "%d", stack_size);
    new_enc_p += len_stack_size;
    
    // Place first arg
    int offset;    // Offset is saved here for next argument (the SEL)
    char * arg1 = encoding_findArgument(original_encoding, 1, &offset);
    char * arg0 = encoding_selfArgument(original_encoding);
    size_t len_arg0 = arg1 - arg0;
    strncpy(new_enc_p, arg0, len_arg0);
    new_enc_p += len_arg0;
    
    // Place SEL's encoding
    strncpy(new_enc_p, SELenc, len_SELenc);
    new_enc_p += len_SELenc;
    // Re-use original arg1 offset
    size_t len_offset = log10(offset) + 1;
    snprintf(new_enc_p, len_offset + 1, "%d", offset);
    new_enc_p += len_offset;
    
    // Note end of new string to keep track of how much room is left
    char * end_new_encstring = new_encoding + (len_new_string * sizeof(char));
    // Loop over the rest of the args
    unsigned int numargs = encoding_numberOfArguments(original_encoding);
    for( int i = 1; i < numargs; i++ ){
        char * arg = encoding_findArgument(original_encoding, i, &offset);
        // Copy this encoded arg into the new string
        new_enc_p = arg_getType(arg, new_enc_p, end_new_encstring - new_enc_p);
        offset += alignedSELsize;
        len_offset = (int)(log10(offset) + 1);
        snprintf(new_enc_p, len_offset + 1, "%d", offset);
        new_enc_p += len_offset;
    }
    
    return new_encoding;
}