#Direct cmake to use this file by passing -DCMAKE_TOOLCHAIN_FILE=/path/to/this/file
SET(CMAKE_SYSTEM_NAME Linux)

SET (TARGET_TRIPLE "x86_64-linux-gnu")
#SET (COMPILER_PREFIX "${TARGET_TRIPLE}-")
SET (TARGET_SYSROOT "/Volumes/UbbyHD")
#SET (CROSSCOMPILER_ROOT_PATH /Users/abigagli/LLVM-TOT/bin)
#SET (CROSSCOMPILER_DISTCC_MASQUERADE_PATH /Users/abigagli/bin/distcc_masquerade)

SET (CMAKE_CXX_FLAGS_INIT   "-target ${TARGET_TRIPLE}")
SET (CMAKE_C_FLAGS_INIT     "-target ${TARGET_TRIPLE}")
SET (CMAKE_EXE_LINKER_FLAGS_INIT "-target ${TARGET_TRIPLE} -fuse-ld=lld")
SET (CMAKE_SHARED_LINKER_FLAGS_INIT "-target ${TARGET_TRIPLE} -fuse-ld=lld")


#When using cmake-based IDEs (i.e. CLion) you usually pass a -DCMAKE_TOOLCHAIN=/path/to/this/file
#in their CMake-related preferences section, and setting CMAKE_CXX_FLAGS as early as possible (i.e. here)
#seems to help them correctly pick up the required flags.
#NOTE: This will be anyway eventually overwritten in the cmake cache during normal cmake configuration
#IF ($ENV{CLION_IDE})
#    SET (CMAKE_CXX_FLAGS_INIT "${CMAKE_CXX_FLAGS_INIT} -Wall -Wextra -g3 -pthread -std=c++17")
#ENDIF()


#NOTE: THIS CAUSES A "--sysroot=<...>" TO BE PASSED IN AT EACH COMPILER INVOCATION,
#WHICH BREAKS distcc DISTRIBUTED COMPILATION ON THE REMOTE HOSTS (where the <...> path used for sysroot doesn't clearly make sense)
SET(CMAKE_SYSROOT "${TARGET_SYSROOT}")

#When building external projects, CMAKE_SYSROOT does not have any effect, so we define a convenience macro to be used
#to force setting sysroot properly (e.g. to be passed during configure with "CFLAGS=${CMAKE_C_FLAGS} ${CROSS_COMPILE_EXTRA_FLAGS_FOR_EXTERNAL_PROJECTS}")
SET(CROSS_COMPILE_EXTRA_FLAGS_FOR_EXTERNAL_PROJECTS "-target ${TARGET_TRIPLE} --sysroot=${TARGET_SYSROOT}")


#Not sure if/what this is needed for
#SET(CMAKE_STAGING_PREFIX /tmp/GTP_STAGING)


#If not explicitly setting CMAKE_SYSROOT, then we need to do this to configure the root path for the FIND_xxx facilities
#SET(CMAKE_FIND_ROOT_PATH "${TARGET_SYSROOT}")


SET(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
SET(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
SET(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)


##This module defines macros intended for use by cross-compiling toolchain
##files when CMake is not able to automatically detect the compiler identification.
##Not used as it seems like our cross-compiler can be correctly detected
#INCLUDE(CMakeForceCompiler)
#CMAKE_FORCE_C_COMPILER(x86_64-linux-gnu-gcc GNU)
#CMAKE_FORCE_CXX_COMPILER(x86_64-linux-gnu-g++ GNU)
