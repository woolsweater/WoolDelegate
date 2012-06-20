//
//  WoolEncoding.m
//  EncodeStringMangling
//
//  Created by Joshua Caswell on 6/12/12.
//

#import "WoolEncoding.h"

/* Processes a compound type encoding, returning the number of characters it 
 * occupies in the string.
 */
static int subtypeUntil(const char * type, char endChar)
{
    int level = 0;
    const char * head = type;
    
    //
    while (*type)
    {
        if (!*type || (!level && (*type == endChar)))
            return (int)(type - head);
        
        switch (*type)
        {
            case ']': case '}': case ')': level--; break;
            case '[': case '{': case '(': level += 1; break;
        }
        
        type++;
    }
    
    //_objc_fatal("Type encoding: subtypeUntil: end of type encountered prematurely\n");
    return 0;
}


/* Moves past the non-numeric portion of an argument's encoding, returning a
 * pointer to the following char, which is the first digit char.
 */
static char * skipType(const char * type)
{
    char * p = (char *)type;
    while (1)
    {
        switch (*p++)
        {
            case 'O':    /* bycopy */
            case 'n':    /* in */
            case 'o':    /* out */
            case 'N':    /* inout */
            case 'r':    /* const */
            case 'V':    /* oneway */
            case '^':    /* pointers */
                break;
                
            case '@':   /* objects */
                if (p[0] == '?') p++;  /* Blocks */
                return p;
                
                /* arrays */
            case '[':
                while ((*p >= '0') && (*p <= '9')){
                    p++;
                }
                return p + subtypeUntil(p, ']') + 1;
                
                /* structures */
            case '{':
                return p + subtypeUntil(p, '}') + 1;
                
                /* unions */
            case '(':
                return p + subtypeUntil(p, ')') + 1;
                
                /* basic types */
            default:
                return p;
        }
    }
}

/* Takes a pointer to the beginning of an encoded argument and gets the offset 
 * portion of the encoding, returning a pointer to the following character. 
 * Returns the offset itself, as an int, indirectly.
 */
char * arg_getOffset(const char * argdesc, int * offset)
{
    BOOL offset_is_negative = NO;
    
    // Move past the non-offset portion
    char * desc_p = skipType(argdesc);
    
    // Skip GNU runtime's register parameter hint
    if( *desc_p == '+' ) desc_p++;
    
    // Note negative sign in offset
    if( *desc_p == '-' )
    {
        offset_is_negative = YES;
        desc_p++;
    }
    
    // Pick up offset value and compensate for it being negative
    *offset = 0;
    while( (*desc_p >= '0') && (*desc_p <= '9') ){
        *offset = *offset * 10 + (*desc_p++ - '0');
    }
    if( offset_is_negative ){
        *offset = -(*offset);
    }
    return desc_p;
}

/* Takes a pointer to the first char of an argument encoding and returns
 * a pointer to the first char of the following argument's encoding.
 */
char * arg_skipArg(const char * argdesc)
{   
    int ignored;
    return arg_getOffset(argdesc, &ignored);
}

/* Skips the return type and stack length to return a pointer to the first
 * char of the first argument's (self) encoding.
 */
char * encoding_selfArgument(const char * typedesc)
{
    return arg_skipArg(typedesc);
}

/* Takes a pointer to an argument encoding and a buffer (dst), along with the
 * buffer's length. Copies the type portion of the argument encoding string 
 * into dst, returning a pointer to the new last character in dst.
 */
char * arg_getType(const char *argdesc, char *buf, size_t buf_size)
{
    size_t len;
    const char *end;
    
    if (!buf) return (char *)argdesc;
    if (!argdesc) {
        strncpy(buf, "", buf_size);
        return NULL;
    }
    
    end = skipType(argdesc);
    len = end - argdesc;
    strncpy(buf, argdesc, MIN(len, buf_size));
    return buf + len;
    // Zero out the remainder of dst
    //if( len < dst_len ) memset(dst+len, 0, dst_len - len);
}

/* Takes an encoding string and a buffer and copies the encoded return 
 * type into the buffer, returning a pointer to the new final char in buf.
 */
char * encoding_getReturnType(const char *typedesc, char *buf, size_t buf_size)
{
    return arg_getType(typedesc, buf, buf_size);
}

/* Takes an encoding string and returns the stack size as an int. */
int encoding_stackSize(const char * typedesc)
{
    int stack_size;
    arg_getOffset(typedesc, &stack_size);
    return stack_size;
}

/* Takes an encoding string and an argument index.
 * Returns a pointer to the first char of the specified argument in the string
 * and indirectly returns that argument's encoded offset as an int.
 */
char * encoding_findArgument(const char *typedesc, int arg_idx, int *offset)
{
    unsigned nargs = 0;
    int self_offset = 0;
    
    // Move past return type and stack size
    char * desc_p = encoding_selfArgument(typedesc);
    
    // Now, we have the arguments - position typedesc to the appropriate argument
    while (*desc_p && nargs != arg_idx)
    {
        
        if (nargs == 0)
        {
            desc_p = arg_getOffset(desc_p, &self_offset);
            
        }
        else
        {
            desc_p = arg_skipArg(desc_p);
        }
        
        nargs += 1;
    }
    
    if (*desc_p)
    {
        int arg_offset;
        if (arg_idx == 0)
        {
            *offset = self_offset;
        }
        else
        {
            char * ignored; 
            ignored = arg_getOffset(desc_p, &arg_offset);
            
            *offset = arg_offset - self_offset;
        }
        
    }
    else
    {
        *offset	= 0;
    }
    
    return desc_p;
}

/* Takes an encoding string. Returns the number of arguments encoded. */
unsigned int encoding_numberOfArguments(const char *typedesc)
{
    unsigned int nargs = 0;
    // Move past return type and stack size
    char * desc_p = encoding_selfArgument(typedesc);
    while( *desc_p )
    {
        desc_p = arg_skipArg(desc_p);
        // Made it past an argument
        nargs += 1;
    }
    
    return nargs;
}

static char * SELenc = @encode(SEL);
//TODO: This doesn't account for negative offsets
char * encoding_createWithInsertedSEL(const char * original_encoding)
{
    NSUInteger alignedSELsize;
    NSGetSizeAndAlignment(@encode(SEL), NULL, &alignedSELsize);
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
    size_t len_stack_size = (size_t)(log10(stack_size) + 1);
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
    size_t len_offset = (size_t)(log10(offset) + 1);
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
    new_enc_p = NULL;
    
    return new_encoding;
}