   Documentation - The Zig Programming Language   :root{ --nav-width: 26em; --nav-margin-l: 1em; } body{ font-family: system-ui, -apple-system, Roboto, "Segoe UI", sans-serif; margin: 0; line-height: 1.5; } header { padding: 0 1em; } #contents { max-width: 60em; margin: auto; padding: 0 1em; } #navigation { padding: 0 1em; } table ul { list-style-type: none; padding: 0em; } table li { padding-bottom: 1em; line-height:1.2em; } table, th, td { border-collapse: collapse; border: 1px solid grey; } th, td { padding: 0.5em; } th\[scope=row\] { text-align: left; font-weight: normal; } @media screen and (min-width: 1025px) { header { margin-left: calc(var(--nav-width) + var(--nav-margin-l)); } header h1 { margin: auto; max-width: 30em; } #navigation { overflow: auto; width: var(--nav-width); height: 100vh; position: fixed; top:0; left:0; bottom:0; padding: unset; margin-left: var(--nav-margin-l); } #navigation nav ul { padding-left: 1em; } #contents-wrapper { margin-left: calc(var(--nav-width) + var(--nav-margin-l)); } } a:hover,a:focus { background: #fff2a8; } dt { font-weight: bold; } .sgr-1m { font-weight: bold; } .sgr-2m { color: #575757; } .sgr-31\_1m { color: #b40000; } .sgr-32\_1m { color: green; } .sgr-36\_1m { color: #005C7A; } .file { font-weight: bold; border: unset; } code { background: #f8f8f8; border: 1px dotted silver; padding-left: 0.3em; padding-right: 0.3em; } pre > code { display: block; overflow: auto; padding: 0.5em; border: 1px solid #eee; line-height: normal; } samp { background: #fafafa; } pre > samp { display: block; overflow: auto; padding: 0.5em; border: 1px solid #eee; line-height: normal; } kbd { font-weight: normal; } .table-wrapper { width: 100%; overflow-x: auto; } .tok-kw { color: #333; font-weight: bold; } .tok-str { color: #d14; } .tok-builtin { color: #005C7A; } .tok-comment { color: #545454; font-style: italic; } .tok-fn { color: #900; font-weight: bold; } .tok-null { color: #005C5C; } .tok-number { color: #005C5C; } .tok-type { color: #458; font-weight: bold; } figure { margin: auto 0; } figure pre { margin-top: 0; } figcaption { padding-left: 0.5em; font-size: small; border-top-left-radius: 5px; border-top-right-radius: 5px; } figcaption.zig-cap { background: #fcdba5; } figcaption.c-cap { background: #a8b9cc; color: #000; } figcaption.peg-cap { background: #fcdba5; } figcaption.javascript-cap { background: #365d95; color: #fff; } figcaption.shell-cap { background: #ccc; color: #000; } aside { border-left: 0.25em solid #f7a41d; padding: 0 1em 0 1em; } h1 a, h2 a, h3 a, h4 a, h5 a { text-decoration: none; color: #333; } a.hdr { visibility: hidden; } h1:hover > a.hdr, h2:hover > a.hdr, h3:hover > a.hdr, h4:hover > a.hdr, h5:hover > a.hdr { visibility: visible; } th pre code { background: none; } @media (prefers-color-scheme: dark) { body{ background:#121212; color: #ccc; } a { color: #88f; } a:hover,a:focus { color: #000; } table, th, td { border-color: grey; } .sgr-2m { color: grey; } .sgr-31\_1m { color: red; } .sgr-32\_1m { color: #00B800; } .sgr-36\_1m { color: #0086b3; } code { background: #222; border-color: #444; } pre > code { color: #ccc; background: #222; border: unset; } samp { background: #000; color: #ccc; } pre > samp { border: unset; } .tok-kw { color: #eee; } .tok-str { color: #2e5; } .tok-builtin { color: #ff894c; } .tok-comment { color: #aa7; } .tok-fn { color: #B1A0F8; } .tok-null { color: #ff8080; } .tok-number { color: #ff8080; } .tok-type { color: #68f; } h1 a, h2 a, h3 a, h4 a, h5 a { color: #aaa; } figcaption.zig-cap { background-color: #b27306; color: #000; } figcaption.peg-cap { background-color: #b27306; color: #000; } figcaption.shell-cap { background: #2a2a2a; color: #fff; } }

Zig Language Reference
======================

Zig Version
-----------

[0.1.1](https://ziglang.org/documentation/0.1.1/) | [0.2.0](https://ziglang.org/documentation/0.2.0/) | [0.3.0](https://ziglang.org/documentation/0.3.0/) | [0.4.0](https://ziglang.org/documentation/0.4.0/) | [0.5.0](https://ziglang.org/documentation/0.5.0/) | [0.6.0](https://ziglang.org/documentation/0.6.0/) | [0.7.1](https://ziglang.org/documentation/0.7.1/) | [0.8.1](https://ziglang.org/documentation/0.8.1/) | [0.9.1](https://ziglang.org/documentation/0.9.1/) | [0.10.1](https://ziglang.org/documentation/0.10.1/) | [0.11.0](https://ziglang.org/documentation/0.11.0/) | [0.12.0](https://ziglang.org/documentation/0.12.0/) | [0.13.0](https://ziglang.org/documentation/0.13.0/) | [0.14.1](https://ziglang.org/documentation/0.14.1/) | [0.15.2](https://ziglang.org/documentation/0.15.2/) | master

Table of Contents
-----------------

{#nav#}

{#header\_open|Introduction#}

[Zig](https://ziglang.org) is a general-purpose programming language and toolchain for maintaining **robust**, **optimal**, and **reusable** software.

Robust

Behavior is correct even for edge cases such as out of memory.

Optimal

Write programs the best way they can behave and perform.

Reusable

The same code works in many environments which have different constraints.

Maintainable

Precisely communicate intent to the compiler and other programmers. The language imposes a low overhead to reading code and is resilient to changing requirements and environments.

Often the most efficient way to learn something new is to see examples, so this documentation shows how to use each of Zig's features. It is all on one page so you can search with your browser's search tool.

The code samples in this document are compiled and tested as part of the main test suite of Zig.

This HTML document depends on no external files, so you can use it offline.

{#header\_close#} {#header\_open|Zig Standard Library#}

The [Zig Standard Library](https://ziglang.org/documentation/master/std/) has its own documentation.

Zig's Standard Library contains commonly used algorithms, data structures, and definitions to help you build programs or libraries. You will see many examples of Zig's Standard Library used in this documentation. To learn more about the Zig Standard Library, visit the link above.

Alternatively, the Zig Standard Library documentation is provided with each Zig distribution. It can be rendered via a local webserver with:

{#shell\_samp#}zig std{#end\_shell\_samp#} {#header\_close#} {#header\_open|Hello World#} {#code|hello.zig#}

Most of the time, it is more appropriate to write to stderr rather than stdout, and whether or not the message is successfully written to the stream is irrelevant. Also, formatted printing often comes in handy. For this common case, there is a simpler API:

{#code|hello\_again.zig#}

In this case, the {#syntax#}!{#endsyntax#} may be omitted from the return type of `main` because no errors are returned from the function.

{#see\_also|Values|Tuples|@import|Errors|Entry Point|Source Encoding|try#} {#header\_close#} {#header\_open|Comments#}

Zig supports 3 types of comments. Normal comments are ignored, but doc comments and top-level doc comments are used by the compiler to generate the package documentation.

The generated documentation is still experimental, and can be produced with:

{#shell\_samp#}zig test -femit-docs main.zig{#end\_shell\_samp#} {#code|comments.zig#}

There are no multiline comments in Zig (e.g. like `/* */` comments in C). This allows Zig to have the property that each line of code can be tokenized out of context.

{#header\_open|Doc Comments#}

A doc comment is one that begins with exactly three slashes (i.e. {#syntax#}///{#endsyntax#} but not {#syntax#}////{#endsyntax#}); multiple doc comments in a row are merged together to form a multiline doc comment. The doc comment documents whatever immediately follows it.

{#code|doc\_comments.zig#}

Doc comments are only allowed in certain places; it is a compile error to have a doc comment in an unexpected place, such as in the middle of an expression, or just before a non-doc comment.

{#code|invalid\_doc-comment.zig#} {#code|unattached\_doc-comment.zig#}

Doc comments can be interleaved with normal comments, which are ignored.

{#header\_close#} {#header\_open|Top-Level Doc Comments#}

A top-level doc comment is one that begins with two slashes and an exclamation point: {#syntax#}//!{#endsyntax#}; it documents the current module.

It is a compile error if a top-level doc comment is not placed at the start of a {#link|container|Containers#}, before any expressions.

{#code|tldoc\_comments.zig#} {#header\_close#} {#header\_close#} {#header\_open|Values#} {#code|values.zig#} {#header\_open|Primitive Types#}

Primitive Types

Type

C Equivalent

Description

{#syntax#}i8{#endsyntax#}

`int8_t`

signed 8-bit integer

{#syntax#}u8{#endsyntax#}

`uint8_t`

unsigned 8-bit integer

{#syntax#}i16{#endsyntax#}

`int16_t`

signed 16-bit integer

{#syntax#}u16{#endsyntax#}

`uint16_t`

unsigned 16-bit integer

{#syntax#}i32{#endsyntax#}

`int32_t`

signed 32-bit integer

{#syntax#}u32{#endsyntax#}

`uint32_t`

unsigned 32-bit integer

{#syntax#}i64{#endsyntax#}

`int64_t`

signed 64-bit integer

{#syntax#}u64{#endsyntax#}

`uint64_t`

unsigned 64-bit integer

{#syntax#}i128{#endsyntax#}

`__int128`

signed 128-bit integer

{#syntax#}u128{#endsyntax#}

`unsigned __int128`

unsigned 128-bit integer

{#syntax#}isize{#endsyntax#}

`intptr_t`

signed pointer sized integer

{#syntax#}usize{#endsyntax#}

`uintptr_t`, `size_t`

unsigned pointer sized integer. Also see [#5185](https://github.com/ziglang/zig/issues/5185)

{#syntax#}c\_char{#endsyntax#}

`char`

for ABI compatibility with C

{#syntax#}c\_short{#endsyntax#}

`short`

for ABI compatibility with C

{#syntax#}c\_ushort{#endsyntax#}

`unsigned short`

for ABI compatibility with C

{#syntax#}c\_int{#endsyntax#}

`int`

for ABI compatibility with C

{#syntax#}c\_uint{#endsyntax#}

`unsigned int`

for ABI compatibility with C

{#syntax#}c\_long{#endsyntax#}

`long`

for ABI compatibility with C

{#syntax#}c\_ulong{#endsyntax#}

`unsigned long`

for ABI compatibility with C

{#syntax#}c\_longlong{#endsyntax#}

`long long`

for ABI compatibility with C

{#syntax#}c\_ulonglong{#endsyntax#}

`unsigned long long`

for ABI compatibility with C

{#syntax#}c\_longdouble{#endsyntax#}

`long double`

for ABI compatibility with C

{#syntax#}f16{#endsyntax#}

`_Float16`

16-bit floating point (10-bit mantissa) IEEE-754-2008 binary16

{#syntax#}f32{#endsyntax#}

`float`

32-bit floating point (23-bit mantissa) IEEE-754-2008 binary32

{#syntax#}f64{#endsyntax#}

`double`

64-bit floating point (52-bit mantissa) IEEE-754-2008 binary64

{#syntax#}f80{#endsyntax#}

`long double`

80-bit floating point (64-bit mantissa) IEEE-754-2008 80-bit extended precision

{#syntax#}f128{#endsyntax#}

`_Float128`

128-bit floating point (112-bit mantissa) IEEE-754-2008 binary128

{#syntax#}bool{#endsyntax#}

`bool`

{#syntax#}true{#endsyntax#} or {#syntax#}false{#endsyntax#}

{#syntax#}anyopaque{#endsyntax#}

`void`

Used for type-erased pointers.

{#syntax#}void{#endsyntax#}

(none)

Always the value {#syntax#}void{}{#endsyntax#}

{#syntax#}noreturn{#endsyntax#}

(none)

the type of {#syntax#}break{#endsyntax#}, {#syntax#}continue{#endsyntax#}, {#syntax#}return{#endsyntax#}, {#syntax#}unreachable{#endsyntax#}, and {#syntax#}while (true) {}{#endsyntax#}

{#syntax#}type{#endsyntax#}

(none)

the type of types

{#syntax#}anyerror{#endsyntax#}

(none)

an error code

{#syntax#}comptime\_int{#endsyntax#}

(none)

Only allowed for {#link|comptime#}-known values. The type of integer literals.

{#syntax#}comptime\_float{#endsyntax#}

(none)

Only allowed for {#link|comptime#}-known values. The type of float literals.

In addition to the integer types above, arbitrary bit-width integers can be referenced by using an identifier of `i` or `u` followed by digits. For example, the identifier {#syntax#}i7{#endsyntax#} refers to a signed 7-bit integer. The maximum allowed bit-width of an integer type is {#syntax#}65535{#endsyntax#}.

{#see\_also|Integers|Floats|void|Errors|@Int#} {#header\_close#} {#header\_open|Primitive Values#}

Primitive Values

Name

Description

{#syntax#}true{#endsyntax#} and {#syntax#}false{#endsyntax#}

{#syntax#}bool{#endsyntax#} values

{#syntax#}null{#endsyntax#}

used to set an optional type to {#syntax#}null{#endsyntax#}

{#syntax#}undefined{#endsyntax#}

used to leave a value unspecified

{#see\_also|Optionals|undefined#} {#header\_close#} {#header\_open|String Literals and Unicode Code Point Literals#}

String literals are constant single-item {#link|Pointers#} to null-terminated byte arrays. The type of string literals encodes both the length, and the fact that they are null-terminated, and thus they can be {#link|coerced|Type Coercion#} to both {#link|Slices#} and {#link|Null-Terminated Pointers|Sentinel-Terminated Pointers#}. Dereferencing string literals converts them to {#link|Arrays#}.

Because Zig source code is {#link|UTF-8 encoded|Source Encoding#}, any non-ASCII bytes appearing within a string literal in source code carry their UTF-8 meaning into the content of the string in the Zig program; the bytes are not modified by the compiler. It is possible to embed non-UTF-8 bytes into a string literal using `\xNN` notation.

Indexing into a string containing non-ASCII bytes returns individual bytes, whether valid UTF-8 or not.

Unicode code point literals have type {#syntax#}comptime\_int{#endsyntax#}, the same as {#link|Integer Literals#}. All {#link|Escape Sequences#} are valid in both string literals and Unicode code point literals.

{#code|string\_literals.zig#} {#see\_also|Arrays|Source Encoding#} {#header\_open|Escape Sequences#}

Escape Sequences

Escape Sequence

Name

`\n`

Newline

`\r`

Carriage Return

`\t`

Tab

`\\`

Backslash

`\'`

Single Quote

`\"`

Double Quote

`\xNN`

hexadecimal 8-bit byte value (2 digits)

`\u{NNNNNN}`

hexadecimal Unicode scalar value UTF-8 encoded (1 or more digits)

Note that the maximum valid Unicode scalar value is {#syntax#}0x10ffff{#endsyntax#}.

{#header\_close#} {#header\_open|Multiline String Literals#}

Multiline string literals have no escapes and can span across multiple lines. To start a multiline string literal, use the {#syntax#}\\\\{#endsyntax#} token. Just like a comment, the string literal goes until the end of the line. The end of the line is not included in the string literal. However, if the next line begins with {#syntax#}\\\\{#endsyntax#} then a newline is appended and the string literal continues.

{#code|multiline\_string\_literals.zig#} {#see\_also|@embedFile#} {#header\_close#} {#header\_close#} {#header\_open|Assignment#}

Use the {#syntax#}const{#endsyntax#} keyword to assign a value to an identifier:

{#code|constant\_identifier\_cannot\_change.zig#}

{#syntax#}const{#endsyntax#} applies to all of the bytes that the identifier immediately addresses. {#link|Pointers#} have their own const-ness.

If you need a variable that you can modify, use the {#syntax#}var{#endsyntax#} keyword:

{#code|mutable\_var.zig#}

Variables must be initialized:

{#code|var\_must\_be\_initialized.zig#} {#header\_open|undefined#}

Use {#syntax#}undefined{#endsyntax#} to leave variables uninitialized:

{#code|assign\_undefined.zig#}

{#syntax#}undefined{#endsyntax#} can be {#link|coerced|Type Coercion#} to any type. Once this happens, it is no longer possible to detect that the value is {#syntax#}undefined{#endsyntax#}. {#syntax#}undefined{#endsyntax#} means the value could be anything, even something that is nonsense according to the type. Translated into English, {#syntax#}undefined{#endsyntax#} means "Not a meaningful value. Using this value would be a bug. The value will be unused, or overwritten before being used."

In {#link|Debug#} and {#link|ReleaseSafe#} mode, Zig writes {#syntax#}0xaa{#endsyntax#} bytes to undefined memory. This is to catch bugs early, and to help detect use of undefined memory in a debugger. However, this behavior is only an implementation feature, not a language semantic, so it is not guaranteed to be observable to code.

{#header\_close#} {#header\_open|Destructuring#}

A destructuring assignment can separate elements of indexable aggregate types ({#link|Tuples#}, {#link|Arrays#}, {#link|Vectors#}):

{#code|destructuring\_to\_existing.zig#}

A destructuring expression may only appear within a block (i.e. not at container scope). The left hand side of the assignment must consist of a comma separated list, each element of which may be either an lvalue (for instance, an existing \`var\`) or a variable declaration:

{#code|destructuring\_mixed.zig#}

A destructure may be prefixed with the {#syntax#}comptime{#endsyntax#} keyword, in which case the entire destructure expression is evaluated at {#link|comptime#}. All {#syntax#}var{#endsyntax#}s declared would be {#syntax#}comptime var{#endsyntax#}s and all expressions (both result locations and the assignee expression) are evaluated at {#link|comptime#}.

{#see\_also|Destructuring Tuples|Destructuring Arrays|Destructuring Vectors#} {#header\_close#} {#header\_close#} {#header\_close#} {#header\_open|Zig Test#}

Code written within one or more {#syntax#}test{#endsyntax#} declarations can be used to ensure behavior meets expectations:

{#code|testing\_introduction.zig#}

The `testing_introduction.zig` code sample tests the {#link|function|Functions#} {#syntax#}addOne{#endsyntax#} to ensure that it returns {#syntax#}42{#endsyntax#} given the input {#syntax#}41{#endsyntax#}. From this test's perspective, the {#syntax#}addOne{#endsyntax#} function is said to be _code under test_.

zig test is a tool that creates and runs a test build. By default, it builds and runs an executable program using the _default test runner_ provided by the {#link|Zig Standard Library#} as its main entry point. During the build, {#syntax#}test{#endsyntax#} declarations found while {#link|resolving|File and Declaration Discovery#} the given Zig source file are included for the default test runner to run and report on.

This documentation discusses the features of the default test runner as provided by the Zig Standard Library. Its source code is located in `lib/compiler/test_runner.zig`.

The shell output shown above displays two lines after the zig test command. These lines are printed to standard error by the default test runner:

1/2 testing\_introduction.test.expect addOne adds one to 41...

Lines like this indicate which test, out of the total number of tests, is being run. In this case, 1/2 indicates that the first test, out of a total of two tests, is being run. Note that, when the test runner program's standard error is output to the terminal, these lines are cleared when a test succeeds.

2/2 testing\_introduction.decltest.addOne...

When the test name is an identifier, the default test runner uses the text decltest instead of test.

All 2 tests passed.

This line indicates the total number of tests that have passed.

{#header\_open|Test Declarations#}

Test declarations contain the {#link|keyword|Keyword Reference#} {#syntax#}test{#endsyntax#}, followed by an optional name written as a {#link|string literal|String Literals and Unicode Code Point Literals#} or an {#link|identifier|Identifiers#}, followed by a {#link|block|Blocks#} containing any valid Zig code that is allowed in a {#link|function|Functions#}.

Non-named test blocks always run during test builds and are exempt from {#link|Skip Tests#}.

Test declarations are similar to {#link|Functions#}: they have a return type and a block of code. The implicit return type of {#syntax#}test{#endsyntax#} is the {#link|Error Union Type#} {#syntax#}anyerror!void{#endsyntax#}, and it cannot be changed. When a Zig source file is not built using the zig test tool, the test declarations are omitted from the build.

Test declarations can be written in the same file, where code under test is written, or in a separate Zig source file. Since test declarations are top-level declarations, they are order-independent and can be written before or after the code under test.

{#see\_also|The Global Error Set|Grammar#} {#header\_open|Doctests#}

Test declarations named using an identifier are _doctests_. The identifier must refer to another declaration in scope. A doctest, like a {#link|doc comment|Doc Comments#}, serves as documentation for the associated declaration, and will appear in the generated documentation for the declaration.

An effective doctest should be self-contained and focused on the declaration being tested, answering questions a new user might have about its interface or intended usage, while avoiding unnecessary or confusing details. A doctest is not a substitute for a doc comment, but rather a supplement and companion providing a testable, code-driven example, verified by zig test.

{#header\_close#} {#header\_close#} {#header\_open|Test Failure#}

The default test runner checks for an {#link|error|Errors#} returned from a test. When a test returns an error, the test is considered a failure and its {#link|error return trace|Error Return Traces#} is output to standard error. The total number of failures will be reported after all tests have run.

{#code|testing\_failure.zig#} {#header\_close#} {#header\_open|Skip Tests#}

One way to skip tests is to filter them out by using the zig test command line parameter \--test-filter \[text\]. This makes the test build only include tests whose name contains the supplied filter text. Note that non-named tests are run even when using the \--test-filter \[text\] command line parameter.

To programmatically skip a test, make a {#syntax#}test{#endsyntax#} return the error {#syntax#}error.SkipZigTest{#endsyntax#} and the default test runner will consider the test as being skipped. The total number of skipped tests will be reported after all tests have run.

{#code|testing\_skip.zig#} {#header\_close#} {#header\_open|Report Memory Leaks#}

When code allocates {#link|Memory#} using the {#link|Zig Standard Library#}'s testing allocator, {#syntax#}std.testing.allocator{#endsyntax#}, the default test runner will report any leaks that are found from using the testing allocator:

{#code|testing\_detect\_leak.zig#} {#see\_also|defer|Memory#} {#header\_close#} {#header\_open|Detecting Test Build#}

Use the {#link|compile variable|Compile Variables#} {#syntax#}@import("builtin").is\_test{#endsyntax#} to detect a test build:

{#code|testing\_detect\_test.zig#} {#header\_close#} {#header\_open|Test Output and Logging#}

The default test runner and the Zig Standard Library's testing namespace output messages to standard error.

{#header\_close#} {#header\_open|The Testing Namespace#}

The Zig Standard Library's `testing` namespace contains useful functions to help you create tests. In addition to the `expect` function, this document uses a couple of more functions as exemplified here:

{#code|testing\_namespace.zig#}

The Zig Standard Library also contains functions to compare {#link|Slices#}, strings, and more. See the rest of the {#syntax#}std.testing{#endsyntax#} namespace in the {#link|Zig Standard Library#} for more available functions.

{#header\_close#} {#header\_open|Test Tool Documentation#}

zig test has a few command line parameters which affect the compilation. See zig test --help for a full list.

{#header\_close#} {#header\_close#} {#header\_open|Variables#}

A variable is a unit of {#link|Memory#} storage.

It is generally preferable to use {#syntax#}const{#endsyntax#} rather than {#syntax#}var{#endsyntax#} when declaring a variable. This causes less work for both humans and computers to do when reading code, and creates more optimization opportunities.

The {#syntax#}extern{#endsyntax#} keyword or {#link|@extern#} builtin function can be used to link against a variable that is exported from another object. The {#syntax#}export{#endsyntax#} keyword or {#link|@export#} builtin function can be used to make a variable available to other objects at link time. In both cases, the type of the variable must be C ABI compatible.

{#see\_also|Exporting a C Library#} {#header\_open|Identifiers#}

Variable identifiers are never allowed to shadow identifiers from an outer scope.

Identifiers must start with an alphabetic character or underscore and may be followed by any number of alphanumeric characters or underscores. They must not overlap with any keywords. See {#link|Keyword Reference#}.

If a name that does not fit these requirements is needed, such as for linking with external libraries, the {#syntax#}@""{#endsyntax#} syntax may be used.

{#code|identifiers.zig#} {#header\_close#} {#header\_open|Container Level Variables#}

{#link|Container|Containers#} level variables have static lifetime and are order-independent and lazily analyzed. The initialization value of container level variables is implicitly {#link|comptime#}. If a container level variable is {#syntax#}const{#endsyntax#} then its value is {#syntax#}comptime{#endsyntax#}-known, otherwise it is runtime-known.

{#code|test\_container\_level\_variables.zig#}

Container level variables may be declared inside a {#link|struct#}, {#link|union#}, {#link|enum#}, or {#link|opaque#}:

{#code|test\_namespaced\_container\_level\_variable.zig#} {#header\_close#} {#header\_open|Static Local Variables#}

It is also possible to have local variables with static lifetime by using containers inside functions.

{#code|test\_static\_local\_variable.zig#} {#header\_close#} {#header\_open|Thread Local Variables#}

A variable may be specified to be a thread-local variable using the {#syntax#}threadlocal{#endsyntax#} keyword, which makes each thread work with a separate instance of the variable:

{#code|test\_thread\_local\_variables.zig#}

For {#link|Single Threaded Builds#}, all thread local variables are treated as regular {#link|Container Level Variables#}.

Thread local variables may not be {#syntax#}const{#endsyntax#}.

{#header\_close#} {#header\_open|Local Variables#}

Local variables occur inside {#link|Functions#}, {#link|comptime#} blocks, and {#link|@cImport#} blocks.

When a local variable is {#syntax#}const{#endsyntax#}, it means that after initialization, the variable's value will not change. If the initialization value of a {#syntax#}const{#endsyntax#} variable is {#link|comptime#}-known, then the variable is also {#syntax#}comptime{#endsyntax#}-known.

A local variable may be qualified with the {#syntax#}comptime{#endsyntax#} keyword. This causes the variable's value to be {#syntax#}comptime{#endsyntax#}-known, and all loads and stores of the variable to happen during semantic analysis of the program, rather than at runtime. All variables declared in a {#syntax#}comptime{#endsyntax#} expression are implicitly {#syntax#}comptime{#endsyntax#} variables.

{#code|test\_comptime\_variables.zig#} {#header\_close#} {#header\_close#} {#header\_open|Integers#} {#header\_open|Integer Literals#} {#code|integer\_literals.zig#} {#header\_close#} {#header\_open|Runtime Integer Values#}

Integer literals have no size limitation, and if any Illegal Behavior occurs, the compiler catches it.

However, once an integer value is no longer known at compile-time, it must have a known size, and is vulnerable to safety-checked {#link|Illegal Behavior#}.

{#code|runtime\_vs\_comptime.zig#}

In this function, values {#syntax#}a{#endsyntax#} and {#syntax#}b{#endsyntax#} are known only at runtime, and thus this division operation is vulnerable to both {#link|Integer Overflow#} and {#link|Division by Zero#}.

Operators such as {#syntax#}+{#endsyntax#} and {#syntax#}-{#endsyntax#} cause {#link|Illegal Behavior#} on integer overflow. Alternative operators are provided for wrapping and saturating arithmetic on all targets. {#syntax#}+%{#endsyntax#} and {#syntax#}-%{#endsyntax#} perform wrapping arithmetic while {#syntax#}+|{#endsyntax#} and {#syntax#}-|{#endsyntax#} perform saturating arithmetic.

Zig supports arbitrary bit-width integers, referenced by using an identifier of `i` or `u` followed by digits. For example, the identifier {#syntax#}i7{#endsyntax#} refers to a signed 7-bit integer. The maximum allowed bit-width of an integer type is {#syntax#}65535{#endsyntax#}. For signed integer types, Zig uses a [two's complement](https://en.wikipedia.org/wiki/Two's_complement) representation.

{#see\_also|Wrapping Operations#} {#header\_close#} {#header\_close#} {#header\_open|Floats#}

Zig has the following floating point types:

*   {#syntax#}f16{#endsyntax#} - IEEE-754-2008 binary16
*   {#syntax#}f32{#endsyntax#} - IEEE-754-2008 binary32
*   {#syntax#}f64{#endsyntax#} - IEEE-754-2008 binary64
*   {#syntax#}f80{#endsyntax#} - IEEE-754-2008 80-bit extended precision
*   {#syntax#}f128{#endsyntax#} - IEEE-754-2008 binary128
*   {#syntax#}c\_longdouble{#endsyntax#} - matches `long double` for the target C ABI

{#header\_open|Float Literals#}

Float literals have type {#syntax#}comptime\_float{#endsyntax#} which is guaranteed to have the same precision and operations of the largest other floating point type, which is {#syntax#}f128{#endsyntax#}.

Float literals {#link|coerce|Type Coercion#} to any floating point type, and to any {#link|integer|Integers#} type when there is no fractional component.

{#code|float\_literals.zig#}

There is no syntax for NaN, infinity, or negative infinity. For these special values, one must use the standard library:

{#code|float\_special\_values.zig#} {#header\_close#} {#header\_open|Floating Point Operations#}

By default floating point operations use {#syntax#}Strict{#endsyntax#} mode, but you can switch to {#syntax#}Optimized{#endsyntax#} mode on a per-block basis:

{#code|float\_mode\_obj.zig#}

For this test we have to separate code into two object files - otherwise the optimizer figures out all the values at compile-time, which operates in strict mode.

{#code|float\_mode\_exe.zig#} {#see\_also|@setFloatMode|Division by Zero#} {#header\_close#} {#header\_close#} {#header\_open|Operators#}

There is no operator overloading. When you see an operator in Zig, you know that it is doing something from this table, and nothing else.

{#header\_open|Table of Operators#}

Name

Syntax

Types

Remarks

Example

Addition

{#syntax#}a + b
a += b{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}

*   Can cause {#link|overflow|Default Operations#} for integers.
*   Invokes {#link|Peer Type Resolution#} for the operands.
*   See also {#link|@addWithOverflow#}.

{#syntax#}2 + 5 == 7{#endsyntax#}

Wrapping Addition

{#syntax#}a +% b
a +%= b{#endsyntax#}

*   {#link|Integers#}

*   Twos-complement wrapping behavior.
*   Invokes {#link|Peer Type Resolution#} for the operands.
*   See also {#link|@addWithOverflow#}.

{#syntax#}@as(u32, 0xffffffff) +% 1 == 0{#endsyntax#}

Saturating Addition

{#syntax#}a +| b
a +|= b{#endsyntax#}

*   {#link|Integers#}

*   Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}@as(u8, 255) +| 1 == @as(u8, 255){#endsyntax#}

Subtraction

{#syntax#}a - b
a -= b{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}

*   Can cause {#link|overflow|Default Operations#} for integers.
*   Invokes {#link|Peer Type Resolution#} for the operands.
*   See also {#link|@subWithOverflow#}.

{#syntax#}2 - 5 == -3{#endsyntax#}

Wrapping Subtraction

{#syntax#}a -% b
a -%= b{#endsyntax#}

*   {#link|Integers#}

*   Twos-complement wrapping behavior.
*   Invokes {#link|Peer Type Resolution#} for the operands.
*   See also {#link|@subWithOverflow#}.

{#syntax#}@as(u8, 0) -% 1 == 255{#endsyntax#}

Saturating Subtraction

{#syntax#}a -| b
a -|= b{#endsyntax#}

*   {#link|Integers#}

*   Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}@as(u32, 0) -| 1 == 0{#endsyntax#}

Negation

{#syntax#}-a{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}

*   Can cause {#link|overflow|Default Operations#} for integers.

{#syntax#}-1 == 0 - 1{#endsyntax#}

Wrapping Negation

{#syntax#}-%a{#endsyntax#}

*   {#link|Integers#}

*   Twos-complement wrapping behavior.

{#syntax#}-%@as(i8, -128) == -128{#endsyntax#}

Multiplication

{#syntax#}a \* b
a \*= b{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}

*   Can cause {#link|overflow|Default Operations#} for integers.
*   Invokes {#link|Peer Type Resolution#} for the operands.
*   See also {#link|@mulWithOverflow#}.

{#syntax#}2 \* 5 == 10{#endsyntax#}

Wrapping Multiplication

{#syntax#}a \*% b
a \*%= b{#endsyntax#}

*   {#link|Integers#}

*   Twos-complement wrapping behavior.
*   Invokes {#link|Peer Type Resolution#} for the operands.
*   See also {#link|@mulWithOverflow#}.

{#syntax#}@as(u8, 200) \*% 2 == 144{#endsyntax#}

Saturating Multiplication

{#syntax#}a \*| b
a \*|= b{#endsyntax#}

*   {#link|Integers#}

*   Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}@as(u8, 200) \*| 2 == 255{#endsyntax#}

Division

{#syntax#}a / b
a /= b{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}

*   Can cause {#link|overflow|Default Operations#} for integers.
*   Can cause {#link|Division by Zero#} for integers.
*   Can cause {#link|Division by Zero#} for floats in {#link|FloatMode.Optimized Mode|Floating Point Operations#}.
*   Signed integer operands must be comptime-known and positive. In other cases, use {#link|@divTrunc#}, {#link|@divFloor#}, or {#link|@divExact#} instead.
*   Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}10 / 5 == 2{#endsyntax#}

Remainder Division

{#syntax#}a % b
a %= b{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}

*   Can cause {#link|Division by Zero#} for integers.
*   Can cause {#link|Division by Zero#} for floats in {#link|FloatMode.Optimized Mode|Floating Point Operations#}.
*   Signed or floating-point operands must be comptime-known and positive. In other cases, use {#link|@rem#} or {#link|@mod#} instead.
*   Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}10 % 3 == 1{#endsyntax#}

Bit Shift Left

{#syntax#}a << b
a <<= b{#endsyntax#}

*   {#link|Integers#}

*   Moves all bits to the left, inserting new zeroes at the least-significant bit.
*   {#syntax#}b{#endsyntax#} must be {#link|comptime-known|comptime#} or have a type with log2 number of bits as {#syntax#}a{#endsyntax#}.
*   See also {#link|@shlExact#}.
*   See also {#link|@shlWithOverflow#}.

{#syntax#}0b1 << 8 == 0b100000000{#endsyntax#}

Saturating Bit Shift Left

{#syntax#}a <<| b
a <<|= b{#endsyntax#}

*   {#link|Integers#}

*   See also {#link|@shlExact#}.
*   See also {#link|@shlWithOverflow#}.

{#syntax#}@as(u8, 1) <<| 8 == 255{#endsyntax#}

Bit Shift Right

{#syntax#}a >> b
a >>= b{#endsyntax#}

*   {#link|Integers#}

*   Moves all bits to the right, inserting zeroes at the most-significant bit.
*   {#syntax#}b{#endsyntax#} must be {#link|comptime-known|comptime#} or have a type with log2 number of bits as {#syntax#}a{#endsyntax#}.
*   See also {#link|@shrExact#}.

{#syntax#}0b1010 >> 1 == 0b101{#endsyntax#}

Bitwise And

{#syntax#}a & b
a &= b{#endsyntax#}

*   {#link|Integers#}

*   Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}0b011 & 0b101 == 0b001{#endsyntax#}

Bitwise Or

{#syntax#}a | b
a |= b{#endsyntax#}

*   {#link|Integers#}

*   Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}0b010 | 0b100 == 0b110{#endsyntax#}

Bitwise Xor

{#syntax#}a ^ b
a ^= b{#endsyntax#}

*   {#link|Integers#}

*   Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}0b011 ^ 0b101 == 0b110{#endsyntax#}

Bitwise Not

{#syntax#}~a{#endsyntax#}

*   {#link|Integers#}

{#syntax#}~@as(u8, 0b10101111) == 0b01010000{#endsyntax#}

Defaulting Optional Unwrap

{#syntax#}a orelse b{#endsyntax#}

*   {#link|Optionals#}

If {#syntax#}a{#endsyntax#} is {#syntax#}null{#endsyntax#}, returns {#syntax#}b{#endsyntax#} ("default value"), otherwise returns the unwrapped value of {#syntax#}a{#endsyntax#}. Note that {#syntax#}b{#endsyntax#} may be a value of type {#link|noreturn#}.

{#syntax#}const value: ?u32 = null;
const unwrapped = value orelse 1234;
unwrapped == 1234{#endsyntax#}

Optional Unwrap

{#syntax#}a.?{#endsyntax#}

*   {#link|Optionals#}

Equivalent to:

{#syntax#}a orelse unreachable{#endsyntax#}

{#syntax#}const value: ?u32 = 5678;
value.? == 5678{#endsyntax#}

Defaulting Error Unwrap

{#syntax#}a catch b
a catch |err| b{#endsyntax#}

*   {#link|Error Unions|Errors#}

If {#syntax#}a{#endsyntax#} is an {#syntax#}error{#endsyntax#}, returns {#syntax#}b{#endsyntax#} ("default value"), otherwise returns the unwrapped value of {#syntax#}a{#endsyntax#}. Note that {#syntax#}b{#endsyntax#} may be a value of type {#link|noreturn#}. {#syntax#}err{#endsyntax#} is the {#syntax#}error{#endsyntax#} and is in scope of the expression {#syntax#}b{#endsyntax#}.

{#syntax#}const value: anyerror!u32 = error.Broken;
const unwrapped = value catch 1234;
unwrapped == 1234{#endsyntax#}

Logical And

{#syntax#}a and b{#endsyntax#}

*   {#link|bool|Primitive Types#}

If {#syntax#}a{#endsyntax#} is {#syntax#}false{#endsyntax#}, returns {#syntax#}false{#endsyntax#} without evaluating {#syntax#}b{#endsyntax#}. Otherwise, returns {#syntax#}b{#endsyntax#}.

{#syntax#}(false and true) == false{#endsyntax#}

Logical Or

{#syntax#}a or b{#endsyntax#}

*   {#link|bool|Primitive Types#}

If {#syntax#}a{#endsyntax#} is {#syntax#}true{#endsyntax#}, returns {#syntax#}true{#endsyntax#} without evaluating {#syntax#}b{#endsyntax#}. Otherwise, returns {#syntax#}b{#endsyntax#}.

{#syntax#}(false or true) == true{#endsyntax#}

Boolean Not

{#syntax#}!a{#endsyntax#}

*   {#link|bool|Primitive Types#}

{#syntax#}!false == true{#endsyntax#}

Equality

{#syntax#}a == b{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}
*   {#link|bool|Primitive Types#}
*   {#link|type|Primitive Types#}
*   {#link|packed struct#}

Returns {#syntax#}true{#endsyntax#} if a and b are equal, otherwise returns {#syntax#}false{#endsyntax#}. Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}(1 == 1) == true{#endsyntax#}

Null Check

{#syntax#}a == null{#endsyntax#}

*   {#link|Optionals#}

Returns {#syntax#}true{#endsyntax#} if a is {#syntax#}null{#endsyntax#}, otherwise returns {#syntax#}false{#endsyntax#}.

{#syntax#}const value: ?u32 = null;
(value == null) == true{#endsyntax#}

Inequality

{#syntax#}a != b{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}
*   {#link|bool|Primitive Types#}
*   {#link|type|Primitive Types#}

Returns {#syntax#}false{#endsyntax#} if a and b are equal, otherwise returns {#syntax#}true{#endsyntax#}. Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}(1 != 1) == false{#endsyntax#}

Non-Null Check

{#syntax#}a != null{#endsyntax#}

*   {#link|Optionals#}

Returns {#syntax#}false{#endsyntax#} if a is {#syntax#}null{#endsyntax#}, otherwise returns {#syntax#}true{#endsyntax#}.

{#syntax#}const value: ?u32 = null;
(value != null) == false{#endsyntax#}

Greater Than

{#syntax#}a > b{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}

Returns {#syntax#}true{#endsyntax#} if a is greater than b, otherwise returns {#syntax#}false{#endsyntax#}. Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}(2 > 1) == true{#endsyntax#}

Greater or Equal

{#syntax#}a >= b{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}

Returns {#syntax#}true{#endsyntax#} if a is greater than or equal to b, otherwise returns {#syntax#}false{#endsyntax#}. Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}(2 >= 1) == true{#endsyntax#}

Less Than

{#syntax#}a < b{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}

Returns {#syntax#}true{#endsyntax#} if a is less than b, otherwise returns {#syntax#}false{#endsyntax#}. Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}(1 < 2) == true{#endsyntax#}

Lesser or Equal

{#syntax#}a <= b{#endsyntax#}

*   {#link|Integers#}
*   {#link|Floats#}

Returns {#syntax#}true{#endsyntax#} if a is less than or equal to b, otherwise returns {#syntax#}false{#endsyntax#}. Invokes {#link|Peer Type Resolution#} for the operands.

{#syntax#}(1 <= 2) == true{#endsyntax#}

Array Concatenation

{#syntax#}a ++ b{#endsyntax#}

*   {#link|Arrays#}

*   Only available when the lengths of both {#syntax#}a{#endsyntax#} and {#syntax#}b{#endsyntax#} are {#link|compile-time known|comptime#}.

{#syntax#}const mem = @import("std").mem;
const array1 = \[\_\]u32{1,2};
const array2 = \[\_\]u32{3,4};
const together = array1 ++ array2;
mem.eql(u32, &together, &\[\_\]u32{1,2,3,4}){#endsyntax#}

Array Multiplication

{#syntax#}a \*\* b{#endsyntax#}

*   {#link|Arrays#}

*   Only available when the length of {#syntax#}a{#endsyntax#} and {#syntax#}b{#endsyntax#} are {#link|compile-time known|comptime#}.

{#syntax#}const mem = @import("std").mem;
const pattern = "ab" \*\* 3;
mem.eql(u8, pattern, "ababab"){#endsyntax#}

Pointer Dereference

{#syntax#}a.\*{#endsyntax#}

*   {#link|Pointers#}

Pointer dereference.

{#syntax#}const x: u32 = 1234;
const ptr = &x;
ptr.\* == 1234{#endsyntax#}

Address Of

{#syntax#}&a{#endsyntax#}

All types

{#syntax#}const x: u32 = 1234;
const ptr = &x;
ptr.\* == 1234{#endsyntax#}

Error Set Merge

{#syntax#}a || b{#endsyntax#}

*   {#link|Error Set Type#}

{#link|Merging Error Sets#}

{#syntax#}const A = error{One};
const B = error{Two};
(A || B) == error{One, Two}{#endsyntax#}

{#header\_close#} {#header\_open|Precedence#}

{#syntax#}x() x\[\] x.y x.\* x.?
a!b
x{}
!x -x -%x ~x &x ?x
\* / % \*\* \*% \*| ||
+ - ++ +% -% +| -|
<< >> <<|
& ^ | orelse catch
== != < > <= >=
and
or
= \*= \*%= \*|= /= %= += +%= +|= -= -%= -|= <<= <<|= >>= &= ^= |={#endsyntax#}

{#header\_close#} {#header\_close#} {#header\_open|Arrays#} {#code|test\_arrays.zig#} {#see\_also|for|Slices#} {#header\_open|Multidimensional Arrays#}

Multidimensional arrays can be created by nesting arrays:

{#code|test\_multidimensional\_arrays.zig#} {#header\_close#} {#header\_open|Sentinel-Terminated Arrays#}

The syntax {#syntax#}\[N:x\]T{#endsyntax#} describes an array which has a sentinel element of value {#syntax#}x{#endsyntax#} at the index corresponding to the length {#syntax#}N{#endsyntax#}.

{#code|test\_null\_terminated\_array.zig#} {#see\_also|Sentinel-Terminated Pointers|Sentinel-Terminated Slices#} {#header\_close#} {#header\_open|Destructuring Arrays#}

Arrays can be destructured:

{#code|destructuring\_arrays.zig#} {#see\_also|Destructuring|Destructuring Tuples|Destructuring Vectors#} {#header\_close#} {#header\_close#} {#header\_open|Vectors#}

A vector is a group of booleans, {#link|Integers#}, {#link|Floats#}, or {#link|Pointers#} which are operated on in parallel, using SIMD instructions if possible. Vector types are created with the builtin function {#link|@Vector#}.

Vectors generally support the same builtin operators as their underlying base types. The only exception to this is the keywords \`and\` and \`or\` on vectors of bools, since these operators affect control flow, which is not allowed for vectors. All other operations are performed element-wise, and return a vector of the same length as the input vectors. This includes:

*   Arithmetic ({#syntax#}+{#endsyntax#}, {#syntax#}-{#endsyntax#}, {#syntax#}/{#endsyntax#}, {#syntax#}\*{#endsyntax#}, {#syntax#}@divFloor{#endsyntax#}, {#syntax#}@sqrt{#endsyntax#}, {#syntax#}@ceil{#endsyntax#}, {#syntax#}@log{#endsyntax#}, etc.)
*   Bitwise operators ({#syntax#}>>{#endsyntax#}, {#syntax#}<<{#endsyntax#}, {#syntax#}&{#endsyntax#}, {#syntax#}|{#endsyntax#}, {#syntax#}~{#endsyntax#}, etc.)
*   Comparison operators ({#syntax#}<{#endsyntax#}, {#syntax#}>{#endsyntax#}, {#syntax#}=={#endsyntax#}, etc.)
*   Boolean not ({#syntax#}!{#endsyntax#})

It is prohibited to use a math operator on a mixture of scalars (individual numbers) and vectors. Zig provides the {#link|@splat#} builtin to easily convert from scalars to vectors, and it supports {#link|@reduce#} and array indexing syntax to convert from vectors to scalars. Vectors also support assignment to and from fixed-length arrays with comptime-known length.

For rearranging elements within and between vectors, Zig provides the {#link|@shuffle#} and {#link|@select#} functions.

Operations on vectors shorter than the target machine's native SIMD size will typically compile to single SIMD instructions, while vectors longer than the target machine's native SIMD size will compile to multiple SIMD instructions. If a given operation doesn't have SIMD support on the target architecture, the compiler will default to operating on each vector element one at a time. Zig supports any comptime-known vector length up to 2^32-1, although small powers of two (2-64) are most typical. Note that excessively long vector lengths (e.g. 2^20) may result in compiler crashes on current versions of Zig.

{#code|test\_vector.zig#}

TODO talk about C ABI interop  
TODO consider suggesting std.MultiArrayList

{#see\_also|@splat|@shuffle|@select|@reduce#} {#header\_open|Relationship with Arrays#}

Vectors and {#link|Arrays#} each have a well-defined **bit layout** and therefore support {#link|@bitCast#} between each other. {#link|Type Coercion#} implicitly peforms {#syntax#}@bitCast{#endsyntax#}.

Arrays have well-defined byte layout, but vectors do not, making {#link|@ptrCast#} between them {#link|Illegal Behavior#}.

{#header\_close#} {#header\_open|Destructuring Vectors#}

Vectors can be destructured:

{#code|destructuring\_vectors.zig#} {#see\_also|Destructuring|Destructuring Tuples|Destructuring Arrays#} {#header\_close#} {#header\_close#} {#header\_open|Pointers#}

Zig has two kinds of pointers: single-item and many-item.

*   {#syntax#}\*T{#endsyntax#} - single-item pointer to exactly one item.
    *   Supports deref syntax: {#syntax#}ptr.\*{#endsyntax#}
    *   Supports slice syntax: {#syntax#}ptr\[0..1\]{#endsyntax#}
    *   Supports pointer subtraction: {#syntax#}ptr - ptr{#endsyntax#}
*   {#syntax#}\[\*\]T{#endsyntax#} - many-item pointer to unknown number of items.
    *   Supports index syntax: {#syntax#}ptr\[i\]{#endsyntax#}
    *   Supports slice syntax: {#syntax#}ptr\[start..end\]{#endsyntax#} and {#syntax#}ptr\[start..\]{#endsyntax#}
    *   Supports pointer-integer arithmetic: {#syntax#}ptr + int{#endsyntax#}, {#syntax#}ptr - int{#endsyntax#}
    *   Supports pointer subtraction: {#syntax#}ptr - ptr{#endsyntax#}{#syntax#}T{#endsyntax#} must have a known size, which means that it cannot be {#syntax#}anyopaque{#endsyntax#} or any other {#link|opaque type|opaque#}.

These types are closely related to {#link|Arrays#} and {#link|Slices#}:

*   {#syntax#}\*\[N\]T{#endsyntax#} - pointer to N items, same as single-item pointer to an array.
    *   Supports index syntax: {#syntax#}array\_ptr\[i\]{#endsyntax#}
    *   Supports slice syntax: {#syntax#}array\_ptr\[start..end\]{#endsyntax#}
    *   Supports len property: {#syntax#}array\_ptr.len{#endsyntax#}
    *   Supports pointer subtraction: {#syntax#}array\_ptr - array\_ptr{#endsyntax#}

*   {#syntax#}\[\]T{#endsyntax#} - is a slice (a fat pointer, which contains a pointer of type {#syntax#}\[\*\]T{#endsyntax#} and a length).
    *   Supports index syntax: {#syntax#}slice\[i\]{#endsyntax#}
    *   Supports slice syntax: {#syntax#}slice\[start..end\]{#endsyntax#}
    *   Supports len property: {#syntax#}slice.len{#endsyntax#}

Use {#syntax#}&x{#endsyntax#} to obtain a single-item pointer:

{#code|test\_single\_item\_pointer.zig#}

Zig supports pointer arithmetic. It's better to assign the pointer to {#syntax#}\[\*\]T{#endsyntax#} and increment that variable. For example, directly incrementing the pointer from a slice will corrupt it.

{#code|test\_pointer\_arithmetic.zig#}

In Zig, we generally prefer {#link|Slices#} rather than {#link|Sentinel-Terminated Pointers#}. You can turn an array or pointer into a slice using slice syntax.

Slices have bounds checking and are therefore protected against this kind of Illegal Behavior. This is one reason we prefer slices to pointers.

{#code|test\_slice\_bounds.zig#}

Pointers work at compile-time too, as long as the code does not depend on an undefined memory layout:

{#code|test\_comptime\_pointers.zig#}

To convert an integer address into a pointer, use {#syntax#}@ptrFromInt{#endsyntax#}. To convert a pointer to an integer, use {#syntax#}@intFromPtr{#endsyntax#}:

{#code|test\_integer\_pointer\_conversion.zig#}

Zig is able to preserve memory addresses in comptime code, as long as the pointer is never dereferenced:

{#code|test\_comptime\_pointer\_conversion.zig#}

{#link|@ptrCast#} converts a pointer's element type to another. This creates a new pointer that can cause undetectable Illegal Behavior depending on the loads and stores that pass through it. Generally, other kinds of type conversions are preferable to {#syntax#}@ptrCast{#endsyntax#} if possible.

{#code|test\_pointer\_casting.zig#} {#see\_also|Optional Pointers|@ptrFromInt|@intFromPtr|C Pointers#} {#header\_open|volatile#}

Loads and stores are assumed to not have side effects. If a given load or store should have side effects, such as Memory Mapped Input/Output (MMIO), use {#syntax#}volatile{#endsyntax#}. In the following code, loads and stores with {#syntax#}mmio\_ptr{#endsyntax#} are guaranteed to all happen and in the same order as in source code:

{#code|test\_volatile.zig#}

Note that {#syntax#}volatile{#endsyntax#} is unrelated to concurrency and {#link|Atomics#}. If you see code that is using {#syntax#}volatile{#endsyntax#} for something other than Memory Mapped Input/Output, it is probably a bug.

{#header\_close#} {#header\_open|Alignment#}

Each type has an **alignment** - a number of bytes such that, when a value of the type is loaded from or stored to memory, the memory address must be evenly divisible by this number. You can use {#link|@alignOf#} to find out this value for any type.

Alignment depends on the CPU architecture, but is always a power of two, and less than {#syntax#}1 << 29{#endsyntax#}.

In Zig, a pointer type has an alignment value. If the value is equal to the alignment of the underlying type, it can be omitted from the type:

{#code|test\_variable\_alignment.zig#}

In the same way that a {#syntax#}\*i32{#endsyntax#} can be {#link|coerced|Type Coercion#} to a {#syntax#}\*const i32{#endsyntax#}, a pointer with a larger alignment can be implicitly cast to a pointer with a smaller alignment, but not vice versa.

You can specify alignment on variables and functions. If you do this, then pointers to them get the specified alignment:

{#code|test\_variable\_func\_alignment.zig#}

If you have a pointer or a slice that has a small alignment, but you know that it actually has a bigger alignment, use {#link|@alignCast#} to change the pointer into a more aligned pointer. This is a no-op at runtime, but inserts a {#link|safety check|Incorrect Pointer Alignment#}:

{#code|test\_incorrect\_pointer\_alignment.zig#} {#header\_close#} {#header\_open|allowzero#}

This pointer attribute allows a pointer to have address zero. This is only ever needed on the freestanding OS target, where the address zero is mappable. If you want to represent null pointers, use {#link|Optional Pointers#} instead. {#link|Optional Pointers#} with {#syntax#}allowzero{#endsyntax#} are not the same size as pointers. In this code example, if the pointer did not have the {#syntax#}allowzero{#endsyntax#} attribute, this would be a {#link|Pointer Cast Invalid Null#} panic:

{#code|test\_allowzero.zig#} {#header\_close#} {#header\_open|Sentinel-Terminated Pointers#}

The syntax {#syntax#}\[\*:x\]T{#endsyntax#} describes a pointer that has a length determined by a sentinel value. This provides protection against buffer overflow and overreads.

{#code|sentinel-terminated\_pointer.zig#} {#see\_also|Sentinel-Terminated Slices|Sentinel-Terminated Arrays#} {#header\_close#} {#header\_close#} {#header\_open|Slices#}

A slice is a pointer and a length. The difference between an array and a slice is that the array's length is part of the type and known at compile-time, whereas the slice's length is known at runtime. Both can be accessed with the {#syntax#}len{#endsyntax#} field.

{#code|test\_basic\_slices.zig#}

This is one reason we prefer slices to pointers.

{#code|test\_slices.zig#} {#see\_also|Pointers|for|Arrays#} {#header\_open|Sentinel-Terminated Slices#}

The syntax {#syntax#}\[:x\]T{#endsyntax#} is a slice which has a runtime-known length and also guarantees a sentinel value at the element indexed by the length. The type does not guarantee that there are no sentinel elements before that. Sentinel-terminated slices allow element access to the {#syntax#}len{#endsyntax#} index.

{#code|test\_null\_terminated\_slice.zig#}

Sentinel-terminated slices can also be created using a variation of the slice syntax {#syntax#}data\[start..end :x\]{#endsyntax#}, where {#syntax#}data{#endsyntax#} is a many-item pointer, array or slice and {#syntax#}x{#endsyntax#} is the sentinel value.

{#code|test\_null\_terminated\_slicing.zig#}

Sentinel-terminated slicing asserts that the element in the sentinel position of the backing data is actually the sentinel value. If this is not the case, safety-checked {#link|Illegal Behavior#} results.

{#code|test\_sentinel\_mismatch.zig#} {#see\_also|Sentinel-Terminated Pointers|Sentinel-Terminated Arrays#} {#header\_close#} {#header\_close#} {#header\_open|struct#} {#code|test\_structs.zig#} {#header\_open|Default Field Values#}

Each struct field may have an expression indicating the default field value. Such expressions are executed at {#link|comptime#}, and allow the field to be omitted in a struct literal expression:

{#code|struct\_default\_field\_values.zig#} {#header\_open|Faulty Default Field Values#}

Default field values are only appropriate when the data invariants of a struct cannot be violated by omitting that field from an initialization.

For example, here is an inappropriate use of default struct field initialization:

{#code|bad\_default\_value.zig#}

Above you can see the danger of ignoring this principle. The default field values caused the data invariant to be violated, causing illegal behavior.

To fix this, remove the default values from all the struct fields, and provide a named default value:

{#code|struct\_default\_value.zig#}

If a struct value requires a runtime-known value in order to be initialized without violating data invariants, then use an initialization method that accepts those runtime values, and populates the remaining fields.

{#header\_close#} {#header\_close#} {#header\_open|extern struct#}

An {#syntax#}extern struct{#endsyntax#} has in-memory layout matching the C ABI for the target.

If well-defined in-memory layout is not required, {#link|struct#} is a better choice because it places fewer restrictions on the compiler.

See {#link|packed struct#} for a struct that has the ABI of its backing integer, which can be useful for modeling flags.

{#see\_also|extern union|extern enum#} {#header\_close#} {#header\_open|packed struct#}

{#syntax#}packed{#endsyntax#} structs, like {#syntax#}enum{#endsyntax#}, are based on the concept of interpreting integers differently. All packed structs have a **backing integer**, which is implicitly determined by the total bit count of fields, or explicitly specified. Packed structs have well-defined memory layout - exactly the same ABI as their backing integer.

Each field of a packed struct is interpreted as a logical sequence of bits, arranged from least to most significant. Allowed field types:

*   An {#link|integer|Integers#} field uses exactly as many bits as its bit width. For example, a {#syntax#}u5{#endsyntax#} will use 5 bits of the backing integer.
*   A {#link|bool|Primitive Types#} field uses exactly 1 bit.
*   An {#link|enum#} field uses exactly the bit width of its integer tag type.
*   A {#link|packed union#} field uses exactly the bit width of the union field with the largest bit width.
*   A {#syntax#}packed struct{#endsyntax#} field uses the bits of its backing integer.

This means that a {#syntax#}packed struct{#endsyntax#} can participate in a {#link|@bitCast#} or a {#link|@ptrCast#} to reinterpret memory. This even works at {#link|comptime#}:

{#code|test\_packed\_structs.zig#}

The backing integer can be inferred or explicitly provided. When inferred, it will be unsigned. When explicitly provided, its bit width will be enforced at compile time to exactly match the total bit width of the fields:

{#code|test\_missized\_packed\_struct.zig#}

Zig allows the address to be taken of a non-byte-aligned field:

{#code|test\_pointer\_to\_non-byte\_aligned\_field.zig#}

However, the pointer to a non-byte-aligned field has special properties and cannot be passed when a normal pointer is expected:

{#code|test\_misaligned\_pointer.zig#}

In this case, the function {#syntax#}bar{#endsyntax#} cannot be called because the pointer to the non-ABI-aligned field mentions the bit offset, but the function expects an ABI-aligned pointer.

Pointers to non-ABI-aligned fields share the same address as the other fields within their host integer:

{#code|test\_packed\_struct\_field\_address.zig#}

This can be observed with {#link|@bitOffsetOf#} and {#link|offsetOf#}:

{#code|test\_bitOffsetOf\_offsetOf.zig#}

Packed structs have the same alignment as their backing integer, however, overaligned pointers to packed structs can override this:

{#code|test\_overaligned\_packed\_struct.zig#}

It's also possible to set alignment of struct fields:

{#code|test\_aligned\_struct\_fields.zig#}

Equating packed structs results in a comparison of the backing integer, and only works for the {#syntax#}=={#endsyntax#} and {#syntax#}!={#endsyntax#} {#link|Operators#}.

{#code|test\_packed\_struct\_equality.zig#}

Field access and assignment can be understood as shorthand for bitshifts on the backing integer. These operations are not {#link|atomic|Atomics#}, so beware using field access syntax when combined with memory-mapped input-output (MMIO). Instead of field access on {#link|volatile#} {#link|Pointers#}, construct a fully-formed new value first, then write that value to the volatile pointer.

{#code|packed\_struct\_mmio.zig#} {#header\_close#} {#header\_open|Struct Naming#}

Since all structs are anonymous, Zig infers the type name based on a few rules.

*   If the struct is in the initialization expression of a variable, it gets named after that variable.
*   If the struct is in the {#syntax#}return{#endsyntax#} expression, it gets named after the function it is returning from, with the parameter values serialized.
*   Otherwise, the struct gets a name such as `(filename.funcname__struct_ID)`.
*   If the struct is declared inside another struct, it gets named after both the parent struct and the name inferred by the previous rules, separated by a dot.

{#code|struct\_name.zig#} {#header\_close#} {#header\_open|Anonymous Struct Literals#}

Zig allows omitting the struct type of a literal. When the result is {#link|coerced|Type Coercion#}, the struct literal will directly instantiate the {#link|result location|Result Location Semantics#}, with no copy:

{#code|test\_struct\_result.zig#}

The struct type can be inferred. Here the {#link|result location|Result Location Semantics#} does not include a type, and so Zig infers the type:

{#code|test\_anonymous\_struct.zig#} {#header\_close#} {#header\_open|Tuples#}

Anonymous structs can be created without specifying field names, and are referred to as "tuples". An empty tuple looks like `.{}` and can be seen in one of the {#link|Hello World examples|Hello World#}.

The fields are implicitly named using numbers starting from 0. Because their names are integers, they cannot be accessed with {#syntax#}.{#endsyntax#} syntax without also wrapping them in {#syntax#}@""{#endsyntax#}. Names inside {#syntax#}@""{#endsyntax#} are always recognised as {#link|identifiers|Identifiers#}.

Like arrays, tuples have a .len field, can be indexed (provided the index is comptime-known) and work with the ++ and \*\* operators. They can also be iterated over with {#link|inline for#}.

{#code|test\_tuples.zig#} {#header\_open|Destructuring Tuples#}

Tuples can be {#link|destructured|Destructuring#}.

Tuple destructuring is helpful for returning multiple values from a block:

{#code|destructuring\_block.zig#}

Tuple destructuring is helpful for dealing with functions and built-ins that return multiple values as a tuple:

{#code|destructuring\_return\_value.zig#} {#see\_also|Destructuring|Destructuring Arrays|Destructuring Vectors#} {#header\_close#} {#header\_close#} {#see\_also|comptime|@fieldParentPtr#} {#header\_close#} {#header\_open|enum#} {#code|test\_enums.zig#} {#see\_also|@typeInfo|@tagName|@sizeOf#} {#header\_open|extern enum#}

By default, enums are not guaranteed to be compatible with the C ABI:

{#code|enum\_export\_error.zig#}

For a C-ABI-compatible enum, provide an explicit tag type to the enum:

{#code|enum\_export.zig#} {#header\_close#} {#header\_open|Enum Literals#}

Enum literals allow specifying the name of an enum field without specifying the enum type:

{#code|test\_enum\_literals.zig#} {#header\_close#} {#header\_open|Non-exhaustive enum#}

A non-exhaustive enum can be created by adding a trailing {#syntax#}\_{#endsyntax#} field. The enum must specify a tag type and cannot consume every enumeration value.

{#link|@enumFromInt#} on a non-exhaustive enum involves the safety semantics of {#link|@intCast#} to the integer tag type, but beyond that always results in a well-defined enum value.

A switch on a non-exhaustive enum can include a {#syntax#}\_{#endsyntax#} prong as an alternative to an {#syntax#}else{#endsyntax#} prong. With a {#syntax#}\_{#endsyntax#} prong the compiler errors if all the known tag names are not handled by the switch.

{#code|test\_switch\_non-exhaustive.zig#} {#header\_close#} {#header\_close#} {#header\_open|union#}

A bare {#syntax#}union{#endsyntax#} defines a set of possible types that a value can be as a list of fields. Only one field can be active at a time. The in-memory representation of bare unions is not guaranteed. Bare unions cannot be used to reinterpret memory. For that, use {#link|@ptrCast#}, or use an {#link|extern union#} or a {#link|packed union#} which have guaranteed in-memory layout. {#link|Accessing the non-active field|Wrong Union Field Access#} is safety-checked {#link|Illegal Behavior#}:

{#code|test\_wrong\_union\_access.zig#}

You can activate another field by assigning the entire union:

{#code|test\_simple\_union.zig#}

In order to use {#link|switch#} with a union, it must be a {#link|Tagged union#}.

To initialize a union when the tag is a {#link|comptime#}-known name, see {#link|@unionInit#}.

{#header\_open|Tagged union#}

Unions can be declared with an enum tag type. This turns the union into a _tagged_ union, which makes it eligible to use with {#link|switch#} expressions. Tagged unions coerce to their tag type: {#link|Type Coercion: Unions and Enums#}.

{#code|test\_tagged\_union.zig#}

In order to modify the payload of a tagged union in a switch expression, place a {#syntax#}\*{#endsyntax#} before the variable name to make it a pointer:

{#code|test\_switch\_modify\_tagged\_union.zig#}

Unions can be made to infer the enum tag type. Further, unions can have methods just like structs and enums.

{#code|test\_union\_method.zig#}

Unions with inferred enum tag types can also assign ordinal values to their inferred tag. This requires the tag to specify an explicit integer type. {#link|@intFromEnum#} can be used to access the ordinal value corresponding to the active field.

{#code|test\_tagged\_union\_with\_tag\_values.zig#}

{#link|@tagName#} can be used to return a {#link|comptime#} {#syntax#}\[:0\]const u8{#endsyntax#} value representing the field name:

{#code|test\_tagName.zig#} {#header\_close#} {#header\_open|extern union#}

An {#syntax#}extern union{#endsyntax#} has memory layout guaranteed to be compatible with the target C ABI.

{#see\_also|extern struct#} {#header\_close#} {#header\_open|packed union#}

A {#syntax#}packed union{#endsyntax#} has well-defined in-memory layout and is eligible to be in a {#link|packed struct#}.

All fields in a packed union must have the same {#link|@bitSizeOf#}.

{#header\_close#} {#header\_open|Anonymous Union Literals#}

{#link|Anonymous Struct Literals#} syntax can be used to initialize unions without specifying the type:

{#code|test\_anonymous\_union.zig#} {#header\_close#} {#header\_close#} {#header\_open|opaque#}

{#syntax#}opaque {}{#endsyntax#} declares a new type with an unknown (but non-zero) size and alignment. It can contain declarations the same as {#link|structs|struct#}, {#link|unions|union#}, and {#link|enums|enum#}.

This is typically used for type safety when interacting with C code that does not expose struct details. Example:

{#code|test\_opaque.zig#} {#header\_close#} {#header\_open|Blocks#}

Blocks are used to limit the scope of variable declarations:

{#code|test\_blocks.zig#}

Blocks are expressions. When labeled, {#syntax#}break{#endsyntax#} can be used to return a value from the block:

{#code|test\_labeled\_break.zig#}

Here, {#syntax#}blk{#endsyntax#} can be any name.

{#see\_also|Labeled while|Labeled for#} {#header\_open|Shadowing#}

{#link|Identifiers#} are never allowed to "hide" other identifiers by using the same name:

{#code|test\_shadowing.zig#}

Because of this, when you read Zig code you can always rely on an identifier to consistently mean the same thing within the scope it is defined. Note that you can, however, use the same name if the scopes are separate:

{#code|test\_scopes.zig#} {#header\_close#} {#header\_open|Empty Blocks#}

An empty block is equivalent to {#syntax#}void{}{#endsyntax#}:

{#code|test\_empty\_block.zig#} {#header\_close#} {#header\_close#} {#header\_open|switch#} {#code|test\_switch.zig#}

{#syntax#}switch{#endsyntax#} can be used to capture the field values of a {#link|Tagged union#}. Modifications to the field values can be done by placing a {#syntax#}\*{#endsyntax#} before the capture variable name, turning it into a pointer.

{#code|test\_switch\_tagged\_union.zig#} {#see\_also|comptime|enum|@compileError|Compile Variables#} {#header\_open|Exhaustive Switching#}

When a {#syntax#}switch{#endsyntax#} expression does not have an {#syntax#}else{#endsyntax#} clause, it must exhaustively list all the possible values. Failure to do so is a compile error:

{#code|test\_unhandled\_enumeration\_value.zig#} {#header\_close#} {#header\_open|Switching with Enum Literals#}

{#link|Enum Literals#} can be useful to use with {#syntax#}switch{#endsyntax#} to avoid repetitively specifying {#link|enum#} or {#link|union#} types:

{#code|test\_exhaustive\_switch.zig#} {#header\_close#} {#header\_open|Labeled switch#}

When a switch statement is labeled, it can be referenced from a {#syntax#}break{#endsyntax#} or {#syntax#}continue{#endsyntax#}. {#syntax#}break{#endsyntax#} will return a value from the {#syntax#} switch{#endsyntax#}.

A {#syntax#}continue{#endsyntax#} targeting a switch must have an operand. When executed, it will jump to the matching prong, as if the {#syntax#}switch{#endsyntax#} were executed again with the {#syntax#} continue{#endsyntax#}'s operand replacing the initial switch value.

{#code|test\_switch\_continue.zig#}

Semantically, this is equivalent to the following loop:

{#code|test\_switch\_continue\_equivalent.zig#}

This can improve clarity of (for example) state machines, where the syntax {#syntax#}continue :sw .next\_state{#endsyntax#} is unambiguous, explicit, and immediately understandable.

However, the motivating example is a switch on each element of an array, where using a single switch can improve clarity and performance:

{#code|test\_switch\_dispatch\_loop.zig#}

If the operand to {#syntax#}continue{#endsyntax#} is {#link|comptime#}-known, then it can be lowered to an unconditional branch to the relevant case. Such a branch is perfectly predicted, and hence typically very fast to execute.

If the operand is runtime-known, each {#syntax#}continue{#endsyntax#} can embed a conditional branch inline (ideally through a jump table), which allows a CPU to predict its target independently of any other prong. A loop-based lowering would force every branch through the same dispatch point, hindering branch prediction.

{#header\_close#} {#header\_open|Inline Switch Prongs#}

Switch prongs can be marked as {#syntax#}inline{#endsyntax#} to generate the prong's body for each possible value it could have, making the captured value {#link|comptime#}.

{#code|test\_inline\_switch.zig#}

The {#syntax#}inline{#endsyntax#} keyword may also be combined with ranges:

{#code|inline\_prong\_range.zig#}

{#syntax#}inline else{#endsyntax#} prongs can be used as a type safe alternative to {#syntax#}inline for{#endsyntax#} loops:

{#code|test\_inline\_else.zig#}

When using an inline prong switching on an union an additional capture can be used to obtain the union's enum tag value.

{#code|test\_inline\_switch\_union\_tag.zig#} {#see\_also|inline while|inline for#} {#header\_close#} {#header\_close#} {#header\_open|while#}

A while loop is used to repeatedly execute an expression until some condition is no longer true.

{#code|test\_while.zig#}

Use {#syntax#}break{#endsyntax#} to exit a while loop early.

{#code|test\_while\_break.zig#}

Use {#syntax#}continue{#endsyntax#} to jump back to the beginning of the loop.

{#code|test\_while\_continue.zig#}

While loops support a continue expression which is executed when the loop is continued. The {#syntax#}continue{#endsyntax#} keyword respects this expression.

{#code|test\_while\_continue\_expression.zig#}

While loops are expressions. The result of the expression is the result of the {#syntax#}else{#endsyntax#} clause of a while loop, which is executed when the condition of the while loop is tested as false.

{#syntax#}break{#endsyntax#}, like {#syntax#}return{#endsyntax#}, accepts a value parameter. This is the result of the {#syntax#}while{#endsyntax#} expression. When you {#syntax#}break{#endsyntax#} from a while loop, the {#syntax#}else{#endsyntax#} branch is not evaluated.

{#code|test\_while\_else.zig#} {#header\_open|Labeled while#}

When a {#syntax#}while{#endsyntax#} loop is labeled, it can be referenced from a {#syntax#}break{#endsyntax#} or {#syntax#}continue{#endsyntax#} from within a nested loop:

{#code|test\_while\_nested\_break.zig#} {#header\_close#} {#header\_open|while with Optionals#}

Just like {#link|if#} expressions, while loops can take an optional as the condition and capture the payload. When {#link|null#} is encountered the loop exits.

When the {#syntax#}|x|{#endsyntax#} syntax is present on a {#syntax#}while{#endsyntax#} expression, the while condition must have an {#link|Optional Type#}.

The {#syntax#}else{#endsyntax#} branch is allowed on optional iteration. In this case, it will be executed on the first null value encountered.

{#code|test\_while\_null\_capture.zig#} {#header\_close#} {#header\_open|while with Error Unions#}

Just like {#link|if#} expressions, while loops can take an error union as the condition and capture the payload or the error code. When the condition results in an error code the else branch is evaluated and the loop is finished.

When the {#syntax#}else |x|{#endsyntax#} syntax is present on a {#syntax#}while{#endsyntax#} expression, the while condition must have an {#link|Error Union Type#}.

{#code|test\_while\_error\_capture.zig#} {#header\_close#} {#header\_open|inline while#}

While loops can be inlined. This causes the loop to be unrolled, which allows the code to do some things which only work at compile time, such as use types as first class values.

{#code|test\_inline\_while.zig#}

It is recommended to use {#syntax#}inline{#endsyntax#} loops only for one of these reasons:

*   You need the loop to execute at {#link|comptime#} for the semantics to work.
*   You have a benchmark to prove that forcibly unrolling the loop in this way is measurably faster.

{#header\_close#} {#see\_also|if|Optionals|Errors|comptime|unreachable#} {#header\_close#} {#header\_open|for#} {#code|test\_for.zig#} {#header\_open|Labeled for#}

When a {#syntax#}for{#endsyntax#} loop is labeled, it can be referenced from a {#syntax#}break{#endsyntax#} or {#syntax#}continue{#endsyntax#} from within a nested loop:

{#code|test\_for\_nested\_break.zig#} {#header\_close#} {#header\_open|inline for#}

For loops can be inlined. This causes the loop to be unrolled, which allows the code to do some things which only work at compile time, such as use types as first class values. The capture value and iterator value of inlined for loops are compile-time known.

{#code|test\_inline\_for.zig#}

It is recommended to use {#syntax#}inline{#endsyntax#} loops only for one of these reasons:

*   You need the loop to execute at {#link|comptime#} for the semantics to work.
*   You have a benchmark to prove that forcibly unrolling the loop in this way is measurably faster.

{#header\_close#} {#see\_also|while|comptime|Arrays|Slices#} {#header\_close#} {#header\_open|if#} {#code|test\_if.zig#} {#header\_open|if with Optionals#} {#code|test\_if\_optionals.zig#} {#header\_close#} {#see\_also|Optionals|Errors#} {#header\_close#} {#header\_open|defer#}

Executes an expression unconditionally at scope exit.

{#code|test\_defer.zig#}

Defer expressions are evaluated in reverse order.

{#code|defer\_unwind.zig#}

Inside a defer expression the return statement is not allowed.

{#code|test\_invalid\_defer.zig#} {#see\_also|Errors#} {#header\_close#} {#header\_open|unreachable#}

In {#link|Debug#} and {#link|ReleaseSafe#} mode {#syntax#}unreachable{#endsyntax#} emits a call to {#syntax#}panic{#endsyntax#} with the message `reached unreachable code`.

In {#link|ReleaseFast#} and {#link|ReleaseSmall#} mode, the optimizer uses the assumption that {#syntax#}unreachable{#endsyntax#} code will never be hit to perform optimizations.

{#header\_open|Basics#} {#code|test\_unreachable.zig#}

In fact, this is how {#syntax#}std.debug.assert{#endsyntax#} is implemented:

{#code|test\_assertion\_failure.zig#} {#header\_close#} {#header\_open|At Compile-Time#} {#code|test\_comptime\_unreachable.zig#} {#see\_also|Zig Test|Build Mode|comptime#} {#header\_close#} {#header\_close#} {#header\_open|noreturn#}

{#syntax#}noreturn{#endsyntax#} is the type of:

*   {#syntax#}break{#endsyntax#}
*   {#syntax#}continue{#endsyntax#}
*   {#syntax#}return{#endsyntax#}
*   {#syntax#}unreachable{#endsyntax#}
*   {#syntax#}while (true) {}{#endsyntax#}

When resolving types together, such as {#syntax#}if{#endsyntax#} clauses or {#syntax#}switch{#endsyntax#} prongs, the {#syntax#}noreturn{#endsyntax#} type is compatible with every other type. Consider:

{#code|test\_noreturn.zig#}

Another use case for {#syntax#}noreturn{#endsyntax#} is the {#syntax#}exit{#endsyntax#} function:

{#code|test\_noreturn\_from\_exit.zig#} {#header\_close#} {#header\_open|Functions#} {#code|test\_functions.zig#}

There is a difference between a function _body_ and a function _pointer_. Function bodies are {#link|comptime#}-only types while function {#link|Pointers#} may be runtime-known.

{#header\_open|Pass-by-value Parameters#}

Primitive types such as {#link|Integers#} and {#link|Floats#} passed as parameters are copied, and then the copy is available in the function body. This is called "passing by value". Copying a primitive type is essentially free and typically involves nothing more than setting a register.

Structs, unions, and arrays can sometimes be more efficiently passed as a reference, since a copy could be arbitrarily expensive depending on the size. When these types are passed as parameters, Zig may choose to copy and pass by value, or pass by reference, whichever way Zig decides will be faster. This is made possible, in part, by the fact that parameters are immutable.

{#code|test\_pass\_by\_reference\_or\_value.zig#}

For extern functions, Zig follows the C ABI for passing structs and unions by value.

{#header\_close#} {#header\_open|Function Parameter Type Inference#}

Function parameters can be declared with {#syntax#}anytype{#endsyntax#} in place of the type. In this case the parameter types will be inferred when the function is called. Use {#link|@TypeOf#} and {#link|@typeInfo#} to get information about the inferred type.

{#code|test\_fn\_type\_inference.zig#} {#header\_close#} {#header\_open|inline fn#}

Adding the {#syntax#}inline{#endsyntax#} keyword to a function definition makes that function become _semantically inlined_ at the callsite. This is not a hint to be possibly observed by optimization passes, but has implications on the types and values involved in the function call.

Unlike normal function calls, arguments at an inline function callsite which are compile-time known are treated as {#link|Compile Time Parameters#}. This can potentially propagate all the way to the return value:

{#code|inline\_call.zig#}

If {#syntax#}inline{#endsyntax#} is removed, the test fails with the compile error instead of passing.

It is generally better to let the compiler decide when to inline a function, except for these scenarios:

*   To change how many stack frames are in the call stack, for debugging purposes.
*   To force comptime-ness of the arguments to propagate to the return value of the function, as in the above example.
*   Real world performance measurements demand it.

Note that {#syntax#}inline{#endsyntax#} actually _restricts_ what the compiler is allowed to do. This can harm binary size, compilation speed, and even runtime performance.

{#header\_close#} {#header\_open|Function Reflection#} {#code|test\_fn\_reflection.zig#} {#header\_close#} {#header\_close#} {#header\_open|Errors#} {#header\_open|Error Set Type#}

An error set is like an {#link|enum#}. However, each error name across the entire compilation gets assigned an unsigned integer greater than 0. You are allowed to declare the same error name more than once, and if you do, it gets assigned the same integer value.

The error set type defaults to a {#syntax#}u16{#endsyntax#}, though if the maximum number of distinct error values is provided via the \--error-limit \[num\] command line parameter an integer type with the minimum number of bits required to represent all of the error values will be used.

You can {#link|coerce|Type Coercion#} an error from a subset to a superset:

{#code|test\_coerce\_error\_subset\_to\_superset.zig#}

But you cannot {#link|coerce|Type Coercion#} an error from a superset to a subset:

{#code|test\_coerce\_error\_superset\_to\_subset.zig#}

There is a shortcut for declaring an error set with only 1 value, and then getting that value:

{#code|single\_value\_error\_set\_shortcut.zig#}

This is equivalent to:

{#code|single\_value\_error\_set.zig#}

This becomes useful when using {#link|Inferred Error Sets#}.

{#header\_open|The Global Error Set#}

{#syntax#}anyerror{#endsyntax#} refers to the global error set. This is the error set that contains all errors in the entire compilation unit, i.e. it is the union of all other error sets.

You can {#link|coerce|Type Coercion#} any error set to the global one, and you can explicitly cast an error of the global error set to a non-global one. This inserts a language-level assert to make sure the error value is in fact in the destination error set.

The global error set should generally be avoided because it prevents the compiler from knowing what errors are possible at compile-time. Knowing the error set at compile-time is better for generated documentation and helpful error messages, such as forgetting a possible error value in a {#link|switch#}.

{#header\_close#} {#header\_close#} {#header\_open|Error Union Type#}

An error set type and normal type can be combined with the {#syntax#}!{#endsyntax#} binary operator to form an error union type. You are likely to use an error union type more often than an error set type by itself.

Here is a function to parse a string into a 64-bit integer:

{#code|error\_union\_parsing\_u64.zig#}

Notice the return type is {#syntax#}!u64{#endsyntax#}. This means that the function either returns an unsigned 64 bit integer, or an error. We left off the error set to the left of the {#syntax#}!{#endsyntax#}, so the error set is inferred.

Within the function definition, you can see some return statements that return an error, and at the bottom a return statement that returns a {#syntax#}u64{#endsyntax#}. Both types {#link|coerce|Type Coercion#} to {#syntax#}anyerror!u64{#endsyntax#}.

What it looks like to use this function varies depending on what you're trying to do. One of the following:

*   You want to provide a default value if it returned an error.
*   If it returned an error then you want to return the same error.
*   You know with complete certainty it will not return an error, so want to unconditionally unwrap it.
*   You want to take a different action for each possible error.

{#header\_open|catch#}

If you want to provide a default value, you can use the {#syntax#}catch{#endsyntax#} binary operator:

{#code|catch.zig#}

In this code, {#syntax#}number{#endsyntax#} will be equal to the successfully parsed string, or a default value of 13. The type of the right hand side of the binary {#syntax#}catch{#endsyntax#} operator must match the unwrapped error union type, or be of type {#syntax#}noreturn{#endsyntax#}.

If you want to provide a default value with {#syntax#}catch{#endsyntax#} after performing some logic, you can combine {#syntax#}catch{#endsyntax#} with named {#link|Blocks#}:

{#code|handle\_error\_with\_catch\_block.zig#} {#header\_close#} {#header\_open|try#}

Let's say you wanted to return the error if you got one, otherwise continue with the function logic:

{#code|catch\_err\_return.zig#}

There is a shortcut for this. The {#syntax#}try{#endsyntax#} expression:

{#code|try.zig#}

{#syntax#}try{#endsyntax#} evaluates an error union expression. If it is an error, it returns from the current function with the same error. Otherwise, the expression results in the unwrapped value.

{#header\_close#}

Maybe you know with complete certainty that an expression will never be an error. In this case you can do this:

{#syntax#}const number = parseU64("1234", 10) catch unreachable;{#endsyntax#}

Here we know for sure that "1234" will parse successfully. So we put the {#syntax#}unreachable{#endsyntax#} value on the right hand side. {#syntax#}unreachable{#endsyntax#} invokes safety-checked {#link|Illegal Behavior#}, so in {#link|Debug#} and {#link|ReleaseSafe#}, triggers a safety panic by default. So, while we're debugging the application, if there _was_ a surprise error here, the application would crash appropriately.

You may want to take a different action for every situation. For that, we combine the {#link|if#} and {#link|switch#} expression:

{#syntax\_block|zig|handle\_all\_error\_scenarios.zig#} fn doAThing(str: \[\]u8) void { if (parseU64(str, 10)) |number| { doSomethingWithNumber(number); } else |err| switch (err) { error.Overflow => { // handle overflow... }, // we promise that InvalidChar won't happen (or crash in debug mode if it does) error.InvalidChar => unreachable, } } {#end\_syntax\_block#}

Finally, you may want to handle only some errors. For that, you can capture the unhandled errors in the {#syntax#}else{#endsyntax#} case, which now contains a narrower error set:

{#syntax\_block|zig|handle\_some\_error\_scenarios.zig#} fn doAnotherThing(str: \[\]u8) error{InvalidChar}!void { if (parseU64(str, 10)) |number| { doSomethingWithNumber(number); } else |err| switch (err) { error.Overflow => { // handle overflow... }, else => |leftover\_err| return leftover\_err, } } {#end\_syntax\_block#}

You must use the variable capture syntax. If you don't need the variable, you can capture with {#syntax#}\_{#endsyntax#} and avoid the {#syntax#}switch{#endsyntax#}.

{#syntax\_block|zig|handle\_no\_error\_scenarios.zig#} fn doADifferentThing(str: \[\]u8) void { if (parseU64(str, 10)) |number| { doSomethingWithNumber(number); } else |\_| { // do as you'd like } } {#end\_syntax\_block#} {#header\_open|errdefer#}

The other component to error handling is defer statements. In addition to an unconditional {#link|defer#}, Zig has {#syntax#}errdefer{#endsyntax#}, which evaluates the deferred expression on block exit path if and only if the function returned with an error from the block.

Example:

{#syntax\_block|zig|errdefer\_example.zig#} fn createFoo(param: i32) !Foo { const foo = try tryToAllocateFoo(); // now we have allocated foo. we need to free it if the function fails. // but we want to return it if the function succeeds. errdefer deallocateFoo(foo); const tmp\_buf = allocateTmpBuffer() orelse return error.OutOfMemory; // tmp\_buf is truly a temporary resource, and we for sure want to clean it up // before this block leaves scope defer deallocateTmpBuffer(tmp\_buf); if (param > 1337) return error.InvalidParam; // here the errdefer will not run since we're returning success from the function. // but the defer will run! return foo; } {#end\_syntax\_block#}

The neat thing about this is that you get robust error handling without the verbosity and cognitive overhead of trying to make sure every exit path is covered. The deallocation code is always directly following the allocation code.

The {#syntax#}errdefer{#endsyntax#} statement can optionally capture the error:

{#code|test\_errdefer\_capture.zig#} {#header\_close#}

A couple of other tidbits about error handling:

*   These primitives give enough expressiveness that it's completely practical to have failing to check for an error be a compile error. If you really want to ignore the error, you can add {#syntax#}catch unreachable{#endsyntax#} and get the added benefit of crashing in Debug and ReleaseSafe modes if your assumption was wrong.
*   Since Zig understands error types, it can pre-weight branches in favor of errors not occurring. Just a small optimization benefit that is not available in other languages.

{#see\_also|defer|if|switch#}

An error union is created with the {#syntax#}!{#endsyntax#} binary operator. You can use compile-time reflection to access the child type of an error union:

{#code|test\_error\_union.zig#} {#header\_open|Merging Error Sets#}

Use the {#syntax#}||{#endsyntax#} operator to merge two error sets together. The resulting error set contains the errors of both error sets. Doc comments from the left-hand side override doc comments from the right-hand side. In this example, the doc comments for {#syntax#}C.PathNotFound{#endsyntax#} is `A doc comment`.

This is especially useful for functions which return different error sets depending on {#link|comptime#} branches. For example, the Zig standard library uses {#syntax#}LinuxFileOpenError || WindowsFileOpenError{#endsyntax#} for the error set of opening files.

{#code|test\_merging\_error\_sets.zig#} {#header\_close#} {#header\_open|Inferred Error Sets#}

Because many functions in Zig return a possible error, Zig supports inferring the error set. To infer the error set for a function, prepend the {#syntax#}!{#endsyntax#} operator to the function’s return type, like {#syntax#}!T{#endsyntax#}:

{#code|test\_inferred\_error\_sets.zig#}

When a function has an inferred error set, that function becomes generic and thus it becomes trickier to do certain things with it, such as obtain a function pointer, or have an error set that is consistent across different build targets. Additionally, inferred error sets are incompatible with recursion.

In these situations, it is recommended to use an explicit error set. You can generally start with an empty error set and let compile errors guide you toward completing the set.

These limitations may be overcome in a future version of Zig.

{#header\_close#} {#header\_close#} {#header\_open|Error Return Traces#}

Error Return Traces show all the points in the code that an error was returned to the calling function. This makes it practical to use {#link|try#} everywhere and then still be able to know what happened if an error ends up bubbling all the way out of your application.

{#code|error\_return\_trace.zig#}

Look closely at this example. This is no stack trace.

You can see that the final error bubbled up was {#syntax#}PermissionDenied{#endsyntax#}, but the original error that started this whole thing was {#syntax#}FileNotFound{#endsyntax#}. In the {#syntax#}bar{#endsyntax#} function, the code handles the original error code, and then returns another one, from the switch statement. Error Return Traces make this clear, whereas a stack trace would look like this:

{#code|stack\_trace.zig#}

Here, the stack trace does not explain how the control flow in {#syntax#}bar{#endsyntax#} got to the {#syntax#}hello(){#endsyntax#} call. One would have to open a debugger or further instrument the application in order to find out. The error return trace, on the other hand, shows exactly how the error bubbled up.

This debugging feature makes it easier to iterate quickly on code that robustly handles all error conditions. This means that Zig developers will naturally find themselves writing correct, robust code in order to increase their development pace.

Error Return Traces are enabled by default in {#link|Debug#} builds and disabled by default in {#link|ReleaseFast#}, {#link|ReleaseSafe#} and {#link|ReleaseSmall#} builds.

There are a few ways to activate this error return tracing feature:

*   Return an error from main
*   An error makes its way to {#syntax#}catch unreachable{#endsyntax#} and you have not overridden the default panic handler
*   Use {#link|errorReturnTrace#} to access the current return trace. You can use {#syntax#}std.debug.dumpStackTrace{#endsyntax#} to print it. This function returns comptime-known {#link|null#} when building without error return tracing support.

{#header\_open|Implementation Details#}

To analyze performance cost, there are two cases:

*   when no errors are returned
*   when returning errors

For the case when no errors are returned, the cost is a single memory write operation, only in the first non-failable function in the call graph that calls a failable function, i.e. when a function returning {#syntax#}void{#endsyntax#} calls a function returning {#syntax#}error{#endsyntax#}. This is to initialize this struct in the stack memory:

{#syntax\_block|zig|stack\_trace\_struct.zig#} pub const StackTrace = struct { index: usize, instruction\_addresses: \[N\]usize, }; {#end\_syntax\_block#}

Here, N is the maximum function call depth as determined by call graph analysis. Recursion is ignored and counts for 2.

A pointer to {#syntax#}StackTrace{#endsyntax#} is passed as a secret parameter to every function that can return an error, but it's always the first parameter, so it can likely sit in a register and stay there.

That's it for the path when no errors occur. It's practically free in terms of performance.

When generating the code for a function that returns an error, just before the {#syntax#}return{#endsyntax#} statement (only for the {#syntax#}return{#endsyntax#} statements that return errors), Zig generates a call to this function:

{#syntax\_block|zig|zig\_return\_error\_fn.zig#} // marked as "no-inline" in LLVM IR fn \_\_zig\_return\_error(stack\_trace: \*StackTrace) void { stack\_trace.instruction\_addresses\[stack\_trace.index\] = @returnAddress(); stack\_trace.index = (stack\_trace.index + 1) % N; } {#end\_syntax\_block#}

The cost is 2 math operations plus some memory reads and writes. The memory accessed is constrained and should remain cached for the duration of the error return bubbling.

As for code size cost, 1 function call before a return statement is no big deal. Even so, I have [a plan](https://github.com/ziglang/zig/issues/690) to make the call to {#syntax#}\_\_zig\_return\_error{#endsyntax#} a tail call, which brings the code size cost down to actually zero. What is a return statement in code without error return tracing can become a jump instruction in code with error return tracing.

{#header\_close#} {#header\_close#} {#header\_close#} {#header\_open|Optionals#}

One area that Zig provides safety without compromising efficiency or readability is with the optional type.

The question mark symbolizes the optional type. You can convert a type to an optional type by putting a question mark in front of it, like this:

{#code|optional\_integer.zig#}

Now the variable {#syntax#}optional\_int{#endsyntax#} could be an {#syntax#}i32{#endsyntax#}, or {#syntax#}null{#endsyntax#}.

Instead of integers, let's talk about pointers. Null references are the source of many runtime exceptions, and even stand accused of being [the worst mistake of computer science](https://www.lucidchart.com/techblog/2015/08/31/the-worst-mistake-of-computer-science/).

Zig does not have them.

Instead, you can use an optional pointer. This secretly compiles down to a normal pointer, since we know we can use 0 as the null value for the optional type. But the compiler can check your work and make sure you don't assign null to something that can't be null.

Typically the downside of not having null is that it makes the code more verbose to write. But, let's compare some equivalent C code and Zig code.

Task: call malloc, if the result is null, return null.

C code

{#syntax\_block|c|call\_malloc\_in\_c.c#} // malloc prototype included for reference void \*malloc(size\_t size); struct Foo \*do\_a\_thing(void) { char \*ptr = malloc(1234); if (!ptr) return NULL; // ... } {#end\_syntax\_block#}

Zig code

{#syntax\_block|zig|call\_malloc\_from\_zig.zig#} // malloc prototype included for reference extern fn malloc(size: usize) ?\[\*\]u8; fn doAThing() ?\*Foo { const ptr = malloc(1234) orelse return null; \_ = ptr; // ... } {#end\_syntax\_block#}

Here, Zig is at least as convenient, if not more, than C. And, the type of "ptr" is {#syntax#}\[\*\]u8{#endsyntax#} _not_ {#syntax#}?\[\*\]u8{#endsyntax#}. The {#syntax#}orelse{#endsyntax#} keyword unwrapped the optional type and therefore {#syntax#}ptr{#endsyntax#} is guaranteed to be non-null everywhere it is used in the function.

The other form of checking against NULL you might see looks like this:

{#syntax\_block|c|checking\_null\_in\_c.c#} void do\_a\_thing(struct Foo \*foo) { // do some stuff if (foo) { do\_something\_with\_foo(foo); } // do some stuff } {#end\_syntax\_block#}

In Zig you can accomplish the same thing:

{#code|checking\_null\_in\_zig.zig#}

Once again, the notable thing here is that inside the if block, {#syntax#}foo{#endsyntax#} is no longer an optional pointer, it is a pointer, which cannot be null.

One benefit to this is that functions which take pointers as arguments can be annotated with the "nonnull" attribute - `__attribute__((nonnull))` in [GCC](https://gcc.gnu.org/onlinedocs/gcc-4.0.0/gcc/Function-Attributes.html). The optimizer can sometimes make better decisions knowing that pointer arguments cannot be null.

{#header\_open|Optional Type#}

An optional is created by putting {#syntax#}?{#endsyntax#} in front of a type. You can use compile-time reflection to access the child type of an optional:

{#code|test\_optional\_type.zig#} {#header\_close#} {#header\_open|null#}

Just like {#link|undefined#}, {#syntax#}null{#endsyntax#} has its own type, and the only way to use it is to cast it to a different type:

{#code|null.zig#} {#header\_close#} {#header\_open|Optional Pointers#}

An optional pointer is guaranteed to be the same size as a pointer. The {#syntax#}null{#endsyntax#} of the optional is guaranteed to be address 0.

{#code|test\_optional\_pointer.zig#} {#header\_close#} {#see\_also|while with Optionals|if with Optionals#} {#header\_close#} {#header\_open|Casting#}

A **type cast** converts a value of one type to another. Zig has {#link|Type Coercion#} for conversions that are known to be completely safe and unambiguous, and {#link|Explicit Casts#} for conversions that one would not want to happen on accident. There is also a third kind of type conversion called {#link|Peer Type Resolution#} for the case when a result type must be decided given multiple operand types.

{#header\_open|Type Coercion#}

Type coercion occurs when one type is expected, but different type is provided:

{#code|test\_type\_coercion.zig#}

Type coercions are only allowed when it is completely unambiguous how to get from one type to another, and the transformation is guaranteed to be safe. There is one exception, which is {#link|C Pointers#}.

{#header\_open|Type Coercion: Stricter Qualification#}

Values which have the same representation at runtime can be cast to increase the strictness of the qualifiers, no matter how nested the qualifiers are:

*   {#syntax#}const{#endsyntax#} - non-const to const is allowed
*   {#syntax#}volatile{#endsyntax#} - non-volatile to volatile is allowed
*   {#syntax#}align{#endsyntax#} - bigger to smaller alignment is allowed
*   {#link|error sets|Error Set Type#} to supersets is allowed

These casts are no-ops at runtime since the value representation does not change.

{#code|test\_no\_op\_casts.zig#}

In addition, pointers coerce to const optional pointers:

{#code|test\_pointer\_coerce\_const\_optional.zig#} {#header\_close#} {#header\_open|Type Coercion: Integer and Float Widening#}

{#link|Integers#} coerce to integer types which can represent every value of the old type, and likewise {#link|Floats#} coerce to float types which can represent every value of the old type.

{#code|test\_integer\_widening.zig#} {#header\_close#} {#header\_open|Type Coercion: Float to Int#}

A compiler error is appropriate because this ambiguous expression leaves the compiler two choices about the coercion.

*   Cast {#syntax#}54.0{#endsyntax#} to {#syntax#}comptime\_int{#endsyntax#} resulting in {#syntax#}@as(comptime\_int, 10){#endsyntax#}, which is casted to {#syntax#}@as(f32, 10){#endsyntax#}
*   Cast {#syntax#}5{#endsyntax#} to {#syntax#}comptime\_float{#endsyntax#} resulting in {#syntax#}@as(comptime\_float, 10.8){#endsyntax#}, which is casted to {#syntax#}@as(f32, 10.8){#endsyntax#}

{#code|test\_ambiguous\_coercion.zig#} {#header\_close#} {#header\_open|Type Coercion: Slices, Arrays and Pointers#} {#code|test\_coerce\_slices\_arrays\_and\_pointers.zig#} {#see\_also|C Pointers#} {#header\_close#} {#header\_open|Type Coercion: Optionals#}

The payload type of {#link|Optionals#}, as well as {#link|null#}, coerce to the optional type.

{#code|test\_coerce\_optionals.zig#}

Optionals work nested inside the {#link|Error Union Type#}, too:

{#code|test\_coerce\_optional\_wrapped\_error\_union.zig#} {#header\_close#} {#header\_open|Type Coercion: Error Unions#}

The payload type of an {#link|Error Union Type#} as well as the {#link|Error Set Type#} coerce to the error union type:

{#code|test\_coerce\_to\_error\_union.zig#} {#header\_close#} {#header\_open|Type Coercion: Compile-Time Known Numbers#}

When a number is {#link|comptime#}-known to be representable in the destination type, it may be coerced:

{#code|test\_coerce\_large\_to\_small.zig#} {#header\_close#} {#header\_open|Type Coercion: Unions and Enums#}

Tagged unions can be coerced to enums, and enums can be coerced to tagged unions when they are {#link|comptime#}-known to be a field of the union that has only one possible value, such as {#link|void#}:

{#code|test\_coerce\_unions\_enums.zig#} {#see\_also|union|enum#} {#header\_close#} {#header\_open|Type Coercion: undefined#}

{#link|undefined#} can be coerced to any type.

{#header\_close#} {#header\_open|Type Coercion: Tuples to Arrays#}

{#link|Tuples#} can be coerced to arrays, if all of the fields have the same type.

{#code|test\_coerce\_tuples\_arrays.zig#} {#header\_close#} {#header\_close#} {#header\_open|Explicit Casts#}

Explicit casts are performed via {#link|Builtin Functions#}. Some explicit casts are safe; some are not. Some explicit casts perform language-level assertions; some do not. Some explicit casts are no-ops at runtime; some are not.

*   {#link|@bitCast#} - change type but maintain bit representation
*   {#link|@alignCast#} - make a pointer have more alignment
*   {#link|@enumFromInt#} - obtain an enum value based on its integer tag value
*   {#link|@errorFromInt#} - obtain an error code based on its integer value
*   {#link|@errorCast#} - convert to a smaller error set
*   {#link|@floatCast#} - convert a larger float to a smaller float
*   {#link|@floatFromInt#} - convert an integer to a float value
*   {#link|@intCast#} - convert between integer types
*   {#link|@intFromBool#} - convert true to 1 and false to 0
*   {#link|@intFromEnum#} - obtain the integer tag value of an enum or tagged union
*   {#link|@intFromError#} - obtain the integer value of an error code
*   {#link|@intFromFloat#} - obtain the integer part of a float value
*   {#link|@intFromPtr#} - obtain the address of a pointer
*   {#link|@ptrFromInt#} - convert an address to a pointer
*   {#link|@ptrCast#} - convert between pointer types
*   {#link|@truncate#} - convert between integer types, chopping off bits

{#header\_close#} {#header\_open|Peer Type Resolution#}

Peer Type Resolution occurs in these places:

*   {#link|switch#} expressions
*   {#link|if#} expressions
*   {#link|while#} expressions
*   {#link|for#} expressions
*   Multiple break statements in a block
*   Some {#link|binary operations|Table of Operators#}

This kind of type resolution chooses a type that all peer types can coerce into. Here are some examples:

{#code|test\_peer\_type\_resolution.zig#} {#header\_close#} {#header\_close#} {#header\_open|Zero Bit Types#}

For some types, {#link|@sizeOf#} is 0:

*   {#link|void#}
*   The {#link|Integers#} {#syntax#}u0{#endsyntax#} and {#syntax#}i0{#endsyntax#}.
*   {#link|Arrays#} and {#link|Vectors#} with len 0, or with an element type that is a zero bit type.
*   An {#link|enum#} with only 1 tag.
*   A {#link|struct#} with all fields being zero bit types.
*   A {#link|union#} with only 1 field which is a zero bit type.

These types can only ever have one possible value, and thus require 0 bits to represent. Code that makes use of these types is not included in the final generated code:

{#code|zero\_bit\_types.zig#}

When this turns into machine code, there is no code generated in the body of {#syntax#}entry{#endsyntax#}, even in {#link|Debug#} mode. For example, on x86\_64:

    0000000000000010 <entry>:
      10:	55                   	push   %rbp
      11:	48 89 e5             	mov    %rsp,%rbp
      14:	5d                   	pop    %rbp
      15:	c3                   	retq   

These assembly instructions do not have any code associated with the void values - they only perform the function call prologue and epilogue.

{#header\_open|void#}

{#syntax#}void{#endsyntax#} can be useful for instantiating generic types. For example, given a {#syntax#}Map(Key, Value){#endsyntax#}, one can pass {#syntax#}void{#endsyntax#} for the {#syntax#}Value{#endsyntax#} type to make it into a {#syntax#}Set{#endsyntax#}:

{#code|test\_void\_in\_hashmap.zig#}

Note that this is different from using a dummy value for the hash map value. By using {#syntax#}void{#endsyntax#} as the type of the value, the hash map entry type has no value field, and thus the hash map takes up less space. Further, all the code that deals with storing and loading the value is deleted, as seen above.

{#syntax#}void{#endsyntax#} is distinct from {#syntax#}anyopaque{#endsyntax#}. {#syntax#}void{#endsyntax#} has a known size of 0 bytes, and {#syntax#}anyopaque{#endsyntax#} has an unknown, but non-zero, size.

Expressions of type {#syntax#}void{#endsyntax#} are the only ones whose value can be ignored. For example, ignoring a non-{#syntax#}void{#endsyntax#} expression is a compile error:

{#code|test\_expression\_ignored.zig#}

However, if the expression has type {#syntax#}void{#endsyntax#}, there will be no error. Expression results can be explicitly ignored by assigning them to {#syntax#}\_{#endsyntax#}.

{#code|test\_void\_ignored.zig#} {#header\_close#} {#header\_close#} {#header\_open|Result Location Semantics#}

During compilation, every Zig expression and sub-expression is assigned optional result location information. This information dictates what type the expression should have (its result type), and where the resulting value should be placed in memory (its result location). The information is optional in the sense that not every expression has this information: assignment to {#syntax#}\_{#endsyntax#}, for instance, does not provide any information about the type of an expression, nor does it provide a concrete memory location to place it in.

As a motivating example, consider the statement {#syntax#}const x: u32 = 42;{#endsyntax#}. The type annotation here provides a result type of {#syntax#}u32{#endsyntax#} to the initialization expression {#syntax#}42{#endsyntax#}, instructing the compiler to coerce this integer (initially of type {#syntax#}comptime\_int{#endsyntax#}) to this type. We will see more examples shortly.

This is not an implementation detail: the logic outlined above is codified into the Zig language specification, and is the primary mechanism of type inference in the language. This system is collectively referred to as "Result Location Semantics".

{#header\_open|Result Types#}

Result types are propagated recursively through expressions where possible. For instance, if the expression {#syntax#}&e{#endsyntax#} has result type {#syntax#}\*u32{#endsyntax#}, then {#syntax#}e{#endsyntax#} is given a result type of {#syntax#}u32{#endsyntax#}, allowing the language to perform this coercion before taking a reference.

The result type mechanism is utilized by casting builtins such as {#syntax#}@intCast{#endsyntax#}. Rather than taking as an argument the type to cast to, these builtins use their result type to determine this information. The result type is often known from context; where it is not, the {#syntax#}@as{#endsyntax#} builtin can be used to explicitly provide a result type.

We can break down the result types for each component of a simple expression as follows:

{#code|result\_type\_propagation.zig#}

This result type information is useful for the aforementioned cast builtins, as well as to avoid the construction of pre-coercion values, and to avoid the need for explicit type coercions in some cases. The following table details how some common expressions propagate result types, where {#syntax#}x{#endsyntax#} and {#syntax#}y{#endsyntax#} are arbitrary sub-expressions.

Expression

Parent Result Type

Sub-expression Result Type

{#syntax#}const val: T = x{#endsyntax#}

\-

{#syntax#}x{#endsyntax#} is a {#syntax#}T{#endsyntax#}

{#syntax#}var val: T = x{#endsyntax#}

\-

{#syntax#}x{#endsyntax#} is a {#syntax#}T{#endsyntax#}

{#syntax#}val = x{#endsyntax#}

\-

{#syntax#}x{#endsyntax#} is a {#syntax#}@TypeOf(val){#endsyntax#}

{#syntax#}@as(T, x){#endsyntax#}

\-

{#syntax#}x{#endsyntax#} is a {#syntax#}T{#endsyntax#}

{#syntax#}&x{#endsyntax#}

{#syntax#}\*T{#endsyntax#}

{#syntax#}x{#endsyntax#} is a {#syntax#}T{#endsyntax#}

{#syntax#}&x{#endsyntax#}

{#syntax#}\[\]T{#endsyntax#}

{#syntax#}x{#endsyntax#} is some array of {#syntax#}T{#endsyntax#}

{#syntax#}f(x){#endsyntax#}

\-

{#syntax#}x{#endsyntax#} has the type of the first parameter of {#syntax#}f{#endsyntax#}

{#syntax#}.{x}{#endsyntax#}

{#syntax#}T{#endsyntax#}

{#syntax#}x{#endsyntax#} is a {#syntax#}@FieldType(T, "0"){#endsyntax#}

{#syntax#}.{ .a = x }{#endsyntax#}

{#syntax#}T{#endsyntax#}

{#syntax#}x{#endsyntax#} is a {#syntax#}@FieldType(T, "a"){#endsyntax#}

{#syntax#}T{x}{#endsyntax#}

\-

{#syntax#}x{#endsyntax#} is a {#syntax#}@FieldType(T, "0"){#endsyntax#}

{#syntax#}T{ .a = x }{#endsyntax#}

\-

{#syntax#}x{#endsyntax#} is a {#syntax#}@FieldType(T, "a"){#endsyntax#}

{#syntax#}@Int(x, y){#endsyntax#}

\-

{#syntax#}x{#endsyntax#} is a {#syntax#}std.builtin.Signedness{#endsyntax#}, {#syntax#}y{#endsyntax#} is a {#syntax#}u16{#endsyntax#}

{#syntax#}@typeInfo(x){#endsyntax#}

\-

{#syntax#}x{#endsyntax#} is a {#syntax#}type{#endsyntax#}

{#syntax#}x << y{#endsyntax#}

\-

{#syntax#}y{#endsyntax#} is a {#syntax#}std.math.Log2IntCeil(@TypeOf(x)){#endsyntax#}

{#header\_close#} {#header\_open|Result Locations#}

In addition to result type information, every expression may be optionally assigned a result location: a pointer to which the value must be directly written. This system can be used to prevent intermediate copies when initializing data structures, which can be important for types which must have a fixed memory address ("pinned" types).

When compiling the simple assignment expression {#syntax#}x = e{#endsyntax#}, many languages would create the temporary value {#syntax#}e{#endsyntax#} on the stack, and then assign it to {#syntax#}x{#endsyntax#}, potentially performing a type coercion in the process. Zig approaches this differently. The expression {#syntax#}e{#endsyntax#} is given a result type matching the type of {#syntax#}x{#endsyntax#}, and a result location of {#syntax#}&x{#endsyntax#}. For many syntactic forms of {#syntax#}e{#endsyntax#}, this has no practical impact. However, it can have important semantic effects when working with more complex syntax forms.

For instance, if the expression {#syntax#}.{ .a = x, .b = y }{#endsyntax#} has a result location of {#syntax#}ptr{#endsyntax#}, then {#syntax#}x{#endsyntax#} is given a result location of {#syntax#}&ptr.a{#endsyntax#}, and {#syntax#}y{#endsyntax#} a result location of {#syntax#}&ptr.b{#endsyntax#}. Without this system, this expression would construct a temporary struct value entirely on the stack, and only then copy it to the destination address. In essence, Zig desugars the assignment {#syntax#}foo = .{ .a = x, .b = y }{#endsyntax#} to the two statements {#syntax#}foo.a = x; foo.b = y;{#endsyntax#}.

This can sometimes be important when assigning an aggregate value where the initialization expression depends on the previous value of the aggregate. The easiest way to demonstrate this is by attempting to swap fields of a struct or array - the following logic looks sound, but in fact is not:

{#code|result\_location\_interfering\_with\_swap.zig#}

The following table details how some common expressions propagate result locations, where {#syntax#}x{#endsyntax#} and {#syntax#}y{#endsyntax#} are arbitrary sub-expressions. Note that some expressions cannot provide meaningful result locations to sub-expressions, even if they themselves have a result location.

Expression

Result Location

Sub-expression Result Locations

{#syntax#}const val: T = x{#endsyntax#}

\-

{#syntax#}x{#endsyntax#} has result location {#syntax#}&val{#endsyntax#}

{#syntax#}var val: T = x{#endsyntax#}

\-

{#syntax#}x{#endsyntax#} has result location {#syntax#}&val{#endsyntax#}

{#syntax#}val = x{#endsyntax#}

\-

{#syntax#}x{#endsyntax#} has result location {#syntax#}&val{#endsyntax#}

{#syntax#}@as(T, x){#endsyntax#}

{#syntax#}ptr{#endsyntax#}

{#syntax#}x{#endsyntax#} has no result location

{#syntax#}&x{#endsyntax#}

{#syntax#}ptr{#endsyntax#}

{#syntax#}x{#endsyntax#} has no result location

{#syntax#}f(x){#endsyntax#}

{#syntax#}ptr{#endsyntax#}

{#syntax#}x{#endsyntax#} has no result location

{#syntax#}.{x}{#endsyntax#}

{#syntax#}ptr{#endsyntax#}

{#syntax#}x{#endsyntax#} has result location {#syntax#}&ptr\[0\]{#endsyntax#}

{#syntax#}.{ .a = x }{#endsyntax#}

{#syntax#}ptr{#endsyntax#}

{#syntax#}x{#endsyntax#} has result location {#syntax#}&ptr.a{#endsyntax#}

{#syntax#}T{x}{#endsyntax#}

{#syntax#}ptr{#endsyntax#}

{#syntax#}x{#endsyntax#} has no result location (typed initializers do not propagate result locations)

{#syntax#}T{ .a = x }{#endsyntax#}

{#syntax#}ptr{#endsyntax#}

{#syntax#}x{#endsyntax#} has no result location (typed initializers do not propagate result locations)

{#syntax#}@Int(x, y){#endsyntax#}

\-

{#syntax#}x{#endsyntax#} and {#syntax#}y{#endsyntax#} do not have result locations

{#syntax#}@typeInfo(x){#endsyntax#}

{#syntax#}ptr{#endsyntax#}

{#syntax#}x{#endsyntax#} has no result location

{#syntax#}x << y{#endsyntax#}

{#syntax#}ptr{#endsyntax#}

{#syntax#}x{#endsyntax#} and {#syntax#}y{#endsyntax#} do not have result locations

{#header\_close#} {#header\_close#} {#header\_open|comptime#}

Zig places importance on the concept of whether an expression is known at compile-time. There are a few different places this concept is used, and these building blocks are used to keep the language small, readable, and powerful.

{#header\_open|Introducing the Compile-Time Concept#} {#header\_open|Compile-Time Parameters#}

Compile-time parameters is how Zig implements generics. It is compile-time duck typing.

{#code|compile-time\_duck\_typing.zig#}

In Zig, types are first-class citizens. They can be assigned to variables, passed as parameters to functions, and returned from functions. However, they can only be used in expressions which are known at _compile-time_, which is why the parameter {#syntax#}T{#endsyntax#} in the above snippet must be marked with {#syntax#}comptime{#endsyntax#}.

A {#syntax#}comptime{#endsyntax#} parameter means that:

*   At the callsite, the value must be known at compile-time, or it is a compile error.
*   In the function definition, the value is known at compile-time.

For example, if we were to introduce another function to the above snippet:

{#code|test\_unresolved\_comptime\_value.zig#}

This is an error because the programmer attempted to pass a value only known at run-time to a function which expects a value known at compile-time.

Another way to get an error is if we pass a type that violates the type checker when the function is analyzed. This is what it means to have _compile-time duck typing_.

For example:

{#code|test\_comptime\_mismatched\_type.zig#}

On the flip side, inside the function definition with the {#syntax#}comptime{#endsyntax#} parameter, the value is known at compile-time. This means that we actually could make this work for the bool type if we wanted to:

{#code|test\_comptime\_max\_with\_bool.zig#}

This works because Zig implicitly inlines {#syntax#}if{#endsyntax#} expressions when the condition is known at compile-time, and the compiler guarantees that it will skip analysis of the branch not taken.

This means that the actual function generated for {#syntax#}max{#endsyntax#} in this situation looks like this:

{#code|compiler\_generated\_function.zig#}

All the code that dealt with compile-time known values is eliminated and we are left with only the necessary run-time code to accomplish the task.

This works the same way for {#syntax#}switch{#endsyntax#} expressions - they are implicitly inlined when the target expression is compile-time known.

{#header\_close#} {#header\_open|Compile-Time Variables#}

In Zig, the programmer can label variables as {#syntax#}comptime{#endsyntax#}. This guarantees to the compiler that every load and store of the variable is performed at compile-time. Any violation of this results in a compile error.

This combined with the fact that we can {#syntax#}inline{#endsyntax#} loops allows us to write a function which is partially evaluated at compile-time and partially at run-time.

For example:

{#code|test\_comptime\_evaluation.zig#}

This example is a bit contrived, because the compile-time evaluation component is unnecessary; this code would work fine if it was all done at run-time. But it does end up generating different code. In this example, the function {#syntax#}performFn{#endsyntax#} is generated three different times, for the different values of {#syntax#}prefix\_char{#endsyntax#} provided:

{#syntax\_block|zig|performFn\_1#} // From the line: // expect(performFn('t', 1) == 6); fn performFn(start\_value: i32) i32 { var result: i32 = start\_value; result = two(result); result = three(result); return result; } {#end\_syntax\_block#} {#syntax\_block|zig|performFn\_2#} // From the line: // expect(performFn('o', 0) == 1); fn performFn(start\_value: i32) i32 { var result: i32 = start\_value; result = one(result); return result; } {#end\_syntax\_block#} {#syntax\_block|zig|performFn\_3#} // From the line: // expect(performFn('w', 99) == 99); fn performFn(start\_value: i32) i32 { var result: i32 = start\_value; \_ = &result; return result; } {#end\_syntax\_block#}

Note that this happens even in a debug build. This is not a way to write more optimized code, but it is a way to make sure that what _should_ happen at compile-time, _does_ happen at compile-time. This catches more errors and allows expressiveness that in other languages requires using macros, generated code, or a preprocessor to accomplish.

{#header\_close#} {#header\_open|Compile-Time Expressions#}

In Zig, it matters whether a given expression is known at compile-time or run-time. A programmer can use a {#syntax#}comptime{#endsyntax#} expression to guarantee that the expression will be evaluated at compile-time. If this cannot be accomplished, the compiler will emit an error. For example:

{#code|test\_comptime\_call\_extern\_function.zig#}

It doesn't make sense that a program could call {#syntax#}exit(){#endsyntax#} (or any other external function) at compile-time, so this is a compile error. However, a {#syntax#}comptime{#endsyntax#} expression does much more than sometimes cause a compile error.

Within a {#syntax#}comptime{#endsyntax#} expression:

*   All variables are {#syntax#}comptime{#endsyntax#} variables.
*   All {#syntax#}if{#endsyntax#}, {#syntax#}while{#endsyntax#}, {#syntax#}for{#endsyntax#}, and {#syntax#}switch{#endsyntax#} expressions are evaluated at compile-time, or emit a compile error if this is not possible.
*   All {#syntax#}return{#endsyntax#} and {#syntax#}try{#endsyntax#} expressions are invalid (unless the function itself is called at compile-time).
*   All code with runtime side effects or depending on runtime values emits a compile error.
*   All function calls cause the compiler to interpret the function at compile-time, emitting a compile error if the function tries to do something that has global runtime side effects.

This means that a programmer can create a function which is called both at compile-time and run-time, with no modification to the function required.

Let's look at an example:

{#code|test\_fibonacci\_recursion.zig#}

Imagine if we had forgotten the base case of the recursive function and tried to run the tests:

{#code|test\_fibonacci\_comptime\_overflow.zig#}

The compiler produces an error which is a stack trace from trying to evaluate the function at compile-time.

Luckily, we used an unsigned integer, and so when we tried to subtract 1 from 0, it triggered {#link|Illegal Behavior#}, which is always a compile error if the compiler knows it happened. But what would have happened if we used a signed integer?

{#code|fibonacci\_comptime\_infinite\_recursion.zig#}

The compiler is supposed to notice that evaluating this function at compile-time took more than 1000 branches, and thus emits an error and gives up. If the programmer wants to increase the budget for compile-time computation, they can use a built-in function called {#link|@setEvalBranchQuota#} to change the default number 1000 to something else.

However, there is a [design flaw in the compiler](https://github.com/ziglang/zig/issues/13724) causing it to stack overflow instead of having the proper behavior here. I'm terribly sorry about that. I hope to get this resolved before the next release.

What if we fix the base case, but put the wrong value in the {#syntax#}expect{#endsyntax#} line?

{#code|test\_fibonacci\_comptime\_unreachable.zig#}

At {#link|container|Containers#} level (outside of any function), all expressions are implicitly {#syntax#}comptime{#endsyntax#} expressions. This means that we can use functions to initialize complex static data. For example:

{#code|test\_container-level\_comptime\_expressions.zig#}

When we compile this program, Zig generates the constants with the answer pre-computed. Here are the lines from the generated LLVM IR:

    @0 = internal unnamed_addr constant [25 x i32] [i32 2, i32 3, i32 5, i32 7, i32 11, i32 13, i32 17, i32 19, i32 23, i32 29, i32 31, i32 37, i32 41, i32 43, i32 47, i32 53, i32 59, i32 61, i32 67, i32 71, i32 73, i32 79, i32 83, i32 89, i32 97]
    @1 = internal unnamed_addr constant i32 1060

Note that we did not have to do anything special with the syntax of these functions. For example, we could call the {#syntax#}sum{#endsyntax#} function as is with a slice of numbers whose length and values were only known at run-time.

{#header\_close#} {#header\_close#} {#header\_open|Generic Data Structures#}

Zig uses comptime capabilities to implement generic data structures without introducing any special-case syntax.

Here is an example of a generic {#syntax#}List{#endsyntax#} data structure.

{#code|generic\_data\_structure.zig#}

That's it. It's a function that returns an anonymous {#syntax#}struct{#endsyntax#}. For the purposes of error messages and debugging, Zig infers the name {#syntax#}"List(i32)"{#endsyntax#} from the function name and parameters invoked when creating the anonymous struct.

To explicitly give a type a name, we assign it to a constant.

{#code|anonymous\_struct\_name.zig#}

In this example, the {#syntax#}Node{#endsyntax#} struct refers to itself. This works because all top level declarations are order-independent. As long as the compiler can determine the size of the struct, it is free to refer to itself. In this case, {#syntax#}Node{#endsyntax#} refers to itself as a pointer, which has a well-defined size at compile time, so it works fine.

{#header\_close#} {#header\_open|Case Study: print in Zig#}

Putting all of this together, let's see how {#syntax#}print{#endsyntax#} works in Zig.

{#code|print.zig#}

Let's crack open the implementation of this and see how it works:

{#code|poc\_print\_fn.zig#}

This is a proof of concept implementation; the actual function in the standard library has more formatting capabilities.

Note that this is not hard-coded into the Zig compiler; this is userland code in the standard library.

When this function is analyzed from our example code above, Zig partially evaluates the function and emits a function that actually looks like this:

{#syntax\_block|zig|Emitted print Function#} pub fn print(self: \*Writer, arg0: \[\]const u8, arg1: i32) !void { try self.write("here is a string: '"); try self.printValue(arg0); try self.write("' here is a number: "); try self.printValue(arg1); try self.write("\\n"); try self.flush(); } {#end\_syntax\_block#}

{#syntax#}printValue{#endsyntax#} is a function that takes a parameter of any type, and does different things depending on the type:

{#code|poc\_printValue\_fn.zig#}

And now, what happens if we give too many arguments to {#syntax#}print{#endsyntax#}?

{#code|test\_print\_too\_many\_args.zig#}

Zig gives programmers the tools needed to protect themselves against their own mistakes.

Zig doesn't care whether the format argument is a string literal, only that it is a compile-time known value that can be coerced to a {#syntax#}\[\]const u8{#endsyntax#}:

{#code|print\_comptime-known\_format.zig#}

This works fine.

Zig does not special case string formatting in the compiler and instead exposes enough power to accomplish this task in userland. It does so without introducing another language on top of Zig, such as a macro language or a preprocessor language. It's Zig all the way down.

{#header\_close#} {#see\_also|inline while|inline for#} {#header\_close#} {#header\_open|Assembly#}

For some use cases, it may be necessary to directly control the machine code generated by Zig programs, rather than relying on Zig's code generation. For these cases, one can use inline assembly. Here is an example of implementing Hello, World on x86\_64 Linux using inline assembly:

{#code|inline\_assembly.zig#}

Dissecting the syntax:

{#code|Assembly Syntax Explained.zig#}

For x86 and x86\_64 targets, the syntax is AT&T syntax, rather than the more popular Intel syntax. This is due to technical constraints; assembly parsing is provided by LLVM and its support for Intel syntax is buggy and not well tested.

Some day Zig may have its own assembler. This would allow it to integrate more seamlessly into the language, as well as be compatible with the popular NASM syntax. This documentation section will be updated before 1.0.0 is released, with a conclusive statement about the status of AT&T vs Intel/NASM syntax.

{#header\_open|Output Constraints#}

Output constraints are still considered to be unstable in Zig, and so [LLVM documentation](http://releases.llvm.org/10.0.0/docs/LangRef.html#inline-asm-constraint-string) and [GCC documentation](https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html) must be used to understand the semantics.

Note that some breaking changes to output constraints are planned with [issue #215](https://github.com/ziglang/zig/issues/215).

{#header\_close#} {#header\_open|Input Constraints#}

Input constraints are still considered to be unstable in Zig, and so [LLVM documentation](http://releases.llvm.org/10.0.0/docs/LangRef.html#inline-asm-constraint-string) and [GCC documentation](https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html) must be used to understand the semantics.

Note that some breaking changes to input constraints are planned with [issue #215](https://github.com/ziglang/zig/issues/215).

{#header\_close#} {#header\_open|Clobbers#}

Clobbers are the set of registers whose values will not be preserved by the execution of the assembly code. These do not include output or input registers. The special clobber value of {#syntax#}"memory"{#endsyntax#} means that the assembly causes writes to arbitrary undeclared memory locations - not only the memory pointed to by a declared indirect output.

Failure to declare the full set of clobbers for a given inline assembly expression is unchecked {#link|Illegal Behavior#}.

{#header\_close#} {#header\_open|Global Assembly#}

When an assembly expression occurs in a {#link|container|Containers#} level {#link|comptime#} block, this is **global assembly**.

This kind of assembly has different rules than inline assembly. First, {#syntax#}volatile{#endsyntax#} is not valid because all global assembly is unconditionally included. Second, there are no inputs, outputs, or clobbers. All global assembly is concatenated verbatim into one long string and assembled together. There are no template substitution rules regarding `%` as there are in inline assembly expressions.

{#code|test\_global\_assembly.zig#} {#header\_close#} {#header\_close#} {#header\_open|Atomics#}

TODO: @atomic rmw

TODO: builtin atomic memory ordering enum

{#see\_also|@atomicLoad|@atomicStore|@atomicRmw|@cmpxchgWeak|@cmpxchgStrong#} {#header\_close#} {#header\_open|Async Functions#}

Async functions regressed with the release of 0.11.0. The current plan is to reintroduce them as a lower level primitive that powers I/O implementations.

Tracking issue: [Proposal: stackless coroutines as low-level primitives](https://github.com/ziglang/zig/issues/23446)

{#header\_close#} {#header\_open|Builtin Functions|2col#}

Builtin functions are provided by the compiler and are prefixed with `@`. The {#syntax#}comptime{#endsyntax#} keyword on a parameter means that the parameter must be known at compile time.

{#header\_open|@addrSpaceCast#}

{#syntax#}@addrSpaceCast(ptr: anytype) anytype{#endsyntax#}

Converts a pointer from one address space to another. The new address space is inferred based on the result type. Depending on the current target and address spaces, this cast may be a no-op, a complex operation, or illegal. If the cast is legal, then the resulting pointer points to the same memory location as the pointer operand. It is always valid to cast a pointer between the same address spaces.

{#header\_close#} {#header\_open|@addWithOverflow#}

{#syntax#}@addWithOverflow(a: anytype, b: anytype) struct { @TypeOf(a, b), u1 }{#endsyntax#}

Performs {#syntax#}a + b{#endsyntax#} and returns a tuple with the result and a possible overflow bit.

{#header\_close#} {#header\_open|@alignCast#}

{#syntax#}@alignCast(ptr: anytype) anytype{#endsyntax#}

{#syntax#}ptr{#endsyntax#} can be {#syntax#}\*T{#endsyntax#}, {#syntax#}?\*T{#endsyntax#}, or {#syntax#}\[\]T{#endsyntax#}. Changes the alignment of a pointer. The alignment to use is inferred based on the result type.

A {#link|pointer alignment safety check|Incorrect Pointer Alignment#} is added to the generated code to make sure the pointer is aligned as promised.

{#header\_close#} {#header\_open|@alignOf#}

{#syntax#}@alignOf(comptime T: type) comptime\_int{#endsyntax#}

This function returns the number of bytes that this type should be aligned to for the current target to match the C ABI. When the child type of a pointer has this alignment, the alignment can be omitted from the type.

{#syntax#}const assert = @import("std").debug.assert;
comptime {
    assert(\*u32 == \*align(@alignOf(u32)) u32);
}{#endsyntax#}

The result is a target-specific compile time constant. It is guaranteed to be less than or equal to {#link|@sizeOf(T)|@sizeOf#}.

{#see\_also|Alignment#} {#header\_close#} {#header\_open|@as#}

{#syntax#}@as(comptime T: type, expression) T{#endsyntax#}

Performs {#link|Type Coercion#}. This cast is allowed when the conversion is unambiguous and safe, and is the preferred way to convert between types, whenever possible.

{#header\_close#} {#header\_open|@atomicLoad#}

{#syntax#}@atomicLoad(comptime T: type, ptr: \*const T, comptime ordering: AtomicOrder) T{#endsyntax#}

This builtin function atomically dereferences a pointer to a {#syntax#}T{#endsyntax#} and returns the value.

{#syntax#}T{#endsyntax#} must be a pointer, a {#syntax#}bool{#endsyntax#}, a float, an integer, an enum, or a packed struct.

{#syntax#}AtomicOrder{#endsyntax#} can be found with {#syntax#}@import("std").builtin.AtomicOrder{#endsyntax#}.

{#see\_also|@atomicStore|@atomicRmw||@cmpxchgWeak|@cmpxchgStrong#} {#header\_close#} {#header\_open|@atomicRmw#}

{#syntax#}@atomicRmw(comptime T: type, ptr: \*T, comptime op: AtomicRmwOp, operand: T, comptime ordering: AtomicOrder) T{#endsyntax#}

This builtin function dereferences a pointer to a {#syntax#}T{#endsyntax#} and atomically modifies the value and returns the previous value.

{#syntax#}T{#endsyntax#} must be a pointer, a {#syntax#}bool{#endsyntax#}, a float, an integer, an enum, or a packed struct.

{#syntax#}AtomicOrder{#endsyntax#} can be found with {#syntax#}@import("std").builtin.AtomicOrder{#endsyntax#}.

{#syntax#}AtomicRmwOp{#endsyntax#} can be found with {#syntax#}@import("std").builtin.AtomicRmwOp{#endsyntax#}.

{#see\_also|@atomicStore|@atomicLoad|@cmpxchgWeak|@cmpxchgStrong#} {#header\_close#} {#header\_open|@atomicStore#}

{#syntax#}@atomicStore(comptime T: type, ptr: \*T, value: T, comptime ordering: AtomicOrder) void{#endsyntax#}

This builtin function dereferences a pointer to a {#syntax#}T{#endsyntax#} and atomically stores the given value.

{#syntax#}T{#endsyntax#} must be a pointer, a {#syntax#}bool{#endsyntax#}, a float, an integer, an enum, or a packed struct.

{#syntax#}AtomicOrder{#endsyntax#} can be found with {#syntax#}@import("std").builtin.AtomicOrder{#endsyntax#}.

{#see\_also|@atomicLoad|@atomicRmw|@cmpxchgWeak|@cmpxchgStrong#} {#header\_close#} {#header\_open|@bitCast#}

{#syntax#}@bitCast(value: anytype) anytype{#endsyntax#}

Converts a value of one type to another type. The return type is the inferred result type.

Asserts that {#syntax#}@sizeOf(@TypeOf(value)) == @sizeOf(DestType){#endsyntax#}.

Asserts that {#syntax#}@typeInfo(DestType) != .pointer{#endsyntax#}. Use {#syntax#}@ptrCast{#endsyntax#} or {#syntax#}@ptrFromInt{#endsyntax#} if you need this.

Can be used for these things for example:

*   Convert {#syntax#}f32{#endsyntax#} to {#syntax#}u32{#endsyntax#} bits
*   Convert {#syntax#}i32{#endsyntax#} to {#syntax#}u32{#endsyntax#} preserving twos complement

Works at compile-time if {#syntax#}value{#endsyntax#} is known at compile time. It's a compile error to bitcast a value of undefined layout; this means that, besides the restriction from types which possess dedicated casting builtins (enums, pointers, error sets), bare structs, error unions, slices, optionals, and any other type without a well-defined memory layout, also cannot be used in this operation.

{#header\_close#} {#header\_open|@bitOffsetOf#}

{#syntax#}@bitOffsetOf(comptime T: type, comptime field\_name: \[\]const u8) comptime\_int{#endsyntax#}

Returns the bit offset of a field relative to its containing struct.

For non {#link|packed structs|packed struct#}, this will always be divisible by {#syntax#}8{#endsyntax#}. For packed structs, non-byte-aligned fields will share a byte offset, but they will have different bit offsets.

{#see\_also|@offsetOf#} {#header\_close#} {#header\_open|@bitSizeOf#}

{#syntax#}@bitSizeOf(comptime T: type) comptime\_int{#endsyntax#}

This function returns the number of bits it takes to store {#syntax#}T{#endsyntax#} in memory if the type were a field in a packed struct/union. The result is a target-specific compile time constant.

This function measures the size at runtime. For types that are disallowed at runtime, such as {#syntax#}comptime\_int{#endsyntax#} and {#syntax#}type{#endsyntax#}, the result is {#syntax#}0{#endsyntax#}.

{#see\_also|@sizeOf|@typeInfo#} {#header\_close#} {#header\_open|@branchHint#}

{#syntax#}@branchHint(hint: BranchHint) void{#endsyntax#}

Hints to the optimizer how likely a given branch of control flow is to be reached.

{#syntax#}BranchHint{#endsyntax#} can be found with {#syntax#}@import("std").builtin.BranchHint{#endsyntax#}.

This function is only valid as the first statement in a control flow branch, or the first statement in a function.

{#header\_close#} {#header\_open|@breakpoint#}

{#syntax#}@breakpoint() void{#endsyntax#}

This function inserts a platform-specific debug trap instruction which causes debuggers to break there. Unlike for {#syntax#}@trap(){#endsyntax#}, execution may continue after this point if the program is resumed.

This function is only valid within function scope.

{#see\_also|@trap#} {#header\_close#} {#header\_open|@mulAdd#}

{#syntax#}@mulAdd(comptime T: type, a: T, b: T, c: T) T{#endsyntax#}

Fused multiply-add, similar to {#syntax#}(a \* b) + c{#endsyntax#}, except only rounds once, and is thus more accurate.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@byteSwap#}

{#syntax#}@byteSwap(operand: anytype) T{#endsyntax#}

{#syntax#}@TypeOf(operand){#endsyntax#} must be an integer type or an integer vector type with bit count evenly divisible by 8.

{#syntax#}operand{#endsyntax#} may be an {#link|integer|Integers#} or {#link|vector|Vectors#}.

Swaps the byte order of the integer. This converts a big endian integer to a little endian integer, and converts a little endian integer to a big endian integer.

Note that for the purposes of memory layout with respect to endianness, the integer type should be related to the number of bytes reported by {#link|@sizeOf#} bytes. This is demonstrated with {#syntax#}u24{#endsyntax#}. {#syntax#}@sizeOf(u24) == 4{#endsyntax#}, which means that a {#syntax#}u24{#endsyntax#} stored in memory takes 4 bytes, and those 4 bytes are what are swapped on a little vs big endian system. On the other hand, if {#syntax#}T{#endsyntax#} is specified to be {#syntax#}u24{#endsyntax#}, then only 3 bytes are reversed.

{#header\_close#} {#header\_open|@bitReverse#}

{#syntax#}@bitReverse(integer: anytype) T{#endsyntax#}

{#syntax#}@TypeOf(anytype){#endsyntax#} accepts any integer type or integer vector type.

Reverses the bitpattern of an integer value, including the sign bit if applicable.

For example 0b10110110 ({#syntax#}u8 = 182{#endsyntax#}, {#syntax#}i8 = -74{#endsyntax#}) becomes 0b01101101 ({#syntax#}u8 = 109{#endsyntax#}, {#syntax#}i8 = 109{#endsyntax#}).

{#header\_close#} {#header\_open|@offsetOf#}

{#syntax#}@offsetOf(comptime T: type, comptime field\_name: \[\]const u8) comptime\_int{#endsyntax#}

Returns the byte offset of a field relative to its containing struct.

{#see\_also|@bitOffsetOf#} {#header\_close#} {#header\_open|@call#}

{#syntax#}@call(modifier: std.builtin.CallModifier, function: anytype, args: anytype) anytype{#endsyntax#}

Calls a function, in the same way that invoking an expression with parentheses does:

{#code|test\_call\_builtin.zig#}

{#syntax#}@call{#endsyntax#} allows more flexibility than normal function call syntax does. The {#syntax#}CallModifier{#endsyntax#} enum is reproduced here:

{#code|builtin.CallModifier struct.zig#} {#header\_close#} {#header\_open|@cDefine#}

{#syntax#}@cDefine(comptime name: \[\]const u8, value) void{#endsyntax#}

This function can only occur inside {#syntax#}@cImport{#endsyntax#}.

This appends `#define $name $value` to the {#syntax#}@cImport{#endsyntax#} temporary buffer.

To define without a value, like this:

    #define _GNU_SOURCE

Use the void value, like this:

{#syntax#}@cDefine("\_GNU\_SOURCE", {}){#endsyntax#}

{#see\_also|Import from C Header File|@cInclude|@cImport|@cUndef|void#} {#header\_close#} {#header\_open|@cImport#}

{#syntax#}@cImport(expression) type{#endsyntax#}

This function parses C code and imports the functions, types, variables, and compatible macro definitions into a new empty struct type, and then returns that type.

{#syntax#}expression{#endsyntax#} is interpreted at compile time. The builtin functions {#syntax#}@cInclude{#endsyntax#}, {#syntax#}@cDefine{#endsyntax#}, and {#syntax#}@cUndef{#endsyntax#} work within this expression, appending to a temporary buffer which is then parsed as C code.

Usually you should only have one {#syntax#}@cImport{#endsyntax#} in your entire application, because it saves the compiler from invoking clang multiple times, and prevents inline functions from being duplicated.

Reasons for having multiple {#syntax#}@cImport{#endsyntax#} expressions would be:

*   To avoid a symbol collision, for example if foo.h and bar.h both `#define CONNECTION_COUNT`
*   To analyze the C code with different preprocessor defines

{#see\_also|Import from C Header File|@cInclude|@cDefine|@cUndef#} {#header\_close#} {#header\_open|@cInclude#}

{#syntax#}@cInclude(comptime path: \[\]const u8) void{#endsyntax#}

This function can only occur inside {#syntax#}@cImport{#endsyntax#}.

This appends `#include <$path>\n` to the {#syntax#}c\_import{#endsyntax#} temporary buffer.

{#see\_also|Import from C Header File|@cImport|@cDefine|@cUndef#} {#header\_close#} {#header\_open|@clz#}

{#syntax#}@clz(operand: anytype) anytype{#endsyntax#}

{#syntax#}@TypeOf(operand){#endsyntax#} must be an integer type or an integer vector type.

{#syntax#}operand{#endsyntax#} may be an {#link|integer|Integers#} or {#link|vector|Vectors#}.

Counts the number of most-significant (leading in a big-endian sense) zeroes in an integer - "count leading zeroes".

The return type is an unsigned integer or vector of unsigned integers with the minimum number of bits that can represent the bit count of the integer type.

If {#syntax#}operand{#endsyntax#} is zero, {#syntax#}@clz{#endsyntax#} returns the bit width of integer type {#syntax#}T{#endsyntax#}.

{#see\_also|@ctz|@popCount#} {#header\_close#} {#header\_open|@cmpxchgStrong#}

{#syntax#}@cmpxchgStrong(comptime T: type, ptr: \*T, expected\_value: T, new\_value: T, success\_order: AtomicOrder, fail\_order: AtomicOrder) ?T{#endsyntax#}

This function performs a strong atomic compare-and-exchange operation, returning {#syntax#}null{#endsyntax#} if the current value is the given expected value. It's the equivalent of this code, except atomic:

{#code|not\_atomic\_cmpxchgStrong.zig#}

If you are using cmpxchg in a retry loop, {#link|@cmpxchgWeak#} is the better choice, because it can be implemented more efficiently in machine instructions.

{#syntax#}T{#endsyntax#} must be a pointer, a {#syntax#}bool{#endsyntax#}, an integer, an enum, or a packed struct.

{#syntax#}@typeInfo(@TypeOf(ptr)).pointer.alignment{#endsyntax#} must be {#syntax#}>= @sizeOf(T).{#endsyntax#}

{#syntax#}AtomicOrder{#endsyntax#} can be found with {#syntax#}@import("std").builtin.AtomicOrder{#endsyntax#}.

{#see\_also|@atomicStore|@atomicLoad|@atomicRmw|@cmpxchgWeak#} {#header\_close#} {#header\_open|@cmpxchgWeak#}

{#syntax#}@cmpxchgWeak(comptime T: type, ptr: \*T, expected\_value: T, new\_value: T, success\_order: AtomicOrder, fail\_order: AtomicOrder) ?T{#endsyntax#}

This function performs a weak atomic compare-and-exchange operation, returning {#syntax#}null{#endsyntax#} if the current value is the given expected value. It's the equivalent of this code, except atomic:

{#syntax\_block|zig|cmpxchgWeakButNotAtomic#} fn cmpxchgWeakButNotAtomic(comptime T: type, ptr: \*T, expected\_value: T, new\_value: T) ?T { const old\_value = ptr.\*; if (old\_value == expected\_value and usuallyTrueButSometimesFalse()) { ptr.\* = new\_value; return null; } else { return old\_value; } } {#end\_syntax\_block#}

If you are using cmpxchg in a retry loop, the sporadic failure will be no problem, and {#syntax#}cmpxchgWeak{#endsyntax#} is the better choice, because it can be implemented more efficiently in machine instructions. However if you need a stronger guarantee, use {#link|@cmpxchgStrong#}.

{#syntax#}T{#endsyntax#} must be a pointer, a {#syntax#}bool{#endsyntax#}, an integer, an enum, or a packed struct.

{#syntax#}@typeInfo(@TypeOf(ptr)).pointer.alignment{#endsyntax#} must be {#syntax#}>= @sizeOf(T).{#endsyntax#}

{#syntax#}AtomicOrder{#endsyntax#} can be found with {#syntax#}@import("std").builtin.AtomicOrder{#endsyntax#}.

{#see\_also|@atomicStore|@atomicLoad|@atomicRmw|@cmpxchgStrong#} {#header\_close#} {#header\_open|@compileError#}

{#syntax#}@compileError(comptime msg: \[\]const u8) noreturn{#endsyntax#}

This function, when semantically analyzed, causes a compile error with the message {#syntax#}msg{#endsyntax#}.

There are several ways that code avoids being semantically checked, such as using {#syntax#}if{#endsyntax#} or {#syntax#}switch{#endsyntax#} with compile time constants, and {#syntax#}comptime{#endsyntax#} functions.

{#header\_close#} {#header\_open|@compileLog#}

{#syntax#}@compileLog(...) void{#endsyntax#}

This function prints the arguments passed to it at compile-time.

To prevent accidentally leaving compile log statements in a codebase, a compilation error is added to the build, pointing to the compile log statement. This error prevents code from being generated, but does not otherwise interfere with analysis.

This function can be used to do "printf debugging" on compile-time executing code.

{#code|test\_compileLog\_builtin.zig#} {#header\_close#} {#header\_open|@constCast#}

{#syntax#}@constCast(value: anytype) DestType{#endsyntax#}

Remove {#syntax#}const{#endsyntax#} qualifier from a pointer.

{#header\_close#} {#header\_open|@ctz#}

{#syntax#}@ctz(operand: anytype) anytype{#endsyntax#}

{#syntax#}@TypeOf(operand){#endsyntax#} must be an integer type or an integer vector type.

{#syntax#}operand{#endsyntax#} may be an {#link|integer|Integers#} or {#link|vector|Vectors#}.

Counts the number of least-significant (trailing in a big-endian sense) zeroes in an integer - "count trailing zeroes".

The return type is an unsigned integer or vector of unsigned integers with the minimum number of bits that can represent the bit count of the integer type.

If {#syntax#}operand{#endsyntax#} is zero, {#syntax#}@ctz{#endsyntax#} returns the bit width of integer type {#syntax#}T{#endsyntax#}.

{#see\_also|@clz|@popCount#} {#header\_close#} {#header\_open|@cUndef#}

{#syntax#}@cUndef(comptime name: \[\]const u8) void{#endsyntax#}

This function can only occur inside {#syntax#}@cImport{#endsyntax#}.

This appends `#undef $name` to the {#syntax#}@cImport{#endsyntax#} temporary buffer.

{#see\_also|Import from C Header File|@cImport|@cDefine|@cInclude#} {#header\_close#} {#header\_open|@cVaArg#}

{#syntax#}@cVaArg(operand: \*std.builtin.VaList, comptime T: type) T{#endsyntax#}

Implements the C macro {#syntax#}va\_arg{#endsyntax#}.

{#see\_also|@cVaCopy|@cVaEnd|@cVaStart#} {#header\_close#} {#header\_open|@cVaCopy#}

{#syntax#}@cVaCopy(src: \*std.builtin.VaList) std.builtin.VaList{#endsyntax#}

Implements the C macro {#syntax#}va\_copy{#endsyntax#}.

{#see\_also|@cVaArg|@cVaEnd|@cVaStart#} {#header\_close#} {#header\_open|@cVaEnd#}

{#syntax#}@cVaEnd(src: \*std.builtin.VaList) void{#endsyntax#}

Implements the C macro {#syntax#}va\_end{#endsyntax#}.

{#see\_also|@cVaArg|@cVaCopy|@cVaStart#} {#header\_close#} {#header\_open|@cVaStart#}

{#syntax#}@cVaStart() std.builtin.VaList{#endsyntax#}

Implements the C macro {#syntax#}va\_start{#endsyntax#}. Only valid inside a variadic function.

{#see\_also|@cVaArg|@cVaCopy|@cVaEnd#} {#header\_close#} {#header\_open|@divExact#}

{#syntax#}@divExact(numerator: T, denominator: T) T{#endsyntax#}

Exact division. Caller guarantees {#syntax#}denominator != 0{#endsyntax#} and {#syntax#}@divTrunc(numerator, denominator) \* denominator == numerator{#endsyntax#}.

*   {#syntax#}@divExact(6, 3) == 2{#endsyntax#}
*   {#syntax#}@divExact(a, b) \* b == a{#endsyntax#}

For a function that returns a possible error code, use {#syntax#}@import("std").math.divExact{#endsyntax#}.

{#see\_also|@divTrunc|@divFloor#} {#header\_close#} {#header\_open|@divFloor#}

{#syntax#}@divFloor(numerator: T, denominator: T) T{#endsyntax#}

Floored division. Rounds toward negative infinity. For unsigned integers it is the same as {#syntax#}numerator / denominator{#endsyntax#}. Caller guarantees {#syntax#}denominator != 0{#endsyntax#} and {#syntax#}!(@typeInfo(T) == .int and T.is\_signed and numerator == std.math.minInt(T) and denominator == -1){#endsyntax#}.

*   {#syntax#}@divFloor(-5, 3) == -2{#endsyntax#}
*   {#syntax#}(@divFloor(a, b) \* b) + @mod(a, b) == a{#endsyntax#}

For a function that returns a possible error code, use {#syntax#}@import("std").math.divFloor{#endsyntax#}.

{#see\_also|@divTrunc|@divExact#} {#header\_close#} {#header\_open|@divTrunc#}

{#syntax#}@divTrunc(numerator: T, denominator: T) T{#endsyntax#}

Truncated division. Rounds toward zero. For unsigned integers it is the same as {#syntax#}numerator / denominator{#endsyntax#}. Caller guarantees {#syntax#}denominator != 0{#endsyntax#} and {#syntax#}!(@typeInfo(T) == .int and T.is\_signed and numerator == std.math.minInt(T) and denominator == -1){#endsyntax#}.

*   {#syntax#}@divTrunc(-5, 3) == -1{#endsyntax#}
*   {#syntax#}(@divTrunc(a, b) \* b) + @rem(a, b) == a{#endsyntax#}

For a function that returns a possible error code, use {#syntax#}@import("std").math.divTrunc{#endsyntax#}.

{#see\_also|@divFloor|@divExact#} {#header\_close#} {#header\_open|@embedFile#}

{#syntax#}@embedFile(comptime path: \[\]const u8) \*const \[N:0\]u8{#endsyntax#}

This function returns a compile time constant pointer to null-terminated, fixed-size array with length equal to the byte count of the file given by {#syntax#}path{#endsyntax#}. The contents of the array are the contents of the file. This is equivalent to a {#link|string literal|String Literals and Unicode Code Point Literals#} with the file contents.

{#syntax#}path{#endsyntax#} is absolute or relative to the current file, just like {#syntax#}@import{#endsyntax#}.

{#see\_also|@import#} {#header\_close#} {#header\_open|@enumFromInt#}

{#syntax#}@enumFromInt(integer: anytype) anytype{#endsyntax#}

Converts an integer into an {#link|enum#} value. The return type is the inferred result type.

Attempting to convert an integer with no corresponding value in the enum invokes safety-checked {#link|Illegal Behavior#}. Note that a {#link|non-exhaustive enum|Non-exhaustive enum#} has corresponding values for all integers in the enum's integer tag type: the {#syntax#}\_{#endsyntax#} value represents all the remaining unnamed integers in the enum's tag type.

{#see\_also|@intFromEnum#} {#header\_close#} {#header\_open|@errorFromInt#}

{#syntax#}@errorFromInt(value: std.meta.Int(.unsigned, @bitSizeOf(anyerror))) anyerror{#endsyntax#}

Converts from the integer representation of an error into {#link|The Global Error Set#} type.

It is generally recommended to avoid this cast, as the integer representation of an error is not stable across source code changes.

Attempting to convert an integer that does not correspond to any error results in safety-checked {#link|Illegal Behavior#}.

{#see\_also|@intFromError#} {#header\_close#} {#header\_open|@errorName#}

{#syntax#}@errorName(err: anyerror) \[:0\]const u8{#endsyntax#}

This function returns the string representation of an error. The string representation of {#syntax#}error.OutOfMem{#endsyntax#} is {#syntax#}"OutOfMem"{#endsyntax#}.

If there are no calls to {#syntax#}@errorName{#endsyntax#} in an entire application, or all calls have a compile-time known value for {#syntax#}err{#endsyntax#}, then no error name table will be generated.

{#header\_close#} {#header\_open|@errorReturnTrace#}

{#syntax#}@errorReturnTrace() ?\*builtin.StackTrace{#endsyntax#}

If the binary is built with error return tracing, and this function is invoked in a function that calls a function with an error or error union return type, returns a stack trace object. Otherwise returns {#link|null#}.

{#header\_close#} {#header\_open|@errorCast#}

{#syntax#}@errorCast(value: anytype) anytype{#endsyntax#}

Converts an error set or error union value from one error set to another error set. The return type is the inferred result type. Attempting to convert an error which is not in the destination error set results in safety-checked {#link|Illegal Behavior#}.

{#header\_close#} {#header\_open|@export#}

{#syntax#}@export(comptime ptr: \*const anyopaque, comptime options: std.builtin.ExportOptions) void{#endsyntax#}

Creates a symbol in the output object file which refers to the target of `ptr`.

`ptr` must point to a global variable or a comptime-known constant.

This builtin can be called from a {#link|comptime#} block to conditionally export symbols. When `ptr` points to a function with the C calling convention and {#syntax#}options.linkage{#endsyntax#} is {#syntax#}.strong{#endsyntax#}, this is equivalent to the {#syntax#}export{#endsyntax#} keyword used on a function:

{#code|export\_builtin.zig#}

This is equivalent to:

{#code|export\_builtin\_equivalent\_code.zig#}

Note that even when using {#syntax#}export{#endsyntax#}, the {#syntax#}@"foo"{#endsyntax#} syntax for {#link|identifiers|Identifiers#} can be used to choose any string for the symbol name:

{#code|export\_any\_symbol\_name.zig#}

When looking at the resulting object, you can see the symbol is used verbatim:

    00000000000001f0 T A function name that is a complete sentence.

{#see\_also|Exporting a C Library#} {#header\_close#} {#header\_open|@extern#}

{#syntax#}@extern(T: type, comptime options: std.builtin.ExternOptions) T{#endsyntax#}

Creates a reference to an external symbol in the output object file. T must be a pointer type.

{#see\_also|@export#} {#header\_close#} {#header\_open|@field#}

{#syntax#}@field(lhs: anytype, comptime field\_name: \[\]const u8) (field){#endsyntax#}

Performs field access by a compile-time string. Works on both fields and declarations.

{#code|test\_field\_builtin.zig#} {#header\_close#} {#header\_open|@fieldParentPtr#}

{#syntax#}@fieldParentPtr(comptime field\_name: \[\]const u8, field\_ptr: \*T) anytype{#endsyntax#}

Given a pointer to a struct or union field, returns a pointer to the struct or union containing that field. The return type (pointer to the parent struct or union in question) is the inferred result type.

If {#syntax#}field\_ptr{#endsyntax#} does not point to the {#syntax#}field\_name{#endsyntax#} field of an instance of the result type, and the result type has ill-defined layout, invokes unchecked {#link|Illegal Behavior#}.

{#header\_close#} {#header\_open|@FieldType#}

{#syntax#}@FieldType(comptime Type: type, comptime field\_name: \[\]const u8) type{#endsyntax#}

Given a type and the name of one of its fields, returns the type of that field.

{#header\_close#} {#header\_open|@floatCast#}

{#syntax#}@floatCast(value: anytype) anytype{#endsyntax#}

Convert from one float type to another. This cast is safe, but may cause the numeric value to lose precision. The return type is the inferred result type.

{#header\_close#} {#header\_open|@floatFromInt#}

{#syntax#}@floatFromInt(int: anytype) anytype{#endsyntax#}

Converts an integer to the closest floating point representation. The return type is the inferred result type. To convert the other way, use {#link|@intFromFloat#}. This operation is legal for all values of all integer types.

{#header\_close#} {#header\_open|@frameAddress#}

{#syntax#}@frameAddress() usize{#endsyntax#}

This function returns the base pointer of the current stack frame.

The implications of this are target-specific and not consistent across all platforms. The frame address may not be available in release mode due to aggressive optimizations.

This function is only valid within function scope.

{#header\_close#} {#header\_open|@hasDecl#}

{#syntax#}@hasDecl(comptime Container: type, comptime name: \[\]const u8) bool{#endsyntax#}

Returns whether or not a {#link|container|Containers#} has a declaration matching {#syntax#}name{#endsyntax#}.

{#code|test\_hasDecl\_builtin.zig#} {#see\_also|@hasField#} {#header\_close#} {#header\_open|@hasField#}

{#syntax#}@hasField(comptime Container: type, comptime name: \[\]const u8) bool{#endsyntax#}

Returns whether the field name of a struct, union, or enum exists.

The result is a compile time constant.

It does not include functions, variables, or constants.

{#see\_also|@hasDecl#} {#header\_close#} {#header\_open|@import#}

{#syntax#}@import(comptime target: \[\]const u8) anytype{#endsyntax#}

Imports the file at {#syntax#}target{#endsyntax#}, adding it to the compilation if it is not already added. {#syntax#}target{#endsyntax#} is either a relative path to another file from the file containing the {#syntax#}@import{#endsyntax#} call, or it is the name of a {#link|module|Compilation Model#}, with the import referring to the root source file of that module. Either way, the file path must end in either `.zig` (for a Zig source file) or `.zon` (for a ZON data file).

If {#syntax#}target{#endsyntax#} refers to a Zig source file, then {#syntax#}@import{#endsyntax#} returns that file's {#link|corresponding struct type|Source File Structs#}, essentially as if the builtin call was replaced by {#syntax#}struct { FILE\_CONTENTS }{#endsyntax#}. The return type is {#syntax#}type{#endsyntax#}.

If {#syntax#}target{#endsyntax#} refers to a ZON file, then {#syntax#}@import{#endsyntax#} returns the value of the literal in the file. If there is an inferred {#link|result type|Result Types#}, then the return type is that type, and the ZON literal is interpreted as that type ({#link|Result Types#} are propagated through the ZON expression). Otherwise, the return type is the type of the equivalent Zig expression, essentially as if the builtin call was replaced by the ZON file contents.

The following modules are always available for import:

*   {#syntax#}@import("std"){#endsyntax#} - Zig Standard Library
*   {#syntax#}@import("builtin"){#endsyntax#} - Target-specific information. The command `zig build-exe --show-builtin` outputs the source to stdout for reference.
*   {#syntax#}@import("root"){#endsyntax#} - Alias for the root module. In typical project structures, this means it refers back to `src/main.zig`.

{#see\_also|Compile Variables|@embedFile#} {#header\_close#} {#header\_open|@inComptime#}

{#syntax#}@inComptime() bool{#endsyntax#}

Returns whether the builtin was run in a {#syntax#}comptime{#endsyntax#} context. The result is a compile-time constant.

This can be used to provide alternative, comptime-friendly implementations of functions. It should not be used, for instance, to exclude certain functions from being evaluated at comptime.

{#see\_also|comptime#} {#header\_close#} {#header\_open|@intCast#}

{#syntax#}@intCast(int: anytype) anytype{#endsyntax#}

Converts an integer to another integer while keeping the same numerical value. The return type is the inferred result type. Attempting to convert a number which is out of range of the destination type results in safety-checked {#link|Illegal Behavior#}.

{#code|test\_intCast\_builtin.zig#}

To truncate the significant bits of a number out of range of the destination type, use {#link|@truncate#}.

If {#syntax#}T{#endsyntax#} is {#syntax#}comptime\_int{#endsyntax#}, then this is semantically equivalent to {#link|Type Coercion#}.

{#header\_close#} {#header\_open|@intFromBool#}

{#syntax#}@intFromBool(value: bool) u1{#endsyntax#}

Converts {#syntax#}true{#endsyntax#} to {#syntax#}@as(u1, 1){#endsyntax#} and {#syntax#}false{#endsyntax#} to {#syntax#}@as(u1, 0){#endsyntax#}.

{#header\_close#} {#header\_open|@intFromEnum#}

{#syntax#}@intFromEnum(enum\_or\_tagged\_union: anytype) anytype{#endsyntax#}

Converts an enumeration value into its integer tag type. When a tagged union is passed, the tag value is used as the enumeration value.

If there is only one possible enum value, the result is a {#syntax#}comptime\_int{#endsyntax#} known at {#link|comptime#}.

{#see\_also|@enumFromInt#} {#header\_close#} {#header\_open|@intFromError#}

{#syntax#}@intFromError(err: anytype) std.meta.Int(.unsigned, @bitSizeOf(anyerror)){#endsyntax#}

Supports the following types:

*   {#link|The Global Error Set#}
*   {#link|Error Set Type#}
*   {#link|Error Union Type#}

Converts an error to the integer representation of an error.

It is generally recommended to avoid this cast, as the integer representation of an error is not stable across source code changes.

{#see\_also|@errorFromInt#} {#header\_close#} {#header\_open|@intFromFloat#}

{#syntax#}@intFromFloat(float: anytype) anytype{#endsyntax#}

Converts the integer part of a floating point number to the inferred result type.

If the integer part of the floating point number cannot fit in the destination type, it invokes safety-checked {#link|Illegal Behavior#}.

{#see\_also|@floatFromInt#} {#header\_close#} {#header\_open|@intFromPtr#}

{#syntax#}@intFromPtr(value: anytype) usize{#endsyntax#}

Converts {#syntax#}value{#endsyntax#} to a {#syntax#}usize{#endsyntax#} which is the address of the pointer. {#syntax#}value{#endsyntax#} can be {#syntax#}\*T{#endsyntax#} or {#syntax#}?\*T{#endsyntax#}.

To convert the other way, use {#link|@ptrFromInt#}

{#header\_close#} {#header\_open|@max#}

{#syntax#}@max(...) T{#endsyntax#}

Takes two or more arguments and returns the biggest value included (the maximum). This builtin accepts integers, floats, and vectors of either. In the latter case, the operation is performed element wise.

NaNs are handled as follows: return the biggest non-NaN value included. If all operands are NaN, return NaN.

{#see\_also|@min|Vectors#} {#header\_close#} {#header\_open|@memcpy#}

{#syntax#}@memcpy(noalias dest, noalias source) void{#endsyntax#}

This function copies bytes from one region of memory to another.

{#syntax#}dest{#endsyntax#} must be a mutable slice, a mutable pointer to an array, or a mutable many-item {#link|pointer|Pointers#}. It may have any alignment, and it may have any element type.

{#syntax#}source{#endsyntax#} must be a slice, a pointer to an array, or a many-item {#link|pointer|Pointers#}. It may have any alignment, and it may have any element type.

The {#syntax#}source{#endsyntax#} element type must have the same in-memory representation as the {#syntax#}dest{#endsyntax#} element type.

Similar to {#link|for#} loops, at least one of {#syntax#}source{#endsyntax#} and {#syntax#}dest{#endsyntax#} must provide a length, and if two lengths are provided, they must be equal.

Finally, the two memory regions must not overlap.

{#header\_close#} {#header\_open|@memset#}

{#syntax#}@memset(dest, elem) void{#endsyntax#}

This function sets all the elements of a memory region to {#syntax#}elem{#endsyntax#}.

{#syntax#}dest{#endsyntax#} must be a mutable slice or a mutable pointer to an array. It may have any alignment, and it may have any element type.

{#syntax#}elem{#endsyntax#} is coerced to the element type of {#syntax#}dest{#endsyntax#}.

For securely zeroing out sensitive contents from memory, you should use {#syntax#}std.crypto.secureZero{#endsyntax#}

{#header\_close#} {#header\_open|@memmove#}

{#syntax#}@memmove(dest, source) void{#endsyntax#}

This function copies bytes from one region of memory to another, but unlike {#link|@memcpy#} the regions may overlap.

{#syntax#}dest{#endsyntax#} must be a mutable slice, a mutable pointer to an array, or a mutable many-item {#link|pointer|Pointers#}. It may have any alignment, and it may have any element type.

{#syntax#}source{#endsyntax#} must be a slice, a pointer to an array, or a many-item {#link|pointer|Pointers#}. It may have any alignment, and it may have any element type.

The {#syntax#}source{#endsyntax#} element type must have the same in-memory representation as the {#syntax#}dest{#endsyntax#} element type.

Similar to {#link|for#} loops, at least one of {#syntax#}source{#endsyntax#} and {#syntax#}dest{#endsyntax#} must provide a length, and if two lengths are provided, they must be equal.

{#header\_close#} {#header\_open|@min#}

{#syntax#}@min(...) T{#endsyntax#}

Takes two or more arguments and returns the smallest value included (the minimum). This builtin accepts integers, floats, and vectors of either. In the latter case, the operation is performed element wise.

NaNs are handled as follows: return the smallest non-NaN value included. If all operands are NaN, return NaN.

{#see\_also|@max|Vectors#} {#header\_close#} {#header\_open|@wasmMemorySize#}

{#syntax#}@wasmMemorySize(index: u32) usize{#endsyntax#}

This function returns the size of the Wasm memory identified by {#syntax#}index{#endsyntax#} as an unsigned value in units of Wasm pages. Note that each Wasm page is 64KB in size.

This function is a low level intrinsic with no safety mechanisms usually useful for allocator designers targeting Wasm. So unless you are writing a new allocator from scratch, you should use something like {#syntax#}@import("std").heap.WasmPageAllocator{#endsyntax#}.

{#see\_also|@wasmMemoryGrow#} {#header\_close#} {#header\_open|@wasmMemoryGrow#}

{#syntax#}@wasmMemoryGrow(index: u32, delta: usize) isize{#endsyntax#}

This function increases the size of the Wasm memory identified by {#syntax#}index{#endsyntax#} by {#syntax#}delta{#endsyntax#} in units of unsigned number of Wasm pages. Note that each Wasm page is 64KB in size. On success, returns previous memory size; on failure, if the allocation fails, returns -1.

This function is a low level intrinsic with no safety mechanisms usually useful for allocator designers targeting Wasm. So unless you are writing a new allocator from scratch, you should use something like {#syntax#}@import("std").heap.WasmPageAllocator{#endsyntax#}.

{#code|test\_wasmMemoryGrow\_builtin.zig#} {#see\_also|@wasmMemorySize#} {#header\_close#} {#header\_open|@mod#}

{#syntax#}@mod(numerator: T, denominator: T) T{#endsyntax#}

Modulus division. For unsigned integers this is the same as {#syntax#}numerator % denominator{#endsyntax#}. Caller guarantees {#syntax#}denominator != 0{#endsyntax#}, otherwise the operation will result in a {#link|Remainder Division by Zero#} when runtime safety checks are enabled.

*   {#syntax#}@mod(-5, 3) == 1{#endsyntax#}
*   {#syntax#}(@divFloor(a, b) \* b) + @mod(a, b) == a{#endsyntax#}

For a function that returns an error code, see {#syntax#}@import("std").math.mod{#endsyntax#}.

{#see\_also|@rem#} {#header\_close#} {#header\_open|@mulWithOverflow#}

{#syntax#}@mulWithOverflow(a: anytype, b: anytype) struct { @TypeOf(a, b), u1 }{#endsyntax#}

Performs {#syntax#}a \* b{#endsyntax#} and returns a tuple with the result and a possible overflow bit.

{#header\_close#} {#header\_open|@panic#}

{#syntax#}@panic(message: \[\]const u8) noreturn{#endsyntax#}

Invokes the panic handler function. By default the panic handler function calls the public {#syntax#}panic{#endsyntax#} function exposed in the root source file, or if there is not one specified, the {#syntax#}std.builtin.default\_panic{#endsyntax#} function from {#syntax#}std/builtin.zig{#endsyntax#}.

Generally it is better to use {#syntax#}@import("std").debug.panic{#endsyntax#}. However, {#syntax#}@panic{#endsyntax#} can be useful for 2 scenarios:

*   From library code, calling the programmer's panic function if they exposed one in the root source file.
*   When mixing C and Zig code, calling the canonical panic implementation across multiple .o files.

{#see\_also|Panic Handler#} {#header\_close#} {#header\_open|@popCount#}

{#syntax#}@popCount(operand: anytype) anytype{#endsyntax#}

{#syntax#}@TypeOf(operand){#endsyntax#} must be an integer type.

{#syntax#}operand{#endsyntax#} may be an {#link|integer|Integers#} or {#link|vector|Vectors#}.

Counts the number of bits set in an integer - "population count".

The return type is an unsigned integer or vector of unsigned integers with the minimum number of bits that can represent the bit count of the integer type.

{#see\_also|@ctz|@clz#} {#header\_close#} {#header\_open|@prefetch#}

{#syntax#}@prefetch(ptr: anytype, comptime options: PrefetchOptions) void{#endsyntax#}

This builtin tells the compiler to emit a prefetch instruction if supported by the target CPU. If the target CPU does not support the requested prefetch instruction, this builtin is a no-op. This function has no effect on the behavior of the program, only on the performance characteristics.

The {#syntax#}ptr{#endsyntax#} argument may be any pointer type and determines the memory address to prefetch. This function does not dereference the pointer, it is perfectly legal to pass a pointer to invalid memory to this function and no Illegal Behavior will result.

{#syntax#}PrefetchOptions{#endsyntax#} can be found with {#syntax#}@import("std").builtin.PrefetchOptions{#endsyntax#}.

{#header\_close#} {#header\_open|@ptrCast#}

{#syntax#}@ptrCast(value: anytype) anytype{#endsyntax#}

Converts a pointer of one type to a pointer of another type. The return type is the inferred result type.

{#link|Optional Pointers#} are allowed. Casting an optional pointer which is {#link|null#} to a non-optional pointer invokes safety-checked {#link|Illegal Behavior#}.

{#syntax#}@ptrCast{#endsyntax#} cannot be used for:

*   Removing {#syntax#}const{#endsyntax#} qualifier, use {#link|@constCast#}.
*   Removing {#syntax#}volatile{#endsyntax#} qualifier, use {#link|@volatileCast#}.
*   Changing pointer address space, use {#link|@addrSpaceCast#}.
*   Increasing pointer alignment, use {#link|@alignCast#}.
*   Casting a non-slice pointer to a slice, use slicing syntax {#syntax#}ptr\[start..end\]{#endsyntax#}.

{#header\_close#} {#header\_open|@ptrFromInt#}

{#syntax#}@ptrFromInt(address: usize) anytype{#endsyntax#}

Converts an integer to a {#link|pointer|Pointers#}. The return type is the inferred result type. To convert the other way, use {#link|@intFromPtr#}. Casting an address of 0 to a destination type which in not {#link|optional|Optional Pointers#} and does not have the {#syntax#}allowzero{#endsyntax#} attribute will result in a {#link|Pointer Cast Invalid Null#} panic when runtime safety checks are enabled.

If the destination pointer type does not allow address zero and {#syntax#}address{#endsyntax#} is zero, this invokes safety-checked {#link|Illegal Behavior#}.

{#header\_close#} {#header\_open|@rem#}

{#syntax#}@rem(numerator: T, denominator: T) T{#endsyntax#}

Remainder division. For unsigned integers this is the same as {#syntax#}numerator % denominator{#endsyntax#}. Caller guarantees {#syntax#}denominator != 0{#endsyntax#}, otherwise the operation will result in a {#link|Remainder Division by Zero#} when runtime safety checks are enabled.

*   {#syntax#}@rem(-5, 3) == -2{#endsyntax#}
*   {#syntax#}(@divTrunc(a, b) \* b) + @rem(a, b) == a{#endsyntax#}

For a function that returns an error code, see {#syntax#}@import("std").math.rem{#endsyntax#}.

{#see\_also|@mod#} {#header\_close#} {#header\_open|@returnAddress#}

{#syntax#}@returnAddress() usize{#endsyntax#}

This function returns the address of the next machine code instruction that will be executed when the current function returns.

The implications of this are target-specific and not consistent across all platforms.

This function is only valid within function scope. If the function gets inlined into a calling function, the returned address will apply to the calling function.

{#header\_close#} {#header\_open|@select#}

{#syntax#}@select(comptime T: type, pred: @Vector(len, bool), a: @Vector(len, T), b: @Vector(len, T)) @Vector(len, T){#endsyntax#}

Selects values element-wise from {#syntax#}a{#endsyntax#} or {#syntax#}b{#endsyntax#} based on {#syntax#}pred{#endsyntax#}. If {#syntax#}pred\[i\]{#endsyntax#} is {#syntax#}true{#endsyntax#}, the corresponding element in the result will be {#syntax#}a\[i\]{#endsyntax#} and otherwise {#syntax#}b\[i\]{#endsyntax#}.

{#see\_also|Vectors#} {#header\_close#} {#header\_open|@setEvalBranchQuota#}

{#syntax#}@setEvalBranchQuota(comptime new\_quota: u32) void{#endsyntax#}

Increase the maximum number of backwards branches that compile-time code execution can use before giving up and making a compile error.

If the {#syntax#}new\_quota{#endsyntax#} is smaller than the default quota ({#syntax#}1000{#endsyntax#}) or a previously explicitly set quota, it is ignored.

Example:

{#code|test\_without\_setEvalBranchQuota\_builtin.zig#}

Now we use {#syntax#}@setEvalBranchQuota{#endsyntax#}:

{#code|test\_setEvalBranchQuota\_builtin.zig#} {#see\_also|comptime#} {#header\_close#} {#header\_open|@setFloatMode#}

{#syntax#}@setFloatMode(comptime mode: FloatMode) void{#endsyntax#}

Changes the current scope's rules about how floating point operations are defined.

*   {#syntax#}Strict{#endsyntax#} (default) - Floating point operations follow strict IEEE compliance.
*   {#syntax#}Optimized{#endsyntax#} - Floating point operations may do all of the following:
    
    *   Assume the arguments and result are not NaN. Optimizations are required to retain legal behavior over NaNs, but the value of the result is undefined.
    *   Assume the arguments and result are not +/-Inf. Optimizations are required to retain legal behavior over +/-Inf, but the value of the result is undefined.
    *   Treat the sign of a zero argument or result as insignificant.
    *   Use the reciprocal of an argument rather than perform division.
    *   Perform floating-point contraction (e.g. fusing a multiply followed by an addition into a fused multiply-add).
    *   Perform algebraically equivalent transformations that may change results in floating point (e.g. reassociate).
    
    This is equivalent to `-ffast-math` in GCC.

The floating point mode is inherited by child scopes, and can be overridden in any scope. You can set the floating point mode in a struct or module scope by using a comptime block.

{#syntax#}FloatMode{#endsyntax#} can be found with {#syntax#}@import("std").builtin.FloatMode{#endsyntax#}.

{#see\_also|Floating Point Operations#} {#header\_close#} {#header\_open|@setRuntimeSafety#}

{#syntax#}@setRuntimeSafety(comptime safety\_on: bool) void{#endsyntax#}

Sets whether runtime safety checks are enabled for the scope that contains the function call.

{#code|test\_setRuntimeSafety\_builtin.zig#}

Note: it is [planned](https://github.com/ziglang/zig/issues/978) to replace {#syntax#}@setRuntimeSafety{#endsyntax#} with `@optimizeFor`

{#header\_close#} {#header\_open|@shlExact#}

{#syntax#}@shlExact(value: T, shift\_amt: Log2T) T{#endsyntax#}

Performs the left shift operation ({#syntax#}<<{#endsyntax#}). For unsigned integers, the result is {#link|undefined#} if any 1 bits are shifted out. For signed integers, the result is {#link|undefined#} if any bits that disagree with the resultant sign bit are shifted out.

The type of {#syntax#}shift\_amt{#endsyntax#} is an unsigned integer with {#syntax#}log2(@typeInfo(T).int.bits){#endsyntax#} bits. This is because {#syntax#}shift\_amt >= @typeInfo(T).int.bits{#endsyntax#} triggers safety-checked {#link|Illegal Behavior#}.

{#syntax#}comptime\_int{#endsyntax#} is modeled as an integer with an infinite number of bits, meaning that in such case, {#syntax#}@shlExact{#endsyntax#} always produces a result and cannot produce a compile error.

{#see\_also|@shrExact|@shlWithOverflow#} {#header\_close#} {#header\_open|@shlWithOverflow#}

{#syntax#}@shlWithOverflow(a: anytype, shift\_amt: Log2T) struct { @TypeOf(a), u1 }{#endsyntax#}

Performs {#syntax#}a << b{#endsyntax#} and returns a tuple with the result and a possible overflow bit.

The type of {#syntax#}shift\_amt{#endsyntax#} is an unsigned integer with {#syntax#}log2(@typeInfo(@TypeOf(a)).int.bits){#endsyntax#} bits. This is because {#syntax#}shift\_amt >= @typeInfo(@TypeOf(a)).int.bits{#endsyntax#} triggers safety-checked {#link|Illegal Behavior#}.

{#see\_also|@shlExact|@shrExact#} {#header\_close#} {#header\_open|@shrExact#}

{#syntax#}@shrExact(value: T, shift\_amt: Log2T) T{#endsyntax#}

Performs the right shift operation ({#syntax#}>>{#endsyntax#}). Caller guarantees that the shift will not shift any 1 bits out.

The type of {#syntax#}shift\_amt{#endsyntax#} is an unsigned integer with {#syntax#}log2(@typeInfo(T).int.bits){#endsyntax#} bits. This is because {#syntax#}shift\_amt >= @typeInfo(T).int.bits{#endsyntax#} triggers safety-checked {#link|Illegal Behavior#}.

{#see\_also|@shlExact|@shlWithOverflow#} {#header\_close#} {#header\_open|@shuffle#}

{#syntax#}@shuffle(comptime E: type, a: @Vector(a\_len, E), b: @Vector(b\_len, E), comptime mask: @Vector(mask\_len, i32)) @Vector(mask\_len, E){#endsyntax#}

Constructs a new {#link|vector|Vectors#} by selecting elements from {#syntax#}a{#endsyntax#} and {#syntax#}b{#endsyntax#} based on {#syntax#}mask{#endsyntax#}.

Each element in {#syntax#}mask{#endsyntax#} selects an element from either {#syntax#}a{#endsyntax#} or {#syntax#}b{#endsyntax#}. Positive numbers select from {#syntax#}a{#endsyntax#} starting at 0. Negative values select from {#syntax#}b{#endsyntax#}, starting at {#syntax#}-1{#endsyntax#} and going down. It is recommended to use the {#syntax#}~{#endsyntax#} operator for indexes from {#syntax#}b{#endsyntax#} so that both indexes can start from {#syntax#}0{#endsyntax#} (i.e. {#syntax#}~@as(i32, 0){#endsyntax#} is {#syntax#}-1{#endsyntax#}).

For each element of {#syntax#}mask{#endsyntax#}, if it or the selected value from {#syntax#}a{#endsyntax#} or {#syntax#}b{#endsyntax#} is {#syntax#}undefined{#endsyntax#}, then the resulting element is {#syntax#}undefined{#endsyntax#}.

{#syntax#}a\_len{#endsyntax#} and {#syntax#}b\_len{#endsyntax#} may differ in length. Out-of-bounds element indexes in {#syntax#}mask{#endsyntax#} result in compile errors.

If {#syntax#}a{#endsyntax#} or {#syntax#}b{#endsyntax#} is {#syntax#}undefined{#endsyntax#}, it is equivalent to a vector of all {#syntax#}undefined{#endsyntax#} with the same length as the other vector. If both vectors are {#syntax#}undefined{#endsyntax#}, {#syntax#}@shuffle{#endsyntax#} returns a vector with all elements {#syntax#}undefined{#endsyntax#}.

{#syntax#}E{#endsyntax#} must be an {#link|integer|Integers#}, {#link|float|Floats#}, {#link|pointer|Pointers#}, or {#syntax#}bool{#endsyntax#}. The mask may be any vector length, and its length determines the result length.

{#code|test\_shuffle\_builtin.zig#} {#see\_also|Vectors#} {#header\_close#} {#header\_open|@sizeOf#}

{#syntax#}@sizeOf(comptime T: type) comptime\_int{#endsyntax#}

This function returns the number of bytes it takes to store {#syntax#}T{#endsyntax#} in memory. The result is a target-specific compile time constant.

This size may contain padding bytes. If there were two consecutive T in memory, the padding would be the offset in bytes between element at index 0 and the element at index 1. For {#link|integer|Integers#}, consider whether you want to use {#syntax#}@sizeOf(T){#endsyntax#} or {#syntax#}@typeInfo(T).int.bits{#endsyntax#}.

This function measures the size at runtime. For types that are disallowed at runtime, such as {#syntax#}comptime\_int{#endsyntax#} and {#syntax#}type{#endsyntax#}, the result is {#syntax#}0{#endsyntax#}.

{#see\_also|@bitSizeOf|@typeInfo#} {#header\_close#} {#header\_open|@splat#}

{#syntax#}@splat(scalar: anytype) anytype{#endsyntax#}

Produces an array or vector where each element is the value {#syntax#}scalar{#endsyntax#}. The return type and thus the length of the vector is inferred.

{#code|test\_splat\_builtin.zig#}

{#syntax#}scalar{#endsyntax#} must be an {#link|integer|Integers#}, {#link|bool|Primitive Types#}, {#link|float|Floats#}, or {#link|pointer|Pointers#}.

{#see\_also|Vectors|@shuffle#} {#header\_close#} {#header\_open|@reduce#}

{#syntax#}@reduce(comptime op: std.builtin.ReduceOp, value: anytype) E{#endsyntax#}

Transforms a {#link|vector|Vectors#} into a scalar value (of type `E`) by performing a sequential horizontal reduction of its elements using the specified operator {#syntax#}op{#endsyntax#}.

Not every operator is available for every vector element type:

*   Every operator is available for {#link|integer|Integers#} vectors.
*   {#syntax#}.And{#endsyntax#}, {#syntax#}.Or{#endsyntax#}, {#syntax#}.Xor{#endsyntax#} are additionally available for {#syntax#}bool{#endsyntax#} vectors,
*   {#syntax#}.Min{#endsyntax#}, {#syntax#}.Max{#endsyntax#}, {#syntax#}.Add{#endsyntax#}, {#syntax#}.Mul{#endsyntax#} are additionally available for {#link|floating point|Floats#} vectors,

Note that {#syntax#}.Add{#endsyntax#} and {#syntax#}.Mul{#endsyntax#} reductions on integral types are wrapping; when applied on floating point types the operation associativity is preserved, unless the float mode is set to {#syntax#}Optimized{#endsyntax#}.

{#code|test\_reduce\_builtin.zig#} {#see\_also|Vectors|@setFloatMode#} {#header\_close#} {#header\_open|@src#}

{#syntax#}@src() std.builtin.SourceLocation{#endsyntax#}

Returns a {#syntax#}SourceLocation{#endsyntax#} struct representing the function's name and location in the source code. This must be called in a function.

{#code|test\_src\_builtin.zig#} {#header\_close#} {#header\_open|@sqrt#}

{#syntax#}@sqrt(value: anytype) @TypeOf(value){#endsyntax#}

Performs the square root of a floating point number. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@sin#}

{#syntax#}@sin(value: anytype) @TypeOf(value){#endsyntax#}

Sine trigonometric function on a floating point number in radians. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@cos#}

{#syntax#}@cos(value: anytype) @TypeOf(value){#endsyntax#}

Cosine trigonometric function on a floating point number in radians. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@tan#}

{#syntax#}@tan(value: anytype) @TypeOf(value){#endsyntax#}

Tangent trigonometric function on a floating point number in radians. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@exp#}

{#syntax#}@exp(value: anytype) @TypeOf(value){#endsyntax#}

Base-e exponential function on a floating point number. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@exp2#}

{#syntax#}@exp2(value: anytype) @TypeOf(value){#endsyntax#}

Base-2 exponential function on a floating point number. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@log#}

{#syntax#}@log(value: anytype) @TypeOf(value){#endsyntax#}

Returns the natural logarithm of a floating point number. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@log2#}

{#syntax#}@log2(value: anytype) @TypeOf(value){#endsyntax#}

Returns the logarithm to the base 2 of a floating point number. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@log10#}

{#syntax#}@log10(value: anytype) @TypeOf(value){#endsyntax#}

Returns the logarithm to the base 10 of a floating point number. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@abs#}

{#syntax#}@abs(value: anytype) anytype{#endsyntax#}

Returns the absolute value of an integer or a floating point number. Uses a dedicated hardware instruction when available. The return type is always an unsigned integer of the same bit width as the operand if the operand is an integer. Unsigned integer operands are supported. The builtin cannot overflow for signed integer operands.

Supports {#link|Floats#}, {#link|Integers#} and {#link|Vectors#} of floats or integers.

{#header\_close#} {#header\_open|@floor#}

{#syntax#}@floor(value: anytype) @TypeOf(value){#endsyntax#}

Returns the largest integral value not greater than the given floating point number. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@ceil#}

{#syntax#}@ceil(value: anytype) @TypeOf(value){#endsyntax#}

Returns the smallest integral value not less than the given floating point number. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@trunc#}

{#syntax#}@trunc(value: anytype) @TypeOf(value){#endsyntax#}

Rounds the given floating point number to an integer, towards zero. Uses a dedicated hardware instruction when available.

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@round#}

{#syntax#}@round(value: anytype) @TypeOf(value){#endsyntax#}

Rounds the given floating point number to the nearest integer. If two integers are equally close, rounds away from zero. Uses a dedicated hardware instruction when available.

{#code|test\_round\_builtin.zig#}

Supports {#link|Floats#} and {#link|Vectors#} of floats.

{#header\_close#} {#header\_open|@subWithOverflow#}

{#syntax#}@subWithOverflow(a: anytype, b: anytype) struct { @TypeOf(a, b), u1 }{#endsyntax#}

Performs {#syntax#}a - b{#endsyntax#} and returns a tuple with the result and a possible overflow bit.

{#header\_close#} {#header\_open|@tagName#}

{#syntax#}@tagName(value: anytype) \[:0\]const u8{#endsyntax#}

Converts an enum value or union value to a string literal representing the name.

If the enum is non-exhaustive and the tag value does not map to a name, it invokes safety-checked {#link|Illegal Behavior#}.

{#header\_close#} {#header\_open|@This#}

{#syntax#}@This() type{#endsyntax#}

Returns the innermost struct, enum, or union that this function call is inside. This can be useful for an anonymous struct that needs to refer to itself:

{#code|test\_this\_builtin.zig#}

When {#syntax#}@This(){#endsyntax#} is used at file scope, it returns a reference to the struct that corresponds to the current file.

{#header\_close#} {#header\_open|@trap#}

{#syntax#}@trap() noreturn{#endsyntax#}

This function inserts a platform-specific trap/jam instruction which can be used to exit the program abnormally. This may be implemented by explicitly emitting an invalid instruction which may cause an illegal instruction exception of some sort. Unlike for {#syntax#}@breakpoint(){#endsyntax#}, execution does not continue after this point.

Outside function scope, this builtin causes a compile error.

{#see\_also|@breakpoint#} {#header\_close#} {#header\_open|@truncate#}

{#syntax#}@truncate(integer: anytype) anytype{#endsyntax#}

This function truncates bits from an integer type, resulting in a smaller or same-sized integer type. The return type is the inferred result type.

This function always truncates the significant bits of the integer, regardless of endianness on the target platform.

Calling {#syntax#}@truncate{#endsyntax#} on a number out of range of the destination type is well defined and working code:

{#code|test\_truncate\_builtin.zig#}

Use {#link|@intCast#} to convert numbers guaranteed to fit the destination type.

{#header\_close#} {#header\_open|@EnumLiteral#}

{#syntax#}@EnumLiteral() type{#endsyntax#}

Returns the comptime-only "enum literal" type. This is the type of uncoerced {#link|Enum Literals#}. Values of this type can coerce to any {#link|enum#} with a matching field.

{#header\_close#} {#header\_open|@Int#}

{#syntax#}@Int(comptime signedness: std.builtin.Signedness, comptime bits: u16) type{#endsyntax#}

Returns an integer type with the given signedness and bit width.

For instance, {#syntax#}@Int(.unsigned, 18){#endsyntax#} returns the type {#syntax#}u18{#endsyntax#}.

{#header\_close#} {#header\_open|@Tuple#}

{#syntax#}@Tuple(comptime field\_types: \[\]const type) type{#endsyntax#}

Returns a {#link|tuple|Tuples#} type with the given field types.

{#header\_close#} {#header\_open|@Pointer#}

{#syntax#}@Pointer(
    comptime size: std.builtin.Type.Pointer.Size,
    comptime attrs: std.builtin.Type.Pointer.Attributes,
    comptime Element: type,
    comptime sentinel: ?Element,
) type{#endsyntax#}

Returns a {#link|pointer|Pointers#} type with the properties specified by the arguments.

{#header\_close#} {#header\_open|@Fn#}

{#syntax#}@Fn(
    comptime param\_types: \[\]const type,
    comptime param\_attrs: \*const \[param\_types.len\]std.builtin.Type.Fn.Param.Attributes,
    comptime ReturnType: type,
    comptime attrs: std.builtin.Type.Fn.Attributes,
) type{#endsyntax#}

Returns a {#link|function|Functions#} type with the properties specified by the arguments.

{#header\_close#} {#header\_open|@Struct#}

{#syntax#}@Struct(
    comptime layout: std.builtin.Type.ContainerLayout,
    comptime BackingInt: ?type,
    comptime field\_names: \[\]const \[\]const u8,
    comptime field\_types: \*const \[field\_names.len\]type,
    comptime field\_attrs: \*const \[field\_names.len\]std.builtin.Type.StructField.Attributes,
) type{#endsyntax#}

Returns a {#link|struct#} type with the properties specified by the arguments.

{#header\_close#} {#header\_open|@Union#}

{#syntax#}@Union(
    comptime layout: std.builtin.Type.ContainerLayout,
    /// Either the integer tag type, or the integer backing type, depending on \`layout\`.
    comptime ArgType: ?type,
    comptime field\_names: \[\]const \[\]const u8,
    comptime field\_types: \*const \[field\_names.len\]type,
    comptime field\_attrs: \*const \[field\_names.len\]std.builtin.Type.UnionField.Attributes,
) type{#endsyntax#}

Returns a {#link|union#} type with the properties specified by the arguments.

{#header\_close#} {#header\_open|@Enum#}

{#syntax#}@Enum(
    comptime TagInt: type,
    comptime mode: std.builtin.Type.Enum.Mode,
    comptime field\_names: \[\]const \[\]const u8,
    comptime field\_values: \*const \[field\_names.len\]TagInt,
) type{#endsyntax#}

Returns an {#link|enum#} type with the properties specified by the arguments.

{#header\_close#} {#header\_open|@typeInfo#}

{#syntax#}@typeInfo(comptime T: type) std.builtin.Type{#endsyntax#}

Provides type reflection.

Type information of {#link|structs|struct#}, {#link|unions|union#}, {#link|enums|enum#}, and {#link|error sets|Error Set Type#} has fields which are guaranteed to be in the same order as appearance in the source file.

Type information of {#link|structs|struct#}, {#link|unions|union#}, {#link|enums|enum#}, and {#link|opaques|opaque#} has declarations, which are also guaranteed to be in the same order as appearance in the source file.

{#header\_close#} {#header\_open|@typeName#}

{#syntax#}@typeName(T: type) \*const \[N:0\]u8{#endsyntax#}

This function returns the string representation of a type, as an array. It is equivalent to a string literal of the type name. The returned type name is fully qualified with the parent namespace included as part of the type name with a series of dots.

{#header\_close#} {#header\_open|@TypeOf#}

{#syntax#}@TypeOf(...) type{#endsyntax#}

{#syntax#}@TypeOf{#endsyntax#} is a special builtin function that takes any (non-zero) number of expressions as parameters and returns the type of the result, using {#link|Peer Type Resolution#}.

The expressions are evaluated, however they are guaranteed to have no _runtime_ side-effects:

{#code|test\_TypeOf\_builtin.zig#} {#header\_close#} {#header\_open|@unionInit#}

{#syntax#}@unionInit(comptime Union: type, comptime active\_field\_name: \[\]const u8, init\_expr) Union{#endsyntax#}

This is the same thing as {#link|union#} initialization syntax, except that the field name is a {#link|comptime#}-known value rather than an identifier token.

{#syntax#}@unionInit{#endsyntax#} forwards its {#link|result location|Result Location Semantics#} to {#syntax#}init\_expr{#endsyntax#}.

{#header\_close#} {#header\_open|@Vector#}

{#syntax#}@Vector(len: comptime\_int, Element: type) type{#endsyntax#}

Creates {#link|Vectors#}.

{#header\_close#} {#header\_open|@volatileCast#}

{#syntax#}@volatileCast(value: anytype) DestType{#endsyntax#}

Remove {#syntax#}volatile{#endsyntax#} qualifier from a pointer.

{#header\_close#} {#header\_open|@workGroupId#}

{#syntax#}@workGroupId(comptime dimension: u32) u32{#endsyntax#}

Returns the index of the work group in the current kernel invocation in dimension {#syntax#}dimension{#endsyntax#}.

{#header\_close#} {#header\_open|@workGroupSize#}

{#syntax#}@workGroupSize(comptime dimension: u32) u32{#endsyntax#}

Returns the number of work items that a work group has in dimension {#syntax#}dimension{#endsyntax#}.

{#header\_close#} {#header\_open|@workItemId#}

{#syntax#}@workItemId(comptime dimension: u32) u32{#endsyntax#}

Returns the index of the work item in the work group in dimension {#syntax#}dimension{#endsyntax#}. This function returns values between {#syntax#}0{#endsyntax#} (inclusive) and {#syntax#}@workGroupSize(dimension){#endsyntax#} (exclusive).

{#header\_close#} {#header\_close#} {#header\_open|Build Mode#}

Zig has four build modes:

*   {#link|Debug#} (default)
*   {#link|ReleaseFast#}
*   {#link|ReleaseSafe#}
*   {#link|ReleaseSmall#}

To add standard build options to a `build.zig` file:

{#code|build.zig#}

This causes these options to be available:

\-Doptimize=Debug

Optimizations off and safety on (default)

\-Doptimize=ReleaseSafe

Optimizations on and safety on

\-Doptimize=ReleaseFast

Optimizations on and safety off

\-Doptimize=ReleaseSmall

Size optimizations on and safety off

{#header\_open|Debug#} {#shell\_samp#}$ zig build-exe example.zig{#end\_shell\_samp#}

*   Fast compilation speed
*   Safety checks enabled
*   Slow runtime performance
*   Large binary size
*   No reproducible build requirement

{#header\_close#} {#header\_open|ReleaseFast#} {#shell\_samp#}$ zig build-exe example.zig -O ReleaseFast{#end\_shell\_samp#}

*   Fast runtime performance
*   Safety checks disabled
*   Slow compilation speed
*   Large binary size
*   Reproducible build

{#header\_close#} {#header\_open|ReleaseSafe#} {#shell\_samp#}$ zig build-exe example.zig -O ReleaseSafe{#end\_shell\_samp#}

*   Medium runtime performance
*   Safety checks enabled
*   Slow compilation speed
*   Large binary size
*   Reproducible build

{#header\_close#} {#header\_open|ReleaseSmall#} {#shell\_samp#}$ zig build-exe example.zig -O ReleaseSmall{#end\_shell\_samp#}

*   Medium runtime performance
*   Safety checks disabled
*   Slow compilation speed
*   Small binary size
*   Reproducible build

{#header\_close#} {#see\_also|Compile Variables|Zig Build System|Illegal Behavior#} {#header\_close#} {#header\_open|Single Threaded Builds#}

Zig has a compile option \-fsingle-threaded which has the following effects:

*   All {#link|Thread Local Variables#} are treated as regular {#link|Container Level Variables#}.
*   The overhead of {#link|Async Functions#} becomes equivalent to function call overhead.
*   The {#syntax#}@import("builtin").single\_threaded{#endsyntax#} becomes {#syntax#}true{#endsyntax#} and therefore various userland APIs which read this variable become more efficient. For example {#syntax#}std.Mutex{#endsyntax#} becomes an empty data structure and all of its functions become no-ops.

{#header\_close#} {#header\_open|Illegal Behavior#}

Many operations in Zig trigger what is known as "Illegal Behavior" (IB). If Illegal Behavior is detected at compile-time, Zig emits a compile error and refuses to continue. Otherwise, when Illegal Behavior is not caught at compile-time, it falls into one of two categories.

Some Illegal Behavior is _safety-checked_: this means that the compiler will insert "safety checks" anywhere that the Illegal Behavior may occur at runtime, to determine whether it is about to happen. If it is, the safety check "fails", which triggers a panic.

All other Illegal Behavior is _unchecked_, meaning the compiler is unable to insert safety checks for it. If Unchecked Illegal Behavior is invoked at runtime, anything can happen: usually that will be some kind of crash, but the optimizer is free to make Unchecked Illegal Behavior do anything, such as calling arbitrary functions or clobbering arbitrary data. This is similar to the concept of "undefined behavior" in some other languages. Note that Unchecked Illegal Behavior still always results in a compile error if evaluated at {#link|comptime#}, because the Zig compiler is able to perform more sophisticated checks at compile-time than at runtime.

Most Illegal Behavior is safety-checked. However, to facilitate optimizations, safety checks are disabled by default in the {#link|ReleaseFast#} and {#link|ReleaseSmall#} optimization modes. Safety checks can also be enabled or disabled on a per-block basis, overriding the default for the current optimization mode, using {#link|@setRuntimeSafety#}. When safety checks are disabled, Safety-Checked Illegal Behavior behaves like Unchecked Illegal Behavior; that is, any behavior may result from invoking it.

When a safety check fails, Zig's default panic handler crashes with a stack trace, like this:

{#code|test\_illegal\_behavior.zig#} {#header\_open|Reaching Unreachable Code#}

At compile-time:

{#code|test\_comptime\_reaching\_unreachable.zig#}

At runtime:

{#code|runtime\_reaching\_unreachable.zig#} {#header\_close#} {#header\_open|Index out of Bounds#}

At compile-time:

{#code|test\_comptime\_index\_out\_of\_bounds.zig#}

At runtime:

{#code|runtime\_index\_out\_of\_bounds.zig#} {#header\_close#} {#header\_open|Cast Negative Number to Unsigned Integer#}

At compile-time:

{#code|test\_comptime\_invalid\_cast.zig#}

At runtime:

{#code|runtime\_invalid\_cast.zig#}

To obtain the maximum value of an unsigned integer, use {#syntax#}std.math.maxInt{#endsyntax#}.

{#header\_close#} {#header\_open|Cast Truncates Data#}

At compile-time:

{#code|test\_comptime\_invalid\_cast\_truncate.zig#}

At runtime:

{#code|runtime\_invalid\_cast\_truncate.zig#}

To truncate bits, use {#link|@truncate#}.

{#header\_close#} {#header\_open|Integer Overflow#} {#header\_open|Default Operations#}

The following operators can cause integer overflow:

*   {#syntax#}+{#endsyntax#} (addition)
*   {#syntax#}-{#endsyntax#} (subtraction)
*   {#syntax#}-{#endsyntax#} (negation)
*   {#syntax#}\*{#endsyntax#} (multiplication)
*   {#syntax#}/{#endsyntax#} (division)
*   {#link|@divTrunc#} (division)
*   {#link|@divFloor#} (division)
*   {#link|@divExact#} (division)

Example with addition at compile-time:

{#code|test\_comptime\_overflow.zig#}

At runtime:

{#code|runtime\_overflow.zig#} {#header\_close#} {#header\_open|Standard Library Math Functions#}

These functions provided by the standard library return possible errors.

*   {#syntax#}@import("std").math.add{#endsyntax#}
*   {#syntax#}@import("std").math.sub{#endsyntax#}
*   {#syntax#}@import("std").math.mul{#endsyntax#}
*   {#syntax#}@import("std").math.divTrunc{#endsyntax#}
*   {#syntax#}@import("std").math.divFloor{#endsyntax#}
*   {#syntax#}@import("std").math.divExact{#endsyntax#}
*   {#syntax#}@import("std").math.shl{#endsyntax#}

Example of catching an overflow for addition:

{#code|math\_add.zig#} {#header\_close#} {#header\_open|Builtin Overflow Functions#}

These builtins return a tuple containing whether there was an overflow (as a {#syntax#}u1{#endsyntax#}) and the possibly overflowed bits of the operation:

*   {#link|@addWithOverflow#}
*   {#link|@subWithOverflow#}
*   {#link|@mulWithOverflow#}
*   {#link|@shlWithOverflow#}

Example of {#link|@addWithOverflow#}:

{#code|addWithOverflow\_builtin.zig#} {#header\_close#} {#header\_open|Wrapping Operations#}

These operations have guaranteed wraparound semantics.

*   {#syntax#}+%{#endsyntax#} (wraparound addition)
*   {#syntax#}-%{#endsyntax#} (wraparound subtraction)
*   {#syntax#}-%{#endsyntax#} (wraparound negation)
*   {#syntax#}\*%{#endsyntax#} (wraparound multiplication)

{#code|test\_wraparound\_semantics.zig#} {#header\_close#} {#header\_close#} {#header\_open|Exact Left Shift Overflow#}

At compile-time:

{#code|test\_comptime\_shlExact\_overflow.zig#}

At runtime:

{#code|runtime\_shlExact\_overflow.zig#} {#header\_close#} {#header\_open|Exact Right Shift Overflow#}

At compile-time:

{#code|test\_comptime\_shrExact\_overflow.zig#}

At runtime:

{#code|runtime\_shrExact\_overflow.zig#} {#header\_close#} {#header\_open|Division by Zero#}

At compile-time:

{#code|test\_comptime\_division\_by\_zero.zig#}

At runtime:

{#code|runtime\_division\_by\_zero.zig#} {#header\_close#} {#header\_open|Remainder Division by Zero#}

At compile-time:

{#code|test\_comptime\_remainder\_division\_by\_zero.zig#}

At runtime:

{#code|runtime\_remainder\_division\_by\_zero.zig#} {#header\_close#} {#header\_open|Exact Division Remainder#}

At compile-time:

{#code|test\_comptime\_divExact\_remainder.zig#}

At runtime:

{#code|runtime\_divExact\_remainder.zig#} {#header\_close#} {#header\_open|Attempt to Unwrap Null#}

At compile-time:

{#code|test\_comptime\_unwrap\_null.zig#}

At runtime:

{#code|runtime\_unwrap\_null.zig#}

One way to avoid this crash is to test for null instead of assuming non-null, with the {#syntax#}if{#endsyntax#} expression:

{#code|testing\_null\_with\_if.zig#} {#see\_also|Optionals#} {#header\_close#} {#header\_open|Attempt to Unwrap Error#}

At compile-time:

{#code|test\_comptime\_unwrap\_error.zig#}

At runtime:

{#code|runtime\_unwrap\_error.zig#}

One way to avoid this crash is to test for an error instead of assuming a successful result, with the {#syntax#}if{#endsyntax#} expression:

{#code|testing\_error\_with\_if.zig#} {#see\_also|Errors#} {#header\_close#} {#header\_open|Invalid Error Code#}

At compile-time:

{#code|test\_comptime\_invalid\_error\_code.zig#}

At runtime:

{#code|runtime\_invalid\_error\_code.zig#} {#header\_close#} {#header\_open|Invalid Enum Cast#}

At compile-time:

{#code|test\_comptime\_invalid\_enum\_cast.zig#}

At runtime:

{#code|runtime\_invalid\_enum\_cast.zig#} {#header\_close#} {#header\_open|Invalid Error Set Cast#}

At compile-time:

{#code|test\_comptime\_invalid\_error\_set\_cast.zig#}

At runtime:

{#code|runtime\_invalid\_error\_set\_cast.zig#} {#header\_close#} {#header\_open|Incorrect Pointer Alignment#}

At compile-time:

{#code|test\_comptime\_incorrect\_pointer\_alignment.zig#}

At runtime:

{#code|runtime\_incorrect\_pointer\_alignment.zig#} {#header\_close#} {#header\_open|Wrong Union Field Access#}

At compile-time:

{#code|test\_comptime\_wrong\_union\_field\_access.zig#}

At runtime:

{#code|runtime\_wrong\_union\_field\_access.zig#}

This safety is not available for {#syntax#}extern{#endsyntax#} or {#syntax#}packed{#endsyntax#} unions.

To change the active field of a union, assign the entire union, like this:

{#code|change\_active\_union\_field.zig#}

To change the active field of a union when a meaningful value for the field is not known, use {#link|undefined#}, like this:

{#code|undefined\_active\_union\_field.zig#} {#see\_also|union|extern union#} {#header\_close#} {#header\_open|Out of Bounds Float to Integer Cast#}

This happens when casting a float to an integer where the float has a value outside the integer type's range.

At compile-time:

{#code|test\_comptime\_out\_of\_bounds\_float\_to\_integer\_cast.zig#}

At runtime:

{#code|runtime\_out\_of\_bounds\_float\_to\_integer\_cast.zig#} {#header\_close#} {#header\_open|Pointer Cast Invalid Null#}

This happens when casting a pointer with the address 0 to a pointer which may not have the address 0. For example, {#link|C Pointers#}, {#link|Optional Pointers#}, and {#link|allowzero#} pointers allow address zero, but normal {#link|Pointers#} do not.

At compile-time:

{#code|test\_comptime\_invalid\_null\_pointer\_cast.zig#}

At runtime:

{#code|runtime\_invalid\_null\_pointer\_cast.zig#} {#header\_close#} {#header\_close#} {#header\_open|Memory#}

The Zig language performs no memory management on behalf of the programmer. This is why Zig has no runtime, and why Zig code works seamlessly in so many environments, including real-time software, operating system kernels, embedded devices, and low latency servers. As a consequence, Zig programmers must always be able to answer the question:

{#link|Where are the bytes?#}

Like Zig, the C programming language has manual memory management. However, unlike Zig, C has a default allocator - `malloc`, `realloc`, and `free`. When linking against libc, Zig exposes this allocator with {#syntax#}std.heap.c\_allocator{#endsyntax#}. However, by convention, there is no default allocator in Zig. Instead, functions which need to allocate accept an {#syntax#}Allocator{#endsyntax#} parameter. Likewise, some data structures accept an {#syntax#}Allocator{#endsyntax#} parameter in their initialization functions:

{#code|test\_allocator.zig#}

In the above example, 100 bytes of stack memory are used to initialize a {#syntax#}FixedBufferAllocator{#endsyntax#}, which is then passed to a function. As a convenience there is a global {#syntax#}FixedBufferAllocator{#endsyntax#} available for quick tests at {#syntax#}std.testing.allocator{#endsyntax#}, which will also perform basic leak detection.

Zig has a general purpose allocator available to be imported with {#syntax#}std.heap.GeneralPurposeAllocator{#endsyntax#}. However, it is still recommended to follow the {#link|Choosing an Allocator#} guide.

{#header\_open|Choosing an Allocator#}

What allocator to use depends on a number of factors. Here is a flow chart to help you decide:

1.  Are you making a library? In this case, best to accept an {#syntax#}Allocator{#endsyntax#} as a parameter and allow your library's users to decide what allocator to use.
2.  Are you linking libc? In this case, {#syntax#}std.heap.c\_allocator{#endsyntax#} is likely the right choice, at least for your main allocator.
3.  Is the maximum number of bytes that you will need bounded by a number known at {#link|comptime#}? In this case, use {#syntax#}std.heap.FixedBufferAllocator{#endsyntax#}.
4.  Is your program a command line application which runs from start to end without any fundamental cyclical pattern (such as a video game main loop, or a web server request handler), such that it would make sense to free everything at once at the end? In this case, it is recommended to follow this pattern: {#code|cli\_allocation.zig#} When using this kind of allocator, there is no need to free anything manually. Everything gets freed at once with the call to {#syntax#}arena.deinit(){#endsyntax#}.
5.  Are the allocations part of a cyclical pattern such as a video game main loop, or a web server request handler? If the allocations can all be freed at once, at the end of the cycle, for example once the video game frame has been fully rendered, or the web server request has been served, then {#syntax#}std.heap.ArenaAllocator{#endsyntax#} is a great candidate. As demonstrated in the previous bullet point, this allows you to free entire arenas at once. Note also that if an upper bound of memory can be established, then {#syntax#}std.heap.FixedBufferAllocator{#endsyntax#} can be used as a further optimization.
6.  Are you writing a test, and you want to make sure {#syntax#}error.OutOfMemory{#endsyntax#} is handled correctly? In this case, use {#syntax#}std.testing.FailingAllocator{#endsyntax#}.
7.  Are you writing a test? In this case, use {#syntax#}std.testing.allocator{#endsyntax#}.
8.  Finally, if none of the above apply, you need a general purpose allocator. If you are in Debug mode, {#syntax#}std.heap.DebugAllocator{#endsyntax#} is available as a function that takes a {#link|comptime#} {#link|struct#} of configuration options and returns a type. Generally, you will set up exactly one in your main function, and then pass it or sub-allocators around to various parts of your application.
9.  If you are compiling in ReleaseFast mode, {#syntax#}std.heap.smp\_allocator{#endsyntax#} is a solid choice for a general purpose allocator.
10.  You can also consider implementing an allocator.

{#header\_close#} {#header\_open|Where are the bytes?#}

String literals such as {#syntax#}"hello"{#endsyntax#} are in the global constant data section. This is why it is an error to pass a string literal to a mutable slice, like this:

{#code|test\_string\_literal\_to\_slice.zig#}

However if you make the slice constant, then it works:

{#code|test\_string\_literal\_to\_const\_slice.zig#}

Just like string literals, {#syntax#}const{#endsyntax#} declarations, when the value is known at {#link|comptime#}, are stored in the global constant data section. Also {#link|Compile Time Variables#} are stored in the global constant data section.

{#syntax#}var{#endsyntax#} declarations inside functions are stored in the function's stack frame. Once a function returns, any {#link|Pointers#} to variables in the function's stack frame become invalid references, and dereferencing them becomes unchecked {#link|Illegal Behavior#}.

{#syntax#}var{#endsyntax#} declarations at the top level or in {#link|struct#} declarations are stored in the global data section.

The location of memory allocated with {#syntax#}allocator.alloc{#endsyntax#} or {#syntax#}allocator.create{#endsyntax#} is determined by the allocator's implementation.

TODO: thread local variables

{#header\_close#} {#header\_open|Heap Allocation Failure#}

Many programming languages choose to handle the possibility of heap allocation failure by unconditionally crashing. By convention, Zig programmers do not consider this to be a satisfactory solution. Instead, {#syntax#}error.OutOfMemory{#endsyntax#} represents heap allocation failure, and Zig libraries return this error code whenever heap allocation failure prevented an operation from completing successfully.

Some have argued that because some operating systems such as Linux have memory overcommit enabled by default, it is pointless to handle heap allocation failure. There are many problems with this reasoning:

*   Only some operating systems have an overcommit feature.
    *   Linux has it enabled by default, but it is configurable.
    *   Windows does not overcommit.
    *   Embedded systems do not have overcommit.
    *   Hobby operating systems may or may not have overcommit.
*   For real-time systems, not only is there no overcommit, but typically the maximum amount of memory per application is determined ahead of time.
*   When writing a library, one of the main goals is code reuse. By making code handle allocation failure correctly, a library becomes eligible to be reused in more contexts.
*   Although some software has grown to depend on overcommit being enabled, its existence is the source of countless user experience disasters. When a system with overcommit enabled, such as Linux on default settings, comes close to memory exhaustion, the system locks up and becomes unusable. At this point, the OOM Killer selects an application to kill based on heuristics. This non-deterministic decision often results in an important process being killed, and often fails to return the system back to working order.

{#header\_close#} {#header\_open|Recursion#}

Recursion is a fundamental tool in modeling software. However it has an often-overlooked problem: unbounded memory allocation.

Recursion is an area of active experimentation in Zig and so the documentation here is not final. You can read a [summary of recursion status in the 0.3.0 release notes](https://ziglang.org/download/0.3.0/release-notes.html#recursion).

The short summary is that currently recursion works normally as you would expect. Although Zig code is not yet protected from stack overflow, it is planned that a future version of Zig will provide such protection, with some degree of cooperation from Zig code required.

{#header\_close#} {#header\_open|Lifetime and Ownership#}

It is the Zig programmer's responsibility to ensure that a {#link|pointer|Pointers#} is not accessed when the memory pointed to is no longer available. Note that a {#link|slice|Slices#} is a form of pointer, in that it references other memory.

In order to prevent bugs, there are some helpful conventions to follow when dealing with pointers. In general, when a function returns a pointer, the documentation for the function should explain who "owns" the pointer. This concept helps the programmer decide when it is appropriate, if ever, to free the pointer.

For example, the function's documentation may say "caller owns the returned memory", in which case the code that calls the function must have a plan for when to free that memory. Probably in this situation, the function will accept an {#syntax#}Allocator{#endsyntax#} parameter.

Sometimes the lifetime of a pointer may be more complicated. For example, the {#syntax#}std.ArrayList(T).items{#endsyntax#} slice has a lifetime that remains valid until the next time the list is resized, such as by appending new elements.

The API documentation for functions and data structures should take great care to explain the ownership and lifetime semantics of pointers. Ownership determines whose responsibility it is to free the memory referenced by the pointer, and lifetime determines the point at which the memory becomes inaccessible (lest {#link|Illegal Behavior#} occur).

{#header\_close#} {#header\_close#} {#header\_open|Compile Variables#}

Compile variables are accessible by importing the {#syntax#}"builtin"{#endsyntax#} package, which the compiler makes available to every Zig source file. It contains compile-time constants such as the current target, endianness, and release mode.

{#code|compile\_variables.zig#}

Example of what is imported with {#syntax#}@import("builtin"){#endsyntax#}:

{#builtin#} {#see\_also|Build Mode#} {#header\_close#} {#header\_open|Compilation Model#}

A Zig compilation is separated into _modules_. Each module is a collection of Zig source files, one of which is the module's _root source file_. Each module can _depend_ on any number of other modules, forming a directed graph (dependency loops between modules are allowed). If module A depends on module B, then any Zig source file in module A can import the _root source file_ of module B using {#syntax#}@import{#endsyntax#} with the module's name. In essence, a module acts as an alias to import a Zig source file (which might exist in a completely separate part of the filesystem).

A simple Zig program compiled with `zig build-exe` has two key modules: the one containing your code, known as the "main" or "root" module, and the standard library. Your module _depends on_ the standard library module under the name "std", which is what allows you to write {#syntax#}@import("std"){#endsyntax#}! In fact, every single module in a Zig compilation — including the standard library itself — implicitly depends on the standard library module under the name "std".

The "root module" (the one provided by you in the `zig build-exe` example) has a special property. Like the standard library, it is implicitly made available to all modules (including itself), this time under the name "root". So, {#syntax#}@import("root"){#endsyntax#} will always be equivalent to {#syntax#}@import{#endsyntax#} of your "main" source file (often, but not necessarily, named `main.zig`).

{#header\_open|Source File Structs#}

Every Zig source file is implicitly a {#syntax#}struct{#endsyntax#} declaration; you can imagine that the file's contents are literally surrounded by {#syntax#}struct { ... }{#endsyntax#}. This means that as well as declarations, the top level of a file is permitted to contain fields:

{#code|TopLevelFields.zig#}

Such files can be instantiated just like any other {#syntax#}struct{#endsyntax#} type. A file's "root struct type" can be referred to within that file using {#link|@This#}.

{#header\_close#} {#header\_open|File and Declaration Discovery#}

Zig places importance on the concept of whether any piece of code is _semantically analyzed_; in essence, whether the compiler "looks at" it. What code is analyzed is based on what files and declarations are "discovered" from a certain point. This process of "discovery" is based on a simple set of recursive rules:

*   If a call to {#syntax#}@import{#endsyntax#} is analyzed, the file being imported is analyzed.
*   If a type (including a file) is analyzed, all {#syntax#}comptime{#endsyntax#} and {#syntax#}export{#endsyntax#} declarations within it are analyzed.
*   If a type (including a file) is analyzed, and the compilation is for a {#link|test|Zig Test#}, and the module the type is within is the root module of the compilation, then all {#syntax#}test{#endsyntax#} declarations within it are also analyzed.
*   If a reference to a named declaration (i.e. a usage of it) is analyzed, the declaration being referenced is analyzed. Declarations are order-independent, so this reference may be above or below the declaration being referenced, or even in another file entirely.

That's it! Those rules define how Zig files and declarations are discovered. All that remains is to understand where this process _starts_.

The answer to that is the root of the standard library: every Zig compilation begins by analyzing the file `lib/std/std.zig`. This file contains a {#syntax#}comptime{#endsyntax#} declaration which imports {#syntax#}lib/std/start.zig{#endsyntax#}, and that file in turn uses {#syntax#}@import("root"){#endsyntax#} to reference the "root module"; so, the file you provide as your main module's root source file is effectively also a root, because the standard library will always reference it.

It is often desirable to make sure that certain declarations — particularly {#syntax#}test{#endsyntax#} or {#syntax#}export{#endsyntax#} declarations — are discovered. Based on the above rules, a common strategy for this is to use {#syntax#}@import{#endsyntax#} within a {#syntax#}comptime{#endsyntax#} or {#syntax#}test{#endsyntax#} block:

{#syntax\_block|zig|force\_file\_discovery.zig#} comptime { // This will ensure that the file 'api.zig' is always discovered (as long as this file is discovered). // It is useful if 'api.zig' contains important exported declarations. \_ = @import("api.zig"); // We could also have a file which contains declarations we only want to export depending on a comptime // condition. In that case, we can use an \`if\` statement here: if (builtin.os.tag == .windows) { \_ = @import("windows\_api.zig"); } } test { // This will ensure that the file 'tests.zig' is always discovered (as long as this file is discovered), // if this compilation is a test. It is useful if 'tests.zig' contains tests we want to ensure are run. \_ = @import("tests.zig"); // We could also have a file which contains tests we only want to run depending on a comptime condition. // In that case, we can use an \`if\` statement here: if (builtin.os.tag == .windows) { \_ = @import("windows\_tests.zig"); } } const builtin = @import("builtin"); {#end\_syntax\_block#} {#header\_close#} {#header\_open|Special Root Declarations#}

Because the root module's root source file is always accessible using {#syntax#}@import("root"){#endsyntax#}, is is sometimes used by libraries — including the Zig Standard Library — as a place for the program to expose some "global" information to that library. The Zig Standard Library will look for several declarations in this file.

{#header\_open|Entry Point#}

When building an executable, the most important thing to be looked up in this file is the program's _entry point_. Most commonly, this is a function named {#syntax#}main{#endsyntax#}, which {#syntax#}std.start{#endsyntax#} will call just after performing important initialization work.

Alternatively, the presence of a declaration named {#syntax#}\_start{#endsyntax#} (for instance, {#syntax#}pub const \_start = {};{#endsyntax#}) will disable the default {#syntax#}std.start{#endsyntax#} logic, allowing your root source file to export a low-level entry point as needed.

{#code|entry\_point.zig#}

If the Zig compilation links libc, the {#syntax#}main{#endsyntax#} function can optionally be an {#syntax#}export fn{#endsyntax#} which matches the signature of the C `main` function:

{#code|libc\_export\_entry\_point.zig#}

{#syntax#}std.start{#endsyntax#} may also use other entry point declarations in certain situations, such as {#syntax#}wWinMain{#endsyntax#} or {#syntax#}EfiMain{#endsyntax#}. Refer to the {#syntax#}lib/std/start.zig{#endsyntax#} logic for details of these declarations.

{#header\_close#} {#header\_open|Standard Library Options#}

The standard library also looks for a declaration in the root module's root source file named {#syntax#}std\_options{#endsyntax#}. If present, this declaration is expected to be a struct of type {#syntax#}std.Options{#endsyntax#}, and allows the program to customize some standard library functionality, such as the {#syntax#}std.log{#endsyntax#} implementation.

{#code|std\_options.zig#} {#header\_close#} {#header\_open|Panic Handler#}

The Zig Standard Library looks for a declaration named {#syntax#}panic{#endsyntax#} in the root module's root source file. If present, it is expected to be a namespace (container type) with declarations providing different panic handlers.

See {#syntax#}std.debug.simple\_panic{#endsyntax#} for a basic implementation of this namespace.

Overriding how the panic handler actually outputs messages, but keeping the formatted safety panics which are enabled by default, can be easily achieved with {#syntax#}std.debug.FullPanic{#endsyntax#}:

{#code|panic\_handler.zig#} {#header\_close#} {#header\_close#} {#header\_close#} {#header\_open|Zig Build System#}

The Zig Build System provides a cross-platform, dependency-free way to declare the logic required to build a project. With this system, the logic to build a project is written in a build.zig file, using the Zig Build System API to declare and configure build artifacts and other tasks.

Some examples of tasks the build system can help with:

*   Performing tasks in parallel and caching the results.
*   Depending on other projects.
*   Providing a package for other projects to depend on.
*   Creating build artifacts by executing the Zig compiler. This includes building Zig source code as well as C and C++ source code.
*   Capturing user-configured options and using those options to configure the build.
*   Surfacing build configuration as {#link|comptime#} values by providing a file that can be {#link|imported|@import#} by Zig code.
*   Caching build artifacts to avoid unnecessarily repeating steps.
*   Executing build artifacts or system-installed tools.
*   Running tests and verifying the output of executing a build artifact matches the expected value.
*   Running `zig fmt` on a codebase or a subset of it.
*   Custom tasks.

To use the build system, run zig build --help to see a command-line usage help menu. This will include project-specific options that were declared in the build.zig script.

For the time being, the build system documentation is hosted externally: [Build System Documentation](https://ziglang.org/learn/build-system/)

{#header\_close#} {#header\_open|C#}

Although Zig is independent of C, and, unlike most other languages, does not depend on libc, Zig acknowledges the importance of interacting with existing C code.

There are a few ways that Zig facilitates C interop.

{#header\_open|C Type Primitives#}

These have guaranteed C ABI compatibility and can be used like any other type.

*   {#syntax#}c\_char{#endsyntax#}
*   {#syntax#}c\_short{#endsyntax#}
*   {#syntax#}c\_ushort{#endsyntax#}
*   {#syntax#}c\_int{#endsyntax#}
*   {#syntax#}c\_uint{#endsyntax#}
*   {#syntax#}c\_long{#endsyntax#}
*   {#syntax#}c\_ulong{#endsyntax#}
*   {#syntax#}c\_longlong{#endsyntax#}
*   {#syntax#}c\_ulonglong{#endsyntax#}
*   {#syntax#}c\_longdouble{#endsyntax#}

To interop with the C {#syntax#}void{#endsyntax#} type, use {#syntax#}anyopaque{#endsyntax#}.

{#see\_also|Primitive Types#} {#header\_close#} {#header\_open|Import from C Header File#}

The {#syntax#}@cImport{#endsyntax#} builtin function can be used to directly import symbols from `.h` files:

{#code|cImport\_builtin.zig#}

The {#syntax#}@cImport{#endsyntax#} function takes an expression as a parameter. This expression is evaluated at compile-time and is used to control preprocessor directives and include multiple `.h` files:

{#syntax\_block|zig|@cImport Expression#} const builtin = @import("builtin"); const c = @cImport({ @cDefine("NDEBUG", builtin.mode == .ReleaseFast); if (something) { @cDefine("\_GNU\_SOURCE", {}); } @cInclude("stdlib.h"); if (something) { @cUndef("\_GNU\_SOURCE"); } @cInclude("soundio.h"); }); {#end\_syntax\_block#} {#see\_also|@cImport|@cInclude|@cDefine|@cUndef|@import#} {#header\_close#} {#header\_open|C Translation CLI#}

Zig's C translation capability is available as a CLI tool via zig translate-c. It requires a single filename as an argument. It may also take a set of optional flags that are forwarded to clang. It writes the translated file to stdout.

{#header\_open|Command line flags#}

*   \-I: Specify a search directory for include files. May be used multiple times. Equivalent to [clang's \-I flag](https://releases.llvm.org/12.0.0/tools/clang/docs/ClangCommandLineReference.html#cmdoption-clang-i-dir). The current directory is _not_ included by default; use \-I. to include it.
*   \-D: Define a preprocessor macro. Equivalent to [clang's \-D flag](https://releases.llvm.org/12.0.0/tools/clang/docs/ClangCommandLineReference.html#cmdoption-clang-d-macro).
*   \-cflags \[flags\] --: Pass arbitrary additional [command line flags](https://releases.llvm.org/12.0.0/tools/clang/docs/ClangCommandLineReference.html) to clang. Note: the list of flags must end with \--
*   \-target: The {#link|target triple|Targets#} for the translated Zig code. If no target is specified, the current host target will be used.

{#header\_close#} {#header\_open|Using -target and -cflags#}

**Important!** When translating C code with zig translate-c, you **must** use the same \-target triple that you will use when compiling the translated code. In addition, you **must** ensure that the \-cflags used, if any, match the cflags used by code on the target system. Using the incorrect \-target or \-cflags could result in clang or Zig parse failures, or subtle ABI incompatibilities when linking with C code.

{#syntax\_block|c|varytarget.h#} long FOO = \_\_LONG\_MAX\_\_; {#end\_syntax\_block#} {#shell\_samp#}$ zig translate-c -target thumb-freestanding-gnueabihf varytarget.h|grep FOO pub export var FOO: c\_long = 2147483647; $ zig translate-c -target x86\_64-macos-gnu varytarget.h|grep FOO pub export var FOO: c\_long = 9223372036854775807;{#end\_shell\_samp#} {#syntax\_block|c|varycflags.h#} enum FOO { BAR }; int do\_something(enum FOO foo); {#end\_syntax\_block#} {#shell\_samp#}$ zig translate-c varycflags.h|grep -B1 do\_something pub const enum\_FOO = c\_uint; pub extern fn do\_something(foo: enum\_FOO) c\_int; $ zig translate-c -cflags -fshort-enums -- varycflags.h|grep -B1 do\_something pub const enum\_FOO = u8; pub extern fn do\_something(foo: enum\_FOO) c\_int;{#end\_shell\_samp#} {#header\_close#} {#header\_open|@cImport vs translate-c#}

{#syntax#}@cImport{#endsyntax#} and zig translate-c use the same underlying C translation functionality, so on a technical level they are equivalent. In practice, {#syntax#}@cImport{#endsyntax#} is useful as a way to quickly and easily access numeric constants, typedefs, and record types without needing any extra setup. If you need to pass {#link|cflags|Using -target and -cflags#} to clang, or if you would like to edit the translated code, it is recommended to use zig translate-c and save the results to a file. Common reasons for editing the generated code include: changing {#syntax#}anytype{#endsyntax#} parameters in function-like macros to more specific types; changing {#syntax#}\[\*c\]T{#endsyntax#} pointers to {#syntax#}\[\*\]T{#endsyntax#} or {#syntax#}\*T{#endsyntax#} pointers for improved type safety; and {#link|enabling or disabling runtime safety|@setRuntimeSafety#} within specific functions.

{#header\_close#} {#see\_also|Targets|C Type Primitives|Pointers|C Pointers|Import from C Header File|@cInclude|@cImport|@setRuntimeSafety#} {#header\_close#} {#header\_open|C Translation Caching#}

The C translation feature (whether used via zig translate-c or {#syntax#}@cImport{#endsyntax#}) integrates with the Zig caching system. Subsequent runs with the same source file, target, and cflags will use the cache instead of repeatedly translating the same code.

To see where the cached files are stored when compiling code that uses {#syntax#}@cImport{#endsyntax#}, use the \--verbose-cimport flag:

{#code|verbose\_cimport\_flag.zig#}

`cimport.h` contains the file to translate (constructed from calls to {#syntax#}@cInclude{#endsyntax#}, {#syntax#}@cDefine{#endsyntax#}, and {#syntax#}@cUndef{#endsyntax#}), `cimport.h.d` is the list of file dependencies, and `cimport.zig` contains the translated output.

{#see\_also|Import from C Header File|C Translation CLI|@cInclude|@cImport#} {#header\_close#} {#header\_open|Translation failures#}

Some C constructs cannot be translated to Zig - for example, _goto_, structs with bitfields, and token-pasting macros. Zig employs _demotion_ to allow translation to continue in the face of non-translatable entities.

Demotion comes in three varieties - {#link|opaque#}, _extern_, and {#syntax#}@compileError{#endsyntax#}. C structs and unions that cannot be translated correctly will be translated as {#syntax#}opaque{}{#endsyntax#}. Functions that contain opaque types or code constructs that cannot be translated will be demoted to {#syntax#}extern{#endsyntax#} declarations. Thus, non-translatable types can still be used as pointers, and non-translatable functions can be called so long as the linker is aware of the compiled function.

{#syntax#}@compileError{#endsyntax#} is used when top-level definitions (global variables, function prototypes, macros) cannot be translated or demoted. Since Zig uses lazy analysis for top-level declarations, untranslatable entities will not cause a compile error in your code unless you actually use them.

{#see\_also|opaque|extern|@compileError#} {#header\_close#} {#header\_open|C Macros#}

C Translation makes a best-effort attempt to translate function-like macros into equivalent Zig functions. Since C macros operate at the level of lexical tokens, not all C macros can be translated to Zig. Macros that cannot be translated will be demoted to {#syntax#}@compileError{#endsyntax#}. Note that C code which _uses_ macros will be translated without any additional issues (since Zig operates on the pre-processed source with macros expanded). It is merely the macros themselves which may not be translatable to Zig.

Consider the following example:

{#syntax\_block|c|macro.c#} #define MAKELOCAL(NAME, INIT) int NAME = INIT int foo(void) { MAKELOCAL(a, 1); MAKELOCAL(b, 2); return a + b; } {#end\_syntax\_block#} {#shell\_samp#}$ zig translate-c macro.c > macro.zig{#end\_shell\_samp#} {#code|macro.zig#}

Note that {#syntax#}foo{#endsyntax#} was translated correctly despite using a non-translatable macro. {#syntax#}MAKELOCAL{#endsyntax#} was demoted to {#syntax#}@compileError{#endsyntax#} since it cannot be expressed as a Zig function; this simply means that you cannot directly use {#syntax#}MAKELOCAL{#endsyntax#} from Zig.

{#see\_also|@compileError#} {#header\_close#} {#header\_open|C Pointers#}

This type is to be avoided whenever possible. The only valid reason for using a C pointer is in auto-generated code from translating C code.

When importing C header files, it is ambiguous whether pointers should be translated as single-item pointers ({#syntax#}\*T{#endsyntax#}) or many-item pointers ({#syntax#}\[\*\]T{#endsyntax#}). C pointers are a compromise so that Zig code can utilize translated header files directly.

{#syntax#}\[\*c\]T{#endsyntax#} - C pointer.

*   Supports all the syntax of the other two pointer types ({#syntax#}\*T{#endsyntax#}) and ({#syntax#}\[\*\]T{#endsyntax#}).
*   Coerces to other pointer types, as well as {#link|Optional Pointers#}. When a C pointer is coerced to a non-optional pointer, safety-checked {#link|Illegal Behavior#} occurs if the address is 0.
*   Allows address 0. On non-freestanding targets, dereferencing address 0 is safety-checked {#link|Illegal Behavior#}. Optional C pointers introduce another bit to keep track of null, just like {#syntax#}?usize{#endsyntax#}. Note that creating an optional C pointer is unnecessary as one can use normal {#link|Optional Pointers#}.
*   Supports {#link|Type Coercion#} to and from integers.
*   Supports comparison with integers.
*   Does not support Zig-only pointer attributes such as alignment. Use normal {#link|Pointers#} please!

When a C pointer is pointing to a single struct (not an array), dereference the C pointer to access the struct's fields or member data. That syntax looks like this:

{#syntax#}ptr\_to\_struct.\*.struct\_member{#endsyntax#}

This is comparable to doing {#syntax#}->{#endsyntax#} in C.

When a C pointer is pointing to an array of structs, the syntax reverts to this:

{#syntax#}ptr\_to\_struct\_array\[index\].struct\_member{#endsyntax#}

{#header\_close#} {#header\_open|C Variadic Functions#}

Zig supports extern variadic functions.

{#code|test\_variadic\_function.zig#}

Variadic functions can be implemented using {#link|@cVaStart#}, {#link|@cVaEnd#}, {#link|@cVaArg#} and {#link|@cVaCopy#}.

{#code|test\_defining\_variadic\_function.zig#} {#header\_close#} {#header\_open|Exporting a C Library#}

One of the primary use cases for Zig is exporting a library with the C ABI for other programming languages to call into. The {#syntax#}export{#endsyntax#} keyword in front of functions, variables, and types causes them to be part of the library API:

{#code|mathtest.zig#}

To make a static library:

{#shell\_samp#}$ zig build-lib mathtest.zig{#end\_shell\_samp#}

To make a shared library:

{#shell\_samp#}$ zig build-lib mathtest.zig -dynamic{#end\_shell\_samp#}

Here is an example with the {#link|Zig Build System#}:

{#syntax\_block|c|test.c#} // This header is generated by zig from mathtest.zig #include "mathtest.h" #include int main(int argc, char \*\*argv) { int32\_t result = add(42, 1337); printf("%d\\n", result); return 0; } {#end\_syntax\_block#} {#code|build\_c.zig#} {#shell\_samp#}$ zig build test 1379{#end\_shell\_samp#} {#see\_also|export#} {#header\_close#} {#header\_open|Mixing Object Files#}

You can mix Zig object files with any other object files that respect the C ABI. Example:

{#code|base64.zig#} {#syntax\_block|c|test.c#} // This header is generated by zig from base64.zig #include "base64.h" #include #include int main(int argc, char \*\*argv) { const char \*encoded = "YWxsIHlvdXIgYmFzZSBhcmUgYmVsb25nIHRvIHVz"; char buf\[200\]; size\_t len = decode\_base\_64(buf, 200, encoded, strlen(encoded)); buf\[len\] = 0; puts(buf); return 0; } {#end\_syntax\_block#} {#code|build\_object.zig#} {#shell\_samp#}$ zig build $ ./zig-out/bin/test all your base are belong to us{#end\_shell\_samp#} {#see\_also|Targets|Zig Build System#} {#header\_close#} {#header\_close#} {#header\_open|WebAssembly#}

Zig supports building for WebAssembly out of the box.

{#header\_open|Freestanding#}

For host environments like the web browser and nodejs, build as an executable using the freestanding OS target. Here's an example of running Zig code compiled to WebAssembly with nodejs.

{#code|math.zig#} {#syntax\_block|javascript|test.js#} const fs = require('fs'); const source = fs.readFileSync("./math.wasm"); const typedArray = new Uint8Array(source); WebAssembly.instantiate(typedArray, { env: { print: (result) => { console.log(\`The result is ${result}\`); } }}).then(result => { const add = result.instance.exports.add; add(1, 2); }); {#end\_syntax\_block#} {#shell\_samp#}$ node test.js The result is 3{#end\_shell\_samp#} {#header\_close#} {#header\_open|WASI#}

Zig's support for WebAssembly System Interface (WASI) is under active development. Example of using the standard library and reading command line arguments:

{#code|wasi\_args.zig#} {#shell\_samp#}$ wasmtime wasi\_args.wasm 123 hello 0: wasi\_args.wasm 1: 123 2: hello{#end\_shell\_samp#}

A more interesting example would be extracting the list of preopens from the runtime. This is now supported in the standard library via {#syntax#}std.fs.wasi.Preopens{#endsyntax#}:

{#code|wasi\_preopens.zig#} {#shell\_samp#}$ wasmtime --dir=. wasi\_preopens.wasm 0: stdin 1: stdout 2: stderr 3: . {#end\_shell\_samp#} {#header\_close#} {#header\_close#} {#header\_open|Targets#}

**Target** refers to the computer that will be used to run an executable. It is composed of the CPU architecture, the set of enabled CPU features, operating system, minimum and maximum operating system version, ABI, and ABI version.

Zig is a general-purpose programming language which means that it is designed to generate optimal code for a large set of targets. The command `zig targets` provides information about all of the targets the compiler is aware of.

When no target option is provided to the compiler, the default choice is to target the **host computer**, meaning that the resulting executable will be _unsuitable for copying to a different computer_. In order to copy an executable to another computer, the compiler needs to know about the target requirements via the `-target` option.

The Zig Standard Library ({#syntax#}@import("std"){#endsyntax#}) has cross-platform abstractions, making the same source code viable on many targets. Some code is more portable than other code. In general, Zig code is extremely portable compared to other programming languages.

Each platform requires its own implementations to make Zig's cross-platform abstractions work. These implementations are at various degrees of completion. Each tagged release of the compiler comes with release notes that provide the full support table for each target.

{#header\_close#} {#header\_open|Style Guide#}

These coding conventions are not enforced by the compiler, but they are shipped in this documentation along with the compiler in order to provide a point of reference, should anyone wish to point to an authority on agreed upon Zig coding style.

{#header\_open|Avoid Redundancy in Names#}

Avoid these words in type names:

*   Value
*   Data
*   Context
*   Manager
*   utils, misc, or somebody's initials

Everything is a value, all types are data, everything is context, all logic manages state. Nothing is communicated by using a word that applies to all types.

Temptation to use "utilities", "miscellaneous", or somebody's initials is a failure to categorize, or more commonly, overcategorization. Such declarations can live at the root of a module that needs them with no namespace needed.

{#header\_close#} {#header\_open|Avoid Redundant Names in Fully-Qualified Namespaces#}

Every declaration is assigned a **fully qualified namespace** by the compiler, creating a tree structure. Choose names based on the fully-qualified namespace, and avoid redundant name segments.

{#code|redundant\_fqn.zig#}

In this example, "json" is repeated in the fully-qualified namespace. The solution is to delete `Json` from `JsonValue`. In this example we have an empty struct named `json` but remember that files also act as part of the fully-qualified namespace.

This example is an exception to the rule specified in {#link|Avoid Redundancy in Names#}. The meaning of the type has been reduced to its core: it is a json value. The name cannot be any more specific without being incorrect.

{#header\_close#} {#header\_open|Whitespace#}

*   4 space indentation
*   Open braces on same line, unless you need to wrap.
*   If a list of things is longer than 2, put each item on its own line and exercise the ability to put an extra comma at the end.
*   Line length: aim for 100; use common sense.

{#header\_close#} {#header\_open|Names#}

Roughly speaking: {#syntax#}camelCaseFunctionName{#endsyntax#}, {#syntax#}TitleCaseTypeName{#endsyntax#}, {#syntax#}snake\_case\_variable\_name{#endsyntax#}. More precisely:

*   If {#syntax#}x{#endsyntax#} is a {#syntax#}struct{#endsyntax#} with 0 fields and is never meant to be instantiated then {#syntax#}x{#endsyntax#} is considered to be a "namespace" and should be {#syntax#}snake\_case{#endsyntax#}.
*   If {#syntax#}x{#endsyntax#} is a {#syntax#}type{#endsyntax#} or {#syntax#}type{#endsyntax#} alias then {#syntax#}x{#endsyntax#} should be {#syntax#}TitleCase{#endsyntax#}.
*   If {#syntax#}x{#endsyntax#} is callable, and {#syntax#}x{#endsyntax#}'s return type is {#syntax#}type{#endsyntax#}, then {#syntax#}x{#endsyntax#} should be {#syntax#}TitleCase{#endsyntax#}.
*   If {#syntax#}x{#endsyntax#} is otherwise callable, then {#syntax#}x{#endsyntax#} should be {#syntax#}camelCase{#endsyntax#}.
*   Otherwise, {#syntax#}x{#endsyntax#} should be {#syntax#}snake\_case{#endsyntax#}.

Acronyms, initialisms, proper nouns, or any other word that has capitalization rules in written English are subject to naming conventions just like any other word. Even acronyms that are only 2 letters long are subject to these conventions.

File names fall into two categories: types and namespaces. If the file (implicitly a struct) has top level fields, it should be named like any other struct with fields using `TitleCase`. Otherwise, it should use `snake_case`. Directory names should be `snake_case`.

These are general rules of thumb; if it makes sense to do something different, do what makes sense. For example, if there is an established convention such as {#syntax#}ENOENT{#endsyntax#}, follow the established convention.

{#header\_close#} {#header\_open|Examples#} {#syntax\_block|zig|style\_example.zig#} const namespace\_name = @import("dir\_name/file\_name.zig"); const TypeName = @import("dir\_name/TypeName.zig"); var global\_var: i32 = undefined; const const\_name = 42; const PrimitiveTypeAlias = f32; const StructName = struct { field: i32, }; const StructAlias = StructName; fn functionName(param\_name: TypeName) void { var functionPointer = functionName; functionPointer(); functionPointer = otherFunction; functionPointer(); } const functionAlias = functionName; fn ListTemplateFunction(comptime ChildType: type, comptime fixed\_size: usize) type { return List(ChildType, fixed\_size); } fn ShortList(comptime T: type, comptime n: usize) type { return struct { field\_name: \[n\]T, fn methodName() void {} }; } // The word XML loses its casing when used in Zig identifiers. const xml\_document = \\\\ \\\\ \\\\ ; const XmlParser = struct { field: i32, }; // The initials BE (Big Endian) are just another word in Zig identifier names. fn readU32Be() u32 {} {#end\_syntax\_block#}

See the {#link|Zig Standard Library#} for more examples.

{#header\_close#} {#header\_open|Doc Comment Guidance#}

*   Omit any information that is redundant based on the name of the thing being documented.
*   Duplicating information onto multiple similar functions is encouraged because it helps IDEs and other tools provide better help text.
*   Use the word **assume** to indicate invariants that cause _unchecked_ {#link|Illegal Behavior#} when violated.
*   Use the word **assert** to indicate invariants that cause _safety-checked_ {#link|Illegal Behavior#} when violated.

{#header\_close#} {#header\_close#} {#header\_open|Source Encoding#}

Zig source code is encoded in UTF-8. An invalid UTF-8 byte sequence results in a compile error.

Throughout all zig source code (including in comments), some code points are never allowed:

*   Ascii control characters, except for U+000a (LF), U+000d (CR), and U+0009 (HT): U+0000 - U+0008, U+000b - U+000c, U+000e - U+0001f, U+007f.
*   Non-Ascii Unicode line endings: U+0085 (NEL), U+2028 (LS), U+2029 (PS).

LF (byte value 0x0a, code point U+000a, {#syntax#}'\\n'{#endsyntax#}) is the line terminator in Zig source code. This byte value terminates every line of zig source code except the last line of the file. It is recommended that non-empty source files end with an empty line, which means the last byte would be 0x0a (LF).

Each LF may be immediately preceded by a single CR (byte value 0x0d, code point U+000d, {#syntax#}'\\r'{#endsyntax#}) to form a Windows style line ending, but this is discouraged. Note that in multiline strings, CRLF sequences will be encoded as LF when compiled into a zig program. A CR in any other context is not allowed.

HT hard tabs (byte value 0x09, code point U+0009, {#syntax#}'\\t'{#endsyntax#}) are interchangeable with SP spaces (byte value 0x20, code point U+0020, {#syntax#}' '{#endsyntax#}) as a token separator, but use of hard tabs is discouraged. See {#link|Grammar#}.

For compatibility with other tools, the compiler ignores a UTF-8-encoded byte order mark (U+FEFF) if it is the first Unicode code point in the source text. A byte order mark is not allowed anywhere else in the source.

Note that running zig fmt on a source file will implement all recommendations mentioned here.

Note that a tool reading Zig source code can make assumptions if the source code is assumed to be correct Zig code. For example, when identifying the ends of lines, a tool can use a naive search such as `/\n/`, or an [advanced](https://msdn.microsoft.com/en-us/library/dd409797.aspx) search such as `/\r\n?|[\n\u0085\u2028\u2029]/`, and in either case line endings will be correctly identified. For another example, when identifying the whitespace before the first token on a line, a tool can either use a naive search such as `/[ \t]/`, or an [advanced](https://tc39.es/ecma262/#sec-characterclassescape) search such as `/\s/`, and in either case whitespace will be correctly identified.

{#header\_close#} {#header\_open|Keyword Reference#}

Keyword

Description

{#syntax#}addrspace{#endsyntax#}

The {#syntax#}addrspace{#endsyntax#} keyword.

*   TODO add documentation for addrspace

{#syntax#}align{#endsyntax#}

{#syntax#}align{#endsyntax#} can be used to specify the alignment of a pointer. It can also be used after a variable or function declaration to specify the alignment of pointers to that variable or function.

*   See also {#link|Alignment#}

{#syntax#}allowzero{#endsyntax#}

The pointer attribute {#syntax#}allowzero{#endsyntax#} allows a pointer to have address zero.

*   See also {#link|allowzero#}

{#syntax#}and{#endsyntax#}

The boolean operator {#syntax#}and{#endsyntax#}.

*   See also {#link|Operators#}

{#syntax#}anyframe{#endsyntax#}

{#syntax#}anyframe{#endsyntax#} can be used as a type for variables which hold pointers to function frames.

*   See also {#link|Async Functions#}

{#syntax#}anytype{#endsyntax#}

Function parameters can be declared with {#syntax#}anytype{#endsyntax#} in place of the type. The type will be inferred where the function is called.

*   See also {#link|Function Parameter Type Inference#}

{#syntax#}asm{#endsyntax#}

{#syntax#}asm{#endsyntax#} begins an inline assembly expression. This allows for directly controlling the machine code generated on compilation.

*   See also {#link|Assembly#}

{#syntax#}break{#endsyntax#}

{#syntax#}break{#endsyntax#} can be used with a block label to return a value from the block. It can also be used to exit a loop before iteration completes naturally.

*   See also {#link|Blocks#}, {#link|while#}, {#link|for#}

{#syntax#}callconv{#endsyntax#}

{#syntax#}callconv{#endsyntax#} can be used to specify the calling convention in a function type.

*   See also {#link|Functions#}

{#syntax#}catch{#endsyntax#}

{#syntax#}catch{#endsyntax#} can be used to evaluate an expression if the expression before it evaluates to an error. The expression after the {#syntax#}catch{#endsyntax#} can optionally capture the error value.

*   See also {#link|catch#}, {#link|Operators#}

{#syntax#}comptime{#endsyntax#}

{#syntax#}comptime{#endsyntax#} before a declaration can be used to label variables or function parameters as known at compile time. It can also be used to guarantee an expression is run at compile time.

*   See also {#link|comptime#}

{#syntax#}const{#endsyntax#}

{#syntax#}const{#endsyntax#} declares a variable that can not be modified. Used as a pointer attribute, it denotes the value referenced by the pointer cannot be modified.

*   See also {#link|Variables#}

{#syntax#}continue{#endsyntax#}

{#syntax#}continue{#endsyntax#} can be used in a loop to jump back to the beginning of the loop.

*   See also {#link|while#}, {#link|for#}

{#syntax#}defer{#endsyntax#}

{#syntax#}defer{#endsyntax#} will execute an expression when control flow leaves the current block.

*   See also {#link|defer#}

{#syntax#}else{#endsyntax#}

{#syntax#}else{#endsyntax#} can be used to provide an alternate branch for {#syntax#}if{#endsyntax#}, {#syntax#}switch{#endsyntax#}, {#syntax#}while{#endsyntax#}, and {#syntax#}for{#endsyntax#} expressions.

*   If used after an if expression, the else branch will be executed if the test value returns false, null, or an error.
*   If used within a switch expression, the else branch will be executed if the test value matches no other cases.
*   If used after a loop expression, the else branch will be executed if the loop finishes without breaking.
*   See also {#link|if#}, {#link|switch#}, {#link|while#}, {#link|for#}

{#syntax#}enum{#endsyntax#}

{#syntax#}enum{#endsyntax#} defines an enum type.

*   See also {#link|enum#}

{#syntax#}errdefer{#endsyntax#}

{#syntax#}errdefer{#endsyntax#} will execute an expression when control flow leaves the current block if the function returns an error, the errdefer expression can capture the unwrapped value.

*   See also {#link|errdefer#}

{#syntax#}error{#endsyntax#}

{#syntax#}error{#endsyntax#} defines an error type.

*   See also {#link|Errors#}

{#syntax#}export{#endsyntax#}

{#syntax#}export{#endsyntax#} makes a function or variable externally visible in the generated object file. Exported functions default to the C calling convention.

*   See also {#link|Functions#}

{#syntax#}extern{#endsyntax#}

{#syntax#}extern{#endsyntax#} can be used to declare a function or variable that will be resolved at link time, when linking statically or at runtime, when linking dynamically.

*   See also {#link|Functions#}

{#syntax#}fn{#endsyntax#}

{#syntax#}fn{#endsyntax#} declares a function.

*   See also {#link|Functions#}

{#syntax#}for{#endsyntax#}

A {#syntax#}for{#endsyntax#} expression can be used to iterate over the elements of a slice, array, or tuple.

*   See also {#link|for#}

{#syntax#}if{#endsyntax#}

An {#syntax#}if{#endsyntax#} expression can test boolean expressions, optional values, or error unions. For optional values or error unions, the if expression can capture the unwrapped value.

*   See also {#link|if#}

{#syntax#}inline{#endsyntax#}

{#syntax#}inline{#endsyntax#} can be used to label a loop expression such that it will be unrolled at compile time. It can also be used to force a function to be inlined at all call sites.

*   See also {#link|inline while#}, {#link|inline for#}, {#link|Functions#}

{#syntax#}linksection{#endsyntax#}

The {#syntax#}linksection{#endsyntax#} keyword can be used to specify what section the function or global variable will be put into (e.g. `.text`).

{#syntax#}noalias{#endsyntax#}

The {#syntax#}noalias{#endsyntax#} keyword.

*   TODO add documentation for noalias

{#syntax#}noinline{#endsyntax#}

{#syntax#}noinline{#endsyntax#} disallows function to be inlined in all call sites.

*   See also {#link|Functions#}

{#syntax#}nosuspend{#endsyntax#}

The {#syntax#}nosuspend{#endsyntax#} keyword can be used in front of a block, statement or expression, to mark a scope where no suspension points are reached. In particular, inside a {#syntax#}nosuspend{#endsyntax#} scope:

*   Using the {#syntax#}suspend{#endsyntax#} keyword results in a compile error.
*   Using {#syntax#}await{#endsyntax#} on a function frame which hasn't completed yet results in safety-checked {#link|Illegal Behavior#}.
*   Calling an async function may result in safety-checked {#link|Illegal Behavior#}, because it's equivalent to `await async some_async_fn()`, which contains an {#syntax#}await{#endsyntax#}.

Code inside a {#syntax#}nosuspend{#endsyntax#} scope does not cause the enclosing function to become an {#link|async function|Async Functions#}.

*   See also {#link|Async Functions#}

{#syntax#}opaque{#endsyntax#}

{#syntax#}opaque{#endsyntax#} defines an opaque type.

*   See also {#link|opaque#}

{#syntax#}or{#endsyntax#}

The boolean operator {#syntax#}or{#endsyntax#}.

*   See also {#link|Operators#}

{#syntax#}orelse{#endsyntax#}

{#syntax#}orelse{#endsyntax#} can be used to evaluate an expression if the expression before it evaluates to null.

*   See also {#link|Optionals#}, {#link|Operators#}

{#syntax#}packed{#endsyntax#}

The {#syntax#}packed{#endsyntax#} keyword before a struct definition changes the struct's in-memory layout to the guaranteed {#syntax#}packed{#endsyntax#} layout.

*   See also {#link|packed struct#}

{#syntax#}pub{#endsyntax#}

The {#syntax#}pub{#endsyntax#} in front of a top level declaration makes the declaration available to reference from a different file than the one it is declared in.

*   See also {#link|import#}

{#syntax#}resume{#endsyntax#}

{#syntax#}resume{#endsyntax#} will continue execution of a function frame after the point the function was suspended.

{#syntax#}return{#endsyntax#}

{#syntax#}return{#endsyntax#} exits a function with a value.

*   See also {#link|Functions#}

{#syntax#}struct{#endsyntax#}

{#syntax#}struct{#endsyntax#} defines a struct.

*   See also {#link|struct#}

{#syntax#}suspend{#endsyntax#}

{#syntax#}suspend{#endsyntax#} will cause control flow to return to the call site or resumer of the function. {#syntax#}suspend{#endsyntax#} can also be used before a block within a function, to allow the function access to its frame before control flow returns to the call site.

{#syntax#}switch{#endsyntax#}

A {#syntax#}switch{#endsyntax#} expression can be used to test values of a common type. {#syntax#}switch{#endsyntax#} cases can capture field values of a {#link|Tagged union#}.

*   See also {#link|switch#}

{#syntax#}test{#endsyntax#}

The {#syntax#}test{#endsyntax#} keyword can be used to denote a top-level block of code used to make sure behavior meets expectations.

*   See also {#link|Zig Test#}

{#syntax#}threadlocal{#endsyntax#}

{#syntax#}threadlocal{#endsyntax#} can be used to specify a variable as thread-local.

*   See also {#link|Thread Local Variables#}

{#syntax#}try{#endsyntax#}

{#syntax#}try{#endsyntax#} evaluates an error union expression. If it is an error, it returns from the current function with the same error. Otherwise, the expression results in the unwrapped value.

*   See also {#link|try#}

{#syntax#}union{#endsyntax#}

{#syntax#}union{#endsyntax#} defines a union.

*   See also {#link|union#}

{#syntax#}unreachable{#endsyntax#}

{#syntax#}unreachable{#endsyntax#} can be used to assert that control flow will never happen upon a particular location. Depending on the build mode, {#syntax#}unreachable{#endsyntax#} may emit a panic.

*   Emits a panic in {#syntax#}Debug{#endsyntax#} and {#syntax#}ReleaseSafe{#endsyntax#} mode, or when using zig test.
*   Does not emit a panic in {#syntax#}ReleaseFast{#endsyntax#} and {#syntax#}ReleaseSmall{#endsyntax#} mode.
*   See also {#link|unreachable#}

{#syntax#}var{#endsyntax#}

{#syntax#}var{#endsyntax#} declares a variable that may be modified.

*   See also {#link|Variables#}

{#syntax#}volatile{#endsyntax#}

{#syntax#}volatile{#endsyntax#} can be used to denote loads or stores of a pointer have side effects. It can also modify an inline assembly expression to denote it has side effects.

*   See also {#link|volatile#}, {#link|Assembly#}

{#syntax#}while{#endsyntax#}

A {#syntax#}while{#endsyntax#} expression can be used to repeatedly test a boolean, optional, or error union expression, and cease looping when that expression evaluates to false, null, or an error, respectively.

*   See also {#link|while#}

{#header\_close#} {#header\_open|Appendix#} {#header\_open|Containers#}

A _container_ in Zig is any syntactical construct that acts as a namespace to hold {#link|variable|Container Level Variables#} and {#link|function|Functions#} declarations. Containers are also type definitions which can be instantiated. {#link|Structs|struct#}, {#link|enums|enum#}, {#link|unions|union#}, {#link|opaques|opaque#}, and even Zig source files themselves are containers.

Although containers (except Zig source files) use curly braces to surround their definition, they should not be confused with {#link|blocks|Blocks#} or functions. Containers do not contain statements.

{#header\_close#} {#header\_open|Grammar#} {#syntax\_block|peg|grammar.peg#} Root <- skip ContainerMembers eof # \*\*\* Top level \*\*\* ContainerMembers <- container\_doc\_comment? ContainerDeclaration\* (ContainerField COMMA)\* (ContainerField / ContainerDeclaration\*) ContainerDeclaration <- TestDecl / ComptimeDecl / doc\_comment? KEYWORD\_pub? Decl TestDecl <- KEYWORD\_test (STRINGLITERALSINGLE / IDENTIFIER)? Block ComptimeDecl <- KEYWORD\_comptime Block Decl <- (KEYWORD\_export / KEYWORD\_extern STRINGLITERALSINGLE? / KEYWORD\_inline / KEYWORD\_noinline)? FnProto (SEMICOLON / Block) / (KEYWORD\_export / KEYWORD\_extern STRINGLITERALSINGLE?)? KEYWORD\_threadlocal? GlobalVarDecl FnProto <- KEYWORD\_fn IDENTIFIER? LPAREN ParamDeclList RPAREN ByteAlign? AddrSpace? LinkSection? CallConv? EXCLAMATIONMARK? TypeExpr VarDeclProto <- (KEYWORD\_const / KEYWORD\_var) IDENTIFIER (COLON TypeExpr)? ByteAlign? AddrSpace? LinkSection? GlobalVarDecl <- VarDeclProto (EQUAL Expr)? SEMICOLON ContainerField <- doc\_comment? KEYWORD\_comptime? !KEYWORD\_fn (IDENTIFIER COLON)? TypeExpr ByteAlign? (EQUAL Expr)? # \*\*\* Block Level \*\*\* Statement <- KEYWORD\_comptime ComptimeStatement / KEYWORD\_nosuspend BlockExprStatement / KEYWORD\_suspend BlockExprStatement / KEYWORD\_defer BlockExprStatement / KEYWORD\_errdefer Payload? BlockExprStatement / IfStatement / LabeledStatement / VarDeclExprStatement ComptimeStatement <- BlockExpr / VarDeclExprStatement IfStatement <- IfPrefix BlockExpr ( KEYWORD\_else Payload? Statement )? / IfPrefix AssignExpr ( SEMICOLON / KEYWORD\_else Payload? Statement ) LabeledStatement <- BlockLabel? (Block / LoopStatement / SwitchExpr) LoopStatement <- KEYWORD\_inline? (ForStatement / WhileStatement) ForStatement <- ForPrefix BlockExpr ( KEYWORD\_else Statement )? / ForPrefix AssignExpr ( SEMICOLON / KEYWORD\_else Statement ) WhileStatement <- WhilePrefix BlockExpr ( KEYWORD\_else Payload? Statement )? / WhilePrefix AssignExpr ( SEMICOLON / KEYWORD\_else Payload? Statement ) BlockExprStatement <- BlockExpr / AssignExpr SEMICOLON BlockExpr <- BlockLabel? Block # An expression, assignment, or any destructure, as a statement. VarDeclExprStatement <- VarDeclProto (COMMA (VarDeclProto / Expr))\* EQUAL Expr SEMICOLON / Expr (AssignOp Expr / (COMMA (VarDeclProto / Expr))+ EQUAL Expr)? SEMICOLON # \*\*\* Expression Level \*\*\* # An assignment or a destructure whose LHS are all lvalue expressions. AssignExpr <- Expr (AssignOp Expr / (COMMA Expr)+ EQUAL Expr)? SingleAssignExpr <- Expr (AssignOp Expr)? Expr <- BoolOrExpr BoolOrExpr <- BoolAndExpr (KEYWORD\_or BoolAndExpr)\* BoolAndExpr <- CompareExpr (KEYWORD\_and CompareExpr)\* CompareExpr <- BitwiseExpr (CompareOp BitwiseExpr)? BitwiseExpr <- BitShiftExpr (BitwiseOp BitShiftExpr)\* BitShiftExpr <- AdditionExpr (BitShiftOp AdditionExpr)\* AdditionExpr <- MultiplyExpr (AdditionOp MultiplyExpr)\* MultiplyExpr <- PrefixExpr (MultiplyOp PrefixExpr)\* PrefixExpr <- PrefixOp\* PrimaryExpr PrimaryExpr <- AsmExpr / IfExpr / KEYWORD\_break BreakLabel? Expr? / KEYWORD\_comptime Expr / KEYWORD\_nosuspend Expr / KEYWORD\_continue BreakLabel? Expr? / KEYWORD\_resume Expr / KEYWORD\_return Expr? / BlockLabel? LoopExpr / Block / CurlySuffixExpr IfExpr <- IfPrefix Expr (KEYWORD\_else Payload? Expr)? Block <- LBRACE Statement\* RBRACE LoopExpr <- KEYWORD\_inline? (ForExpr / WhileExpr) ForExpr <- ForPrefix Expr (KEYWORD\_else Expr)? WhileExpr <- WhilePrefix Expr (KEYWORD\_else Payload? Expr)? CurlySuffixExpr <- TypeExpr InitList? InitList <- LBRACE FieldInit (COMMA FieldInit)\* COMMA? RBRACE / LBRACE Expr (COMMA Expr)\* COMMA? RBRACE / LBRACE RBRACE TypeExpr <- PrefixTypeOp\* ErrorUnionExpr ErrorUnionExpr <- SuffixExpr (EXCLAMATIONMARK TypeExpr)? SuffixExpr <- PrimaryTypeExpr (SuffixOp / FnCallArguments)\* PrimaryTypeExpr <- BUILTINIDENTIFIER FnCallArguments / CHAR\_LITERAL / ContainerDecl / DOT IDENTIFIER / DOT InitList / ErrorSetDecl / FLOAT / FnProto / GroupedExpr / LabeledTypeExpr / IDENTIFIER / IfTypeExpr / INTEGER / KEYWORD\_comptime TypeExpr / KEYWORD\_error DOT IDENTIFIER / KEYWORD\_anyframe / KEYWORD\_unreachable / STRINGLITERAL ContainerDecl <- (KEYWORD\_extern / KEYWORD\_packed)? ContainerDeclAuto ErrorSetDecl <- KEYWORD\_error LBRACE IdentifierList RBRACE GroupedExpr <- LPAREN Expr RPAREN IfTypeExpr <- IfPrefix TypeExpr (KEYWORD\_else Payload? TypeExpr)? LabeledTypeExpr <- BlockLabel Block / BlockLabel? LoopTypeExpr / BlockLabel? SwitchExpr LoopTypeExpr <- KEYWORD\_inline? (ForTypeExpr / WhileTypeExpr) ForTypeExpr <- ForPrefix TypeExpr (KEYWORD\_else TypeExpr)? WhileTypeExpr <- WhilePrefix TypeExpr (KEYWORD\_else Payload? TypeExpr)? SwitchExpr <- KEYWORD\_switch LPAREN Expr RPAREN LBRACE SwitchProngList RBRACE # \*\*\* Assembly \*\*\* AsmExpr <- KEYWORD\_asm KEYWORD\_volatile? LPAREN Expr AsmOutput? RPAREN AsmOutput <- COLON AsmOutputList AsmInput? AsmOutputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN (MINUSRARROW TypeExpr / IDENTIFIER) RPAREN AsmInput <- COLON AsmInputList AsmClobbers? AsmInputItem <- LBRACKET IDENTIFIER RBRACKET STRINGLITERAL LPAREN Expr RPAREN AsmClobbers <- COLON Expr # \*\*\* Helper grammar \*\*\* BreakLabel <- COLON IDENTIFIER BlockLabel <- IDENTIFIER COLON FieldInit <- DOT IDENTIFIER EQUAL Expr WhileContinueExpr <- COLON LPAREN AssignExpr RPAREN LinkSection <- KEYWORD\_linksection LPAREN Expr RPAREN AddrSpace <- KEYWORD\_addrspace LPAREN Expr RPAREN # Fn specific CallConv <- KEYWORD\_callconv LPAREN Expr RPAREN ParamDecl <- doc\_comment? (KEYWORD\_noalias / KEYWORD\_comptime)? (IDENTIFIER COLON)? ParamType / DOT3 ParamType <- KEYWORD\_anytype / TypeExpr # Control flow prefixes IfPrefix <- KEYWORD\_if LPAREN Expr RPAREN PtrPayload? WhilePrefix <- KEYWORD\_while LPAREN Expr RPAREN PtrPayload? WhileContinueExpr? ForPrefix <- KEYWORD\_for LPAREN ForArgumentsList RPAREN PtrListPayload # Payloads Payload <- PIPE IDENTIFIER PIPE PtrPayload <- PIPE ASTERISK? IDENTIFIER PIPE PtrIndexPayload <- PIPE ASTERISK? IDENTIFIER (COMMA IDENTIFIER)? PIPE PtrListPayload <- PIPE ASTERISK? IDENTIFIER (COMMA ASTERISK? IDENTIFIER)\* COMMA? PIPE # Switch specific SwitchProng <- KEYWORD\_inline? SwitchCase EQUALRARROW PtrIndexPayload? SingleAssignExpr SwitchCase <- SwitchItem (COMMA SwitchItem)\* COMMA? / KEYWORD\_else SwitchItem <- Expr (DOT3 Expr)? # For specific ForArgumentsList <- ForItem (COMMA ForItem)\* COMMA? ForItem <- Expr (DOT2 Expr?)? # Operators AssignOp <- ASTERISKEQUAL / ASTERISKPIPEEQUAL / SLASHEQUAL / PERCENTEQUAL / PLUSEQUAL / PLUSPIPEEQUAL / MINUSEQUAL / MINUSPIPEEQUAL / LARROW2EQUAL / LARROW2PIPEEQUAL / RARROW2EQUAL / AMPERSANDEQUAL / CARETEQUAL / PIPEEQUAL / ASTERISKPERCENTEQUAL / PLUSPERCENTEQUAL / MINUSPERCENTEQUAL / EQUAL CompareOp <- EQUALEQUAL / EXCLAMATIONMARKEQUAL / LARROW / RARROW / LARROWEQUAL / RARROWEQUAL BitwiseOp <- AMPERSAND / CARET / PIPE / KEYWORD\_orelse / KEYWORD\_catch Payload? BitShiftOp <- LARROW2 / RARROW2 / LARROW2PIPE AdditionOp <- PLUS / MINUS / PLUS2 / PLUSPERCENT / MINUSPERCENT / PLUSPIPE / MINUSPIPE MultiplyOp <- PIPE2 / ASTERISK / SLASH / PERCENT / ASTERISK2 / ASTERISKPERCENT / ASTERISKPIPE PrefixOp <- EXCLAMATIONMARK / MINUS / TILDE / MINUSPERCENT / AMPERSAND / KEYWORD\_try PrefixTypeOp <- QUESTIONMARK / KEYWORD\_anyframe MINUSRARROW / SliceTypeStart (ByteAlign / AddrSpace / KEYWORD\_const / KEYWORD\_volatile / KEYWORD\_allowzero)\* / PtrTypeStart (AddrSpace / KEYWORD\_align LPAREN Expr (COLON Expr COLON Expr)? RPAREN / KEYWORD\_const / KEYWORD\_volatile / KEYWORD\_allowzero)\* / ArrayTypeStart SuffixOp <- LBRACKET Expr (DOT2 (Expr? (COLON Expr)?)?)? RBRACKET / DOT IDENTIFIER / DOTASTERISK / DOTQUESTIONMARK FnCallArguments <- LPAREN ExprList RPAREN # Ptr specific SliceTypeStart <- LBRACKET (COLON Expr)? RBRACKET PtrTypeStart <- ASTERISK / ASTERISK2 / LBRACKET ASTERISK (LETTERC / COLON Expr)? RBRACKET ArrayTypeStart <- LBRACKET Expr (COLON Expr)? RBRACKET # ContainerDecl specific ContainerDeclAuto <- ContainerDeclType LBRACE ContainerMembers RBRACE ContainerDeclType <- KEYWORD\_struct (LPAREN Expr RPAREN)? / KEYWORD\_opaque / KEYWORD\_enum (LPAREN Expr RPAREN)? / KEYWORD\_union (LPAREN (KEYWORD\_enum (LPAREN Expr RPAREN)? / Expr) RPAREN)? # Alignment ByteAlign <- KEYWORD\_align LPAREN Expr RPAREN # Lists IdentifierList <- (doc\_comment? IDENTIFIER COMMA)\* (doc\_comment? IDENTIFIER)? SwitchProngList <- (SwitchProng COMMA)\* SwitchProng? AsmOutputList <- (AsmOutputItem COMMA)\* AsmOutputItem? AsmInputList <- (AsmInputItem COMMA)\* AsmInputItem? ParamDeclList <- (ParamDecl COMMA)\* ParamDecl? ExprList <- (Expr COMMA)\* Expr? # \*\*\* Tokens \*\*\* eof <- !. bin <- \[01\] bin\_ <- '\_'? bin oct <- \[0-7\] oct\_ <- '\_'? oct hex <- \[0-9a-fA-F\] hex\_ <- '\_'? hex dec <- \[0-9\] dec\_ <- '\_'? dec bin\_int <- bin bin\_\* oct\_int <- oct oct\_\* dec\_int <- dec dec\_\* hex\_int <- hex hex\_\* ox80\_oxBF <- \[\\200-\\277\] oxF4 <- '\\364' ox80\_ox8F <- \[\\200-\\217\] oxF1\_oxF3 <- \[\\361-\\363\] oxF0 <- '\\360' ox90\_0xBF <- \[\\220-\\277\] oxEE\_oxEF <- \[\\356-\\357\] oxED <- '\\355' ox80\_ox9F <- \[\\200-\\237\] oxE1\_oxEC <- \[\\341-\\354\] oxE0 <- '\\340' oxA0\_oxBF <- \[\\240-\\277\] oxC2\_oxDF <- \[\\302-\\337\] # From https://lemire.me/blog/2018/05/09/how-quickly-can-you-check-that-a-string-is-valid-unicode-utf-8/ # First Byte Second Byte Third Byte Fourth Byte # \[0x00,0x7F\] # \[0xC2,0xDF\] \[0x80,0xBF\] # 0xE0 \[0xA0,0xBF\] \[0x80,0xBF\] # \[0xE1,0xEC\] \[0x80,0xBF\] \[0x80,0xBF\] # 0xED \[0x80,0x9F\] \[0x80,0xBF\] # \[0xEE,0xEF\] \[0x80,0xBF\] \[0x80,0xBF\] # 0xF0 \[0x90,0xBF\] \[0x80,0xBF\] \[0x80,0xBF\] # \[0xF1,0xF3\] \[0x80,0xBF\] \[0x80,0xBF\] \[0x80,0xBF\] # 0xF4 \[0x80,0x8F\] \[0x80,0xBF\] \[0x80,0xBF\] multibyte\_utf8 <- oxF4 ox80\_ox8F ox80\_oxBF ox80\_oxBF / oxF1\_oxF3 ox80\_oxBF ox80\_oxBF ox80\_oxBF / oxF0 ox90\_0xBF ox80\_oxBF ox80\_oxBF / oxEE\_oxEF ox80\_oxBF ox80\_oxBF / oxED ox80\_ox9F ox80\_oxBF / oxE1\_oxEC ox80\_oxBF ox80\_oxBF / oxE0 oxA0\_oxBF ox80\_oxBF / oxC2\_oxDF ox80\_oxBF non\_control\_ascii <- \[\\040-\\176\] char\_escape <- "\\\\x" hex hex / "\\\\u{" hex+ "}" / "\\\\" \[nr\\\\t'"\] char\_char <- multibyte\_utf8 / char\_escape / !\[\\\\'\\n\] non\_control\_ascii string\_char <- multibyte\_utf8 / char\_escape / !\[\\\\"\\n\] non\_control\_ascii container\_doc\_comment <- ('//!' \[^\\n\]\* \[ \\n\]\* skip)+ doc\_comment <- ('///' \[^\\n\]\* \[ \\n\]\* skip)+ line\_comment <- '//' !\[!/\]\[^\\n\]\* / '////' \[^\\n\]\* line\_string <- ('\\\\\\\\' \[^\\n\]\* \[ \\n\]\*)+ skip <- (\[ \\n\] / line\_comment)\* CHAR\_LITERAL <- \['\] char\_char \['\] skip FLOAT <- '0x' hex\_int '.' hex\_int (\[pP\] \[-+\]? dec\_int)? skip / dec\_int '.' dec\_int (\[eE\] \[-+\]? dec\_int)? skip / '0x' hex\_int \[pP\] \[-+\]? dec\_int skip / dec\_int \[eE\] \[-+\]? dec\_int skip INTEGER <- '0b' bin\_int skip / '0o' oct\_int skip / '0x' hex\_int skip / dec\_int skip STRINGLITERALSINGLE <- \["\] string\_char\* \["\] skip STRINGLITERAL <- STRINGLITERALSINGLE / (line\_string skip)+ IDENTIFIER <- !keyword \[A-Za-z\_\] \[A-Za-z0-9\_\]\* skip / '@' STRINGLITERALSINGLE BUILTINIDENTIFIER <- '@'\[A-Za-z\_\]\[A-Za-z0-9\_\]\* skip AMPERSAND <- '&' !\[=\] skip AMPERSANDEQUAL <- '&=' skip ASTERISK <- '\*' !\[\*%=|\] skip ASTERISK2 <- '\*\*' skip ASTERISKEQUAL <- '\*=' skip ASTERISKPERCENT <- '\*%' !\[=\] skip ASTERISKPERCENTEQUAL <- '\*%=' skip ASTERISKPIPE <- '\*|' !\[=\] skip ASTERISKPIPEEQUAL <- '\*|=' skip CARET <- '^' !\[=\] skip CARETEQUAL <- '^=' skip COLON <- ':' skip COMMA <- ',' skip DOT <- '.' !\[\*.?\] skip DOT2 <- '..' !\[.\] skip DOT3 <- '...' skip DOTASTERISK <- '.\*' skip DOTQUESTIONMARK <- '.?' skip EQUAL <- '=' !\[>=\] skip EQUALEQUAL <- '==' skip EQUALRARROW <- '=>' skip EXCLAMATIONMARK <- '!' !\[=\] skip EXCLAMATIONMARKEQUAL <- '!=' skip LARROW <- '<' !\[<=\] skip LARROW2 <- '<<' !\[=|\] skip LARROW2EQUAL <- '<<=' skip LARROW2PIPE <- '<<|' !\[=\] skip LARROW2PIPEEQUAL <- '<<|=' skip LARROWEQUAL <- '<=' skip LBRACE <- '{' skip LBRACKET <- '\[' skip LPAREN <- '(' skip MINUS <- '-' !\[%=>|\] skip MINUSEQUAL <- '-=' skip MINUSPERCENT <- '-%' !\[=\] skip MINUSPERCENTEQUAL <- '-%=' skip MINUSPIPE <- '-|' !\[=\] skip MINUSPIPEEQUAL <- '-|=' skip MINUSRARROW <- '->' skip PERCENT <- '%' !\[=\] skip PERCENTEQUAL <- '%=' skip PIPE <- '|' !\[|=\] skip PIPE2 <- '||' skip PIPEEQUAL <- '|=' skip PLUS <- '+' !\[%+=|\] skip PLUS2 <- '++' skip PLUSEQUAL <- '+=' skip PLUSPERCENT <- '+%' !\[=\] skip PLUSPERCENTEQUAL <- '+%=' skip PLUSPIPE <- '+|' !\[=\] skip PLUSPIPEEQUAL <- '+|=' skip LETTERC <- 'c' skip QUESTIONMARK <- '?' skip RARROW <- '>' !\[>=\] skip RARROW2 <- '>>' !\[=\] skip RARROW2EQUAL <- '>>=' skip RARROWEQUAL <- '>=' skip RBRACE <- '}' skip RBRACKET <- '\]' skip RPAREN <- ')' skip SEMICOLON <- ';' skip SLASH <- '/' !\[=\] skip SLASHEQUAL <- '/=' skip TILDE <- '~' skip end\_of\_word <- !\[a-zA-Z0-9\_\] skip KEYWORD\_addrspace <- 'addrspace' end\_of\_word KEYWORD\_align <- 'align' end\_of\_word KEYWORD\_allowzero <- 'allowzero' end\_of\_word KEYWORD\_and <- 'and' end\_of\_word KEYWORD\_anyframe <- 'anyframe' end\_of\_word KEYWORD\_anytype <- 'anytype' end\_of\_word KEYWORD\_asm <- 'asm' end\_of\_word KEYWORD\_break <- 'break' end\_of\_word KEYWORD\_callconv <- 'callconv' end\_of\_word KEYWORD\_catch <- 'catch' end\_of\_word KEYWORD\_comptime <- 'comptime' end\_of\_word KEYWORD\_const <- 'const' end\_of\_word KEYWORD\_continue <- 'continue' end\_of\_word KEYWORD\_defer <- 'defer' end\_of\_word KEYWORD\_else <- 'else' end\_of\_word KEYWORD\_enum <- 'enum' end\_of\_word KEYWORD\_errdefer <- 'errdefer' end\_of\_word KEYWORD\_error <- 'error' end\_of\_word KEYWORD\_export <- 'export' end\_of\_word KEYWORD\_extern <- 'extern' end\_of\_word KEYWORD\_fn <- 'fn' end\_of\_word KEYWORD\_for <- 'for' end\_of\_word KEYWORD\_if <- 'if' end\_of\_word KEYWORD\_inline <- 'inline' end\_of\_word KEYWORD\_noalias <- 'noalias' end\_of\_word KEYWORD\_nosuspend <- 'nosuspend' end\_of\_word KEYWORD\_noinline <- 'noinline' end\_of\_word KEYWORD\_opaque <- 'opaque' end\_of\_word KEYWORD\_or <- 'or' end\_of\_word KEYWORD\_orelse <- 'orelse' end\_of\_word KEYWORD\_packed <- 'packed' end\_of\_word KEYWORD\_pub <- 'pub' end\_of\_word KEYWORD\_resume <- 'resume' end\_of\_word KEYWORD\_return <- 'return' end\_of\_word KEYWORD\_linksection <- 'linksection' end\_of\_word KEYWORD\_struct <- 'struct' end\_of\_word KEYWORD\_suspend <- 'suspend' end\_of\_word KEYWORD\_switch <- 'switch' end\_of\_word KEYWORD\_test <- 'test' end\_of\_word KEYWORD\_threadlocal <- 'threadlocal' end\_of\_word KEYWORD\_try <- 'try' end\_of\_word KEYWORD\_union <- 'union' end\_of\_word KEYWORD\_unreachable <- 'unreachable' end\_of\_word KEYWORD\_var <- 'var' end\_of\_word KEYWORD\_volatile <- 'volatile' end\_of\_word KEYWORD\_while <- 'while' end\_of\_word keyword <- KEYWORD\_addrspace / KEYWORD\_align / KEYWORD\_allowzero / KEYWORD\_and / KEYWORD\_anyframe / KEYWORD\_anytype / KEYWORD\_asm / KEYWORD\_break / KEYWORD\_callconv / KEYWORD\_catch / KEYWORD\_comptime / KEYWORD\_const / KEYWORD\_continue / KEYWORD\_defer / KEYWORD\_else / KEYWORD\_enum / KEYWORD\_errdefer / KEYWORD\_error / KEYWORD\_export / KEYWORD\_extern / KEYWORD\_fn / KEYWORD\_for / KEYWORD\_if / KEYWORD\_inline / KEYWORD\_noalias / KEYWORD\_nosuspend / KEYWORD\_noinline / KEYWORD\_opaque / KEYWORD\_or / KEYWORD\_orelse / KEYWORD\_packed / KEYWORD\_pub / KEYWORD\_resume / KEYWORD\_return / KEYWORD\_linksection / KEYWORD\_struct / KEYWORD\_suspend / KEYWORD\_switch / KEYWORD\_test / KEYWORD\_threadlocal / KEYWORD\_try / KEYWORD\_union / KEYWORD\_unreachable / KEYWORD\_var / KEYWORD\_volatile / KEYWORD\_while {#end\_syntax\_block#} {#header\_close#} {#header\_open|Zen#}

*   Communicate intent precisely.
*   Edge cases matter.
*   Favor reading code over writing code.
*   Only one obvious way to do things.
*   Runtime crashes are better than bugs.
*   Compile errors are better than runtime crashes.
*   Incremental improvements.
*   Avoid local maximums.
*   Reduce the amount one must remember.
*   Focus on code rather than style.
*   Resource allocation may fail; resource deallocation must succeed.
*   Memory is a resource.
*   Together we serve the users.

{#header\_close#} {#header\_close#}
