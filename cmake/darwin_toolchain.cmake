#Direct cmake to use this file by passing -DCMAKE_TOOLCHAIN_FILE=/path/to/this/file
SET(CMAKE_SYSTEM_NAME Linux)

SET (TARGET_TRIPLE "x86_64-linux-gnu")
SET (COMPILER_PREFIX "${TARGET_TRIPLE}-")
SET (TARGET_SYSROOT "/Volumes/UbbyHD")
SET (CROSSCOMPILER_ROOT_PATH /Users/abigagli/GCC-CURRENT/bin)
SET (CROSSCOMPILER_DISTCC_MASQUERADE_PATH /Users/abigagli/bin/distcc_masquerade)

#Apparently, despite --sysroot=${TARGET_SYSROOT} being passed to each compiler invocation
#(because of setting CMAKE_SYSROOT, see later on) current ${COMPILER_PREFIX}ld
#seems to require an explicit help to locate libraries...
SET (CMAKE_CXX_FLAGS_INIT "-L${TARGET_SYSROOT}/lib/${TARGET_TRIPLE} -L${TARGET_SYSROOT}/usr/lib/${TARGET_TRIPLE} -Wl,-rpath-link,${TARGET_SYSROOT}/lib/${TARGET_TRIPLE} -Wl,-rpath-link,${TARGET_SYSROOT}/usr/lib/${TARGET_TRIPLE}")
SET (CMAKE_C_FLAGS_INIT "${CMAKE_CXX_FLAGS_INIT}")

#When using cmake-based IDEs (i.e. CLion) you usually pass a -DCMAKE_TOOLCHAIN=/path/to/this/file
#in their CMake-related preferences section, and setting CMAKE_CXX_FLAGS as early as possible (i.e. here)
#seems to help them correctly pick up the required flags.
#NOTE: This will be anyway eventually overwritten in the cmake cache during normal cmake configuration
IF ($ENV{CLION_IDE})
    SET (CMAKE_CXX_FLAGS_INIT "${CMAKE_CXX_FLAGS_INIT} -Wall -Wextra -m64 -g3 -pthread -std=c++14")
ENDIF()

#We want use the distcc masquerades as the compilers so that we'll leverage distributed compilation if possible
######## NOTE ##########
#For distributed compilation to correctly work, the compilation server must have a compiler named ${COMPILER_PREFIX}g++/gcc in path
FIND_PROGRAM (CMAKE_CXX_COMPILER NAMES ${COMPILER_PREFIX}g++ PATHS ${CROSSCOMPILER_DISTCC_MASQUERADE_PATH} NO_DEFAULT_PATH)
FIND_PROGRAM (CMAKE_C_COMPILER NAMES ${COMPILER_PREFIX}gcc PATHS ${CROSSCOMPILER_DISTCC_MASQUERADE_PATH} NO_DEFAULT_PATH)

#The other crosstools are instead the standard ones found in CROSSOMPILER_ROOT_PATH
FIND_PROGRAM (CMAKE_LINKER NAMES ${COMPILER_PREFIX}ld PATHS ${CROSSCOMPILER_ROOT_PATH} NO_DEFAULT_PATH)
FIND_PROGRAM (CMAKE_AR NAMES ${COMPILER_PREFIX}ar PATHS ${CROSSCOMPILER_ROOT_PATH} NO_DEFAULT_PATH)
FIND_PROGRAM (CMAKE_RANLIB NAMES ${COMPILER_PREFIX}ranlib PATHS ${CROSSCOMPILER_ROOT_PATH} NO_DEFAULT_PATH)


#HORRIBLE_HACK: (OBSOLETE SINCE I WAS ABLE TO BUILD A SELF-HOSTED CROSS-COMPILER WHICH MAINTAINS SUPPORT OF --sysroot)
#The latest x86-linux-gnu cross compiler has been (more properly) built together with its associated cross-glibc, which means it has its own header/libraries "sysroot" in x86_64-linux-gnu/{include,lib}.
#In other words it has a "self-contained" sysroot and we don't need anymore access to a (external) target sysroot (e.g. mounting a real linux filesystem) to peek into <sysroot>/usr/{include,lib} for anything related to the compiler itself.
#The problem is that we still need a (external) target sysroot as a shortcut to access 3rdParties (e.g. boost etc.) compiled for the target instead of recompiling all the 3rdParties we need and put them into our self-contained sysroot x86_64-linux-gnu/{include,lib}, (which would be the right thing to do, though).
#So, being lazy, we let find_package peek inside TARGET_SYSROOT (where it will e.g. successfully find boost), but this causes cmake to add a -I${TARGET_SYSROOT}/include to the compilation flags (because that's how you access the headers of the package found in TARGET_SYSROOT
#This has the effect of TARGET_SYSROOT/usr/include/features.h to be picked up, which is unfortunately related to the target system's glibc, which is apparently older than the one we cross-compiled and so it doesn't support things like the capability checking macros "__GLIBC_USE"
#With the following we ensure that the cross-compiled glibc's features.h is included from the self-contained sysroot instead, and it seems to have solved the problem for now.
#I'M FULLY AWARE that this is in any case an incorrect solution, because we'll still be accessing 3rdParties from the TARGET_SYSROOT which have been built agains that same older glibc that we don't want to have anything to do with...

#SET (GLIBC_COMPATIBILITY_OPTIONS "-include /Volumes/develop/GNU_FACTORY/INSTALL/x86_64-linux-gnu/include/features.h")




#This is an apparently redundant attempt to help FIND_PACKAGE find boost libraries' binaries.
#Everything seems to work just fine with simply setting the proper CMAKE_FIND_ROOT_PATH_MODE_xxxx variables (see at the end)
#SET(BOOST_LIBRARYDIR ${TARGET_SYSROOT}/lib ${TARGET_SYSROOT}/usr/lib/${COMPILER_PREFIX})



#TODO: PROBABLY THIS WILL BE NECESSARY TO PROPER HANDLE RPATH WHEN INSTALLING
#NOTE: THIS CAUSES A "--sysroot=<...>" TO BE PASSED IN AT EACH COMPILER INVOCATION,
#WHICH BREAKS distcc DISTRIBUTED COMPILATION ON THE REMOTE HOSTS (where the <...> path used for sysroot doesn't clearly make sense)
SET(CMAKE_SYSROOT "${TARGET_SYSROOT}")

#When building external projects, CMAKE_SYSROOT does not have any effect, so we define a convenience macro to be used
#to force setting sysroot properly (e.g. to be passed during configure with "CFLAGS=${CMAKE_C_FLAGS} ${CROSS_COMPILE_EXTRA_FLAGS_FOR_EXTERNAL_PROJECTS}")
SET(CROSS_COMPILE_EXTRA_FLAGS_FOR_EXTERNAL_PROJECTS "--sysroot=${TARGET_SYSROOT}")


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
