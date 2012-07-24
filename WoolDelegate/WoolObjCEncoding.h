//
//  WoolObjCEncoding.h
//  EncodeStringMangling
//
//  Created by Joshua Caswell on 6/12/12.
//

//FIXME: Need to include Apple License information.

/* Takes a pointer to the beginning of an encoded argument and gets the offset 
 * portion of the encoding, returning a pointer to the following character. 
 * Returns the offset itself, as an int, indirectly.
 */
char * arg_getOffset(const char * argdesc, int * offset);

/* Takes a pointer to the first char of an argument encoding and returns
 * a pointer to the first char of the following argument's encoding.
 */
char * arg_skipArg(const char * argdesc);

/* Takes pointers to an argument encoding and a buffer, along with the
 * buffer's length. Copies the type portion of the argument encoding string 
 * into the buffer, returning a pointer to the new final character in buf.
 */
char * arg_getType(const char *argdesc, char *buf, size_t buf_size);

/* Skips the return type and stack length to return a pointer to the first
 * char of the first argument's (self) encoding.
 */
char * encoding_selfArgument(const char * typedesc);

/* Takes an encoding string and a buffer, along with the buffer's length, and
 * copies the encoded return type into the buffer, returning a pointer to the 
 * new final char in buf.
 */
char * encoding_getReturnType(const char *typedesc, char *buf, size_t buf_size);

/* Takes an encoding string and returns the stack size as an int. */
int encoding_stackSize(const char * typedesc);

/* Takes an encoding string and an argument index.
 * Returns a pointer to the first char of the specified argument in the string
 * and indirectly returns that argument's encoded offset as an int.
 */
char * encoding_findArgument(const char *typedesc, int arg_idx, int *offset);

/* Takes an encoding string. Returns the number of arguments encoded. */
unsigned int encoding_numberOfArguments(const char *typedesc);


/* Takes an encode string and inserts the @encoding for a SEL after the first
 * parameter (self), adjusting the stack length and offsets. */
char * encoding_createWithInsertedSEL(const char * original_encoding);

