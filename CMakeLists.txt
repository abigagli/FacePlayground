CMAKE_MINIMUM_REQUIRED(VERSION 3.0)
CMAKE_POLICY (VERSION 3.0)
CMAKE_POLICY (SET CMP0063 NEW)

IF("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_BINARY_DIR}")
    MESSAGE(FATAL_ERROR "Do not build in-source. Please remove CMakeCache.txt and the CMakeFiles/ directory. Then build out-of-source.")
ENDIF()

FIND_PROGRAM(CCACHE_FOUND ccache)
IF(CCACHE_FOUND)
    #SET(ENV{CCACHE_PREFIX} "distcc")
    SET_PROPERTY(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
    SET_PROPERTY(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
ENDIF(CCACHE_FOUND)


PROJECT(PLAYGROUND VERSION 0.1)
IF (NOT CMAKE_BUILD_TYPE)
    MESSAGE (FATAL_ERROR "Please specify CMAKE_BUILD_TYPE")
ENDIF()

#LIST(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/Modules)
INCLUDE (CheckIncludeFileCXX)

SET (CMAKE_CXX_STANDARD 14)
SET (CMAKE_CXX_STANDARD_REQUIRED ON)
SET (CMAKE_CXX_VISIBILITY_PRESET "hidden")
SET (CMAKE_C_VISIBILITY_PRESET "hidden")
SET (CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE BOOL "Generate compile_commands.json for clang tools" FORCE)

#Just be conservative and for now prevent using different breed of C/CXX compilers
IF (NOT "${CMAKE_CXX_COMPILER_ID}" STREQUAL "${CMAKE_C_COMPILER_ID}")
    MESSAGE (FATAL_ERROR "CMAKE_CXX_COMPILER_ID=${CMAKE_CXX_COMPILER_ID} != CMAKE_C_COMPILER_ID=${CMAKE_C_COMPILER_ID}")
ENDIF()

IF ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    EXECUTE_PROCESS (COMMAND ${CMAKE_CXX_COMPILER} -print-prog-name=clang++ OUTPUT_VARIABLE CLANG_EXE_PATH OUTPUT_STRIP_TRAILING_WHITESPACE)

    IF (CMAKE_CROSSCOMPILING)
        #When cross-compiling, since we rely on libraries in sysroot (which most probably are linked with libstdc++)
        #we default to _NOT_ use libc++
        OPTION (CLANG_USE_LIBCXX "Use libc++ instead of libstdc++ when building with clang" OFF)

        #Need to brute-force cross-compilation through clang to use llvm versions of some binutils progs...
        GET_FILENAME_COMPONENT(CLANG_EXE_FOLDER ${CLANG_EXE_PATH} DIRECTORY)
        GET_FILENAME_COMPONENT(CLANG_EXE_FOLDER ${CLANG_EXE_FOLDER} REALPATH)
        SET (CMAKE_LINKER "${CLANG_EXE_FOLDER}/ld.lld" CACHE STRING "VALUE FORCED FOR CROSS-COMPILATION" FORCE)
        SET (CMAKE_AR "${CLANG_EXE_FOLDER}/llvm-ar" CACHE STRING "VALUE FORCED FOR CROSS-COMPILATION" FORCE)
        SET (CMAKE_RANLIB "${CLANG_EXE_FOLDER}/llvm-ranlib" CACHE STRING "VALUE FORCED FOR CROSS-COMPILATION" FORCE)
    ELSE()
        #For a normal (non-cross) build with clang, we default to use libc++
        OPTION (CLANG_USE_LIBCXX "Use libc++ instead of libstdc++ when building with clang (switch off if using zapcc)" ON)
        #...And to use the lld linker
        OPTION (CLANG_USE_LLD_LINKER "Use lld linker (switch off if using zapcc)" ON)
        #Assuming we're using a tot clang build from sources, when NOT crosscompiling we want to ensure we're picking up the libraries built with it,
        #and don't risk picking up the ones potentially already installed on the system, so we ensure we refer to the path where the
        #tot binaries were installed and locate everything else from there...
        GET_FILENAME_COMPONENT(COMPILER_LIBS_FOLDER ${CLANG_EXE_PATH} DIRECTORY)
        GET_FILENAME_COMPONENT(COMPILER_LIBS_FOLDER "${COMPILER_LIBS_FOLDER}/../lib" REALPATH)
    ENDIF()
ELSE()
    UNSET (CLANG_USE_LIBCXX CACHE)
    UNSET (CLANG_USE_LLD_LINKER CACHE)
    EXECUTE_PROCESS (COMMAND ${CMAKE_CXX_COMPILER} -print-file-name=libstdc++.so OUTPUT_VARIABLE LIBSTDCPP_PATH OUTPUT_STRIP_TRAILING_WHITESPACE)
    GET_FILENAME_COMPONENT(COMPILER_LIBS_FOLDER ${LIBSTDCPP_PATH} DIRECTORY)
    GET_FILENAME_COMPONENT(COMPILER_LIBS_FOLDER "${COMPILER_LIBS_FOLDER}" REALPATH)
ENDIF()

#REFINE CACHED COMPILER/LINKER FLAGS WITH PROJECT SPECIFICS
SET (CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O0")
SET (CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -g3")
SET (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -m64")

IF ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")

    IF (CMAKE_CROSSCOMPILING)
        #When crosscompiling we _DO_ want to rely on the sysroot version of libc++. To avoid the compiler to use "its own" version during compilation, 
        #we explicitly force it to look at the sysroot one.
        #NOTE: When doing this, -stdlib=libc++ is redundant and actuall not used by the compiler driver
        IF (CLANG_USE_LIBCXX)
            SET (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -nostdinc++ -isystem ${TARGET_SYSROOT}/usr/include/c++/v1")
            MESSAGE (WARNING "Cross-compilation with clang's libc++ requires all libraries in sysroot to be built with libc++ as well")
        ENDIF()
    ELSE()
        IF (CLANG_USE_LIBCXX)
            SET (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -stdlib=libc++")
        ENDIF()
    ENDIF()

    IF(CCACHE_FOUND)
        #When using clang, ccache might cause spurious "commandline argument unused" warnings, and also
        #switch off colors, so we must pass special flags to prevent that
        SET (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Qunused-arguments -fcolor-diagnostics")
    ENDIF()
ENDIF()




SET (CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -O0")
SET (CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -g3")
SET (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra -m64")

IF ("${CMAKE_C_COMPILER_ID}" STREQUAL "Clang")
    #SET (CMAKE_C_FLAGS "${CMAKE_C_FLAGS}") #Nothing do here for now
    IF(CCACHE_FOUND)
        #When using clang, ccache might cause spurious "commandline argument unused" warnings, and also
        #switch off colors, so we must pass special flags to prevent that
        SET (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Qunused-arguments -fcolor-diagnostics")
    ENDIF()
ENDIF()




SET (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}")

IF ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")

    IF (CLANG_USE_LLD_LINKER)
        SET (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=lld")
    ENDIF()

    IF (CMAKE_CROSSCOMPILING)
        #Since we're crosscompiling and we _DO_ want to rely on the sysroot version of libc++, we don't specify a library search path pointing to the host-compiler lib folder
        #NOTE: It's not clear why when cross-compling we have to explicitly add a dependency on libc++abi on the link line, even though I've verified that the sysroot libc++ has indeed already a dependency on it

        IF (CLANG_USE_LIBCXX)
            SET (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -stdlib=libc++ -lc++abi")
            MESSAGE (WARNING "Cross-compilation with clang's libc++ requires all libraries in sysroot to be built with libc++ as well")
        ENDIF()
    ELSE()
        #We do _NOT_ want the linker to use any other version of libc++ that might already be installed, so we force to look for library into the host-compiler lib folder.
        #NOTE: As expected (and differently from what happens when cross compiling) since the self-compiled libc++ binaries depend on libc++abi, we must also provide the same host-compiler lib path as a -rpath argument to allow the second-level dependency to be resolved at runtime
        IF (CLANG_USE_LIBCXX)
            SET (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -stdlib=libc++ -L${COMPILER_LIBS_FOLDER} -rpath ${COMPILER_LIBS_FOLDER}")
        ENDIF()
    ENDIF()

    IF(CCACHE_FOUND)
        #When using clang, ccache might cause spurious "commandline argument unused" warnings, and also
        #switch off colors, so we must pass special flags to prevent that
        SET (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Qunused-arguments -fcolor-diagnostics")
    ENDIF()
ENDIF()

SET (CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}")

IF ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")

    IF (CLANG_USE_LLD_LINKER)
        SET (CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fuse-ld=lld")
    ENDIF()

    IF (CMAKE_CROSSCOMPILING)

        IF (CLANG_USE_LIBCXX)
            SET (CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -stdlib=libc++")
            MESSAGE (WARNING "Cross-compilation with clang's libc++ requires all libraries in sysroot to be built with libc++ as well")
        ENDIF()
    ELSE()
        IF (CLANG_USE_LIBCXX)
            SET (CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -stdlib=libc++ -L${COMPILER_LIBS_FOLDER}")
        ENDIF()
    ENDIF()

    IF(CCACHE_FOUND)
        #When using clang, ccache might cause spurious "commandline argument unused" warnings, and also
        #switch off colors, so we must pass special flags to prevent that
        SET (CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Qunused-arguments -fcolor-diagnostics")
    ENDIF()
ENDIF()
############################################################


#[==[
#COMMENTED OUT
SET(Boost_USE_MULTITHREADED ON)
SET(Boost_USE_STATIC_LIBS OFF)
FIND_PACKAGE (Boost 1.55 REQUIRED)

GET_PROPERTY (KNOWN_FEATURES GLOBAL PROPERTY CMAKE_CXX_KNOWN_FEATURES)
MESSAGE ("Features known by CMAKE = ${KNOWN_FEATURES}")
MESSAGE ("Features supported by this compiler = ${CMAKE_CXX_COMPILE_FEATURES}")
#]==]




OPTION (BUILD_UNIT_TESTS "Build unit tests" ON)

IF (BUILD_UNIT_TESTS)
    ENABLE_TESTING()
    #INCLUDE(gmock)
ENDIF()

SET (ARCH_NATIVE_LABEL "Native")
SET (ARCH_IVYBRIDGE_LABEL "E5-2680 v2 - ivybridge")
SET (ARCH_SANDYBRIDGE_LABEL "E5-2430 0 - sandybridge")
SET (ARCH_BROADWELL_LABEL "E5-2640 v4 - broadwell")

SET (OPT_ARCH ${ARCH_NATIVE_LABEL} CACHE STRING "The optimization profile")
SET_PROPERTY (CACHE OPT_ARCH PROPERTY STRINGS   "${ARCH_NATIVE_LABEL}"
                                                "${ARCH_IVYBRIDGE_LABEL}"
                                                "${ARCH_SANDYBRIDGE_LABEL}"
                                                "${ARCH_BROADWELL_LABEL}")

IF (CMAKE_CROSSCOMPILING AND NOT "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    #For some reason, cross-compiling with a "normal" x86_64-linux-gnu cross compiler (as opposed to using clang -target x86_64-linux-gnu)
    #doesn't work e.g. with -march=native, so I force/override a different architecture just to make DPDK build happy
    #NOTE: This creates a "Directory-scope" variable, which has precedence over a "Cache-scope" one when evaluating ${VARNAME} variable references
    #IOW: SET-bindings have precedence over CACHE-bindings
    SET (OPT_ARCH "${ARCH_SANDYBRIDGE_LABEL}")
ENDIF()


SET (NUM_PROCESSORS 1)
SET (CPUINFO_FILE "/proc/cpuinfo")
IF  (EXISTS "${CPUINFO_FILE}")
    FILE (STRINGS "${CPUINFO_FILE}" PROCESSORS REGEX "^processor.: [0-9]+$")
    LIST (LENGTH PROCESSORS NUM_PROCESSORS)
ENDIF()

SET (PROCESSOR_COUNT ${NUM_PROCESSORS} CACHE STRING "Number of available processors")




SET (GENERATED_CODE_FOLDER ${CMAKE_BINARY_DIR}/generated_code)

#Communicate with the codebase
SET (THIS_IS_ON ON)
SET (THIS_IS_OFF OFF)
SET (TEST1 CameFromTest1)
SET (TEST2 CameFromTest2)

CONFIGURE_FILE (compiletime_config/config.h.in ${GENERATED_CODE_FOLDER}/config_generated.h)

#Make sure everything is able to access generatd source files and boost headers
#INCLUDE_DIRECTORIES (${GENERATED_CODE_FOLDER} ${Boost_INCLUDE_DIR})
INCLUDE_DIRECTORIES (${GENERATED_CODE_FOLDER})


MESSAGE ("\n")
MESSAGE ("Compiler ID: ${CMAKE_CXX_COMPILER_ID}")
MESSAGE ("Compiler VERSION: ${CMAKE_CXX_COMPILER_VERSION}")
MESSAGE ("System Name: ${CMAKE_SYSTEM_NAME}")
MESSAGE ("System Version: ${CMAKE_SYSTEM_VERSION}")
MESSAGE ("Build Type: ${CMAKE_BUILD_TYPE}")
MESSAGE ("Install Prefix: ${CMAKE_INSTALL_PREFIX}")
#MESSAGE ("Boost Include: ${Boost_INCLUDE_DIR}")
MESSAGE ("CMAKE_CXX_COMPILER: ${CMAKE_CXX_COMPILER}")
MESSAGE ("CMAKE_C_COMPILER: ${CMAKE_C_COMPILER}")
MESSAGE ("CMAKE_LINKER: ${CMAKE_LINKER}")
MESSAGE ("CMAKE_AR: ${CMAKE_AR}")
MESSAGE ("CMAKE_RANLIB: ${CMAKE_RANLIB}")
MESSAGE ("CMAKE_CXX_FLAGS: ${CMAKE_CXX_FLAGS}")
MESSAGE ("CMAKE_CXX_FLAGS_DEBUG: ${CMAKE_CXX_FLAGS_DEBUG}")
MESSAGE ("CMAKE_CXX_FLAGS_RELEASE: ${CMAKE_CXX_FLAGS_RELEASE}")
MESSAGE ("CMAKE_CXX_FLAGS_RELWITHDEBINFO: ${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
MESSAGE ("CMAKE_C_FLAGS: ${CMAKE_C_FLAGS}")
MESSAGE ("CMAKE_C_FLAGS_DEBUG: ${CMAKE_C_FLAGS_DEBUG}")
MESSAGE ("CMAKE_C_FLAGS_RELEASE: ${CMAKE_C_FLAGS_RELEASE}")
MESSAGE ("CMAKE_C_FLAGS_RELWITHDEBINFO: ${CMAKE_C_FLAGS_RELWITHDEBINFO}")
MESSAGE ("CMAKE_EXPORT_COMPILE_COMMANDS: ${CMAKE_EXPORT_COMPILE_COMMANDS}")
MESSAGE ("CMAKE_CROSSCOMPILING: ${CMAKE_CROSSCOMPILING}")
IF (CMAKE_CROSSCOMPILING)
    MESSAGE ("TARGET_SYSROOT for cross-compilation: ${TARGET_SYSROOT}")
ENDIF()


# ###############################################
# configure RPATH handling so that it is correctly set both
# for build and install time
# (see http://www.cmake.org/Wiki/CMake_RPATH_handling and http://www.kitware.com/blog/home/post/510)

# use, i.e. don't skip the full RPATH for the build tree, this allows running
# executables from the build tree without having to mess with DYLD_LIBRARY_PATH etc..
SET(CMAKE_SKIP_BUILD_RPATH  FALSE)
#
# when building, don't use the install RPATH already
# (but later on when installing)
SET(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
#
# Do NOT add the automatically determined parts of the RPATH
# which point to directories outside the build tree to the install RPATH
# This is to prevent rpaths pointing to external 3rdparties to remain into
# installed binaries (which should only rely on libraries found
# in the system and $ORIGIN/libexec)
# For example, say that a target links with /home/bla/3rdpartylib/lib/lib3rdparty.so
# during development it's ok for the target to have an rpath that contains /home/bla/3rdpartylib/lib
# but when installing, lib3rdparty.so will be copied into $ORIGIN/libexec and the installed target
# should not be able anymore to find it in /home/bla/3rpartylib/lib (but only in $ORIGIN/libexec)
# to avoid the possibility that on the deployed server it could pick up a different version
# of lib3rdparty.so if for some reason the deployed server has a /home/bla/3rdpartylib/lib/libparty.so too
SET(CMAKE_INSTALL_RPATH_USE_LINK_PATH FALSE)
#
#
# the RPATH to be used when installing, but only if it's not a system directory
LIST(FIND CMAKE_PLATFORM_IMPLICIT_LINK_DIRECTORIES "${CMAKE_INSTALL_PREFIX}/libexec" isSystemDir)
IF("${isSystemDir}" STREQUAL "-1")
    SET(CMAKE_INSTALL_RPATH "\$ORIGIN/libexec:\$ORIGIN/../libexec")
ENDIF()


FUNCTION(ECHO_ALL_CMAKE_VARIABLE_VALUES)
    MESSAGE(STATUS "")
    GET_CMAKE_PROPERTY(vs VARIABLES)
    FOREACH(v ${vs})
        MESSAGE(STATUS "${v}='${${v}}'")
    ENDFOREACH(v)
    MESSAGE(STATUS "")
ENDFUNCTION()


#A function that recursively scans a target dependencies, and "stage" them in the specified DEPENDENCIES_INSTALL_DIR
#while at the same time creating proper symlinks <SONAME> --> <ACTUALNAME>
FUNCTION (INSTALL_TARGET_AND_ITS_DEPENDENCIES TARGET TARGET_INSTALL_DIR DEPENDENCIES_INSTALL_DIR DEPENDENCIES_SEARCH_DIRS) #[SYMLINK_AT_TOPLEVEL]

    SET (SYMLINK_AT_TOPLEVEL FALSE)

    IF (ARGC GREATER 4)
        SET (SYMLINK_AT_TOPLEVEL ${ARGV4})
    ENDIF()

    LIST(APPEND DEPENDENCIES_SEARCH_DIRS ${COMPILER_LIBS_FOLDER})

    CONFIGURE_FILE (
        ${CMAKE_SOURCE_DIR}/cmake/dependencies.cmake.in
        ${CMAKE_CURRENT_BINARY_DIR}/dependencies.cmake.tgt
        @ONLY
        )

    #Second: (GENERATION_TIME) dependencies.cmake.tgt -> dependencies.cmake: the generator expression for the target location can now finally be expanded
    FILE(GENERATE
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/dependencies.cmake
        INPUT ${CMAKE_CURRENT_BINARY_DIR}/dependencies.cmake.tgt
        )


    INSTALL (TARGETS ${TARGET}
        RUNTIME DESTINATION ${TARGET_INSTALL_DIR} COMPONENT RUNTIME
        )

    INSTALL(SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/dependencies.cmake COMPONENT RUNTIME)



    #If the patchelf program is available, use it to patch the installed target's ELF interpreter section to point it to the loader used on the build platform
    IF (ELF_PATCHER)
        CONFIGURE_FILE (
            ${CMAKE_SOURCE_DIR}/cmake/patchelf.cmake.in
            ${CMAKE_CURRENT_BINARY_DIR}/patchelf.cmake.tgt
            @ONLY
            )
        #Second: (GENERATION_TIME) dependencies.cmake.tgt -> dependencies.cmake: the generator expression for the target location can now finally be expanded
        FILE(GENERATE
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/patchelf.cmake
            INPUT ${CMAKE_CURRENT_BINARY_DIR}/patchelf.cmake.tgt
            )

        INSTALL(SCRIPT ${CMAKE_CURRENT_BINARY_DIR}/patchelf.cmake COMPONENT RUNTIME)
    ENDIF()

ENDFUNCTION(INSTALL_TARGET_AND_ITS_DEPENDENCIES)



SET (CODE_REVISION_TEMPLATE_FILE ${CMAKE_SOURCE_DIR}/compiletime_config/code_revision.cpp.in)
SET (CODE_REVISION_SOURCE_FILE ${GENERATED_CODE_FOLDER}/code_revision.cpp)
CONFIGURE_FILE (${CMAKE_SOURCE_DIR}/cmake/code_revision.cmake.in ${CMAKE_BINARY_DIR}/code_revision.cmake @ONLY)


############# TARGET-EXPORTING ################
###### BEING GOOD CITIZENS: Make us easily reusable by other cmake-based projects
SET(EXPORT_TARGETS_NAME "${PROJECT_NAME}Targets")
SET(VERSION_CONFIG "${GENERATED_CODE_FOLDER}/${PROJECT_NAME}ConfigVersion.cmake")
SET(PROJECT_CONFIG "${GENERATED_CODE_FOLDER}/${PROJECT_NAME}Config.cmake")
SET(CONFIG_INSTALL_DIR "lib/cmake/${PROJECT_NAME}")
SET(NAMESPACE "${PROJECT_NAME}::")

INCLUDE (CMakePackageConfigHelpers)
#WRITE_BASIC_PACKAGE_VERSION_FILE ("${VERSION_CONFIG}" VERSION ${GIT_VERSION} COMPATIBILITY AnyNewerVersion)
WRITE_BASIC_PACKAGE_VERSION_FILE ("${VERSION_CONFIG}" COMPATIBILITY AnyNewerVersion)

#Generate and install a ${PROJECT_NAME}Config.cmake to enable client projects to use DPDKHub through FIND_PACKAGE
CONFIGURE_FILE ("${PROJECT_SOURCE_DIR}/cmake/ProjectConfig.cmake.in" "${PROJECT_CONFIG}" @ONLY)

#INSTALL (EXPORT "${EXPORT_TARGETS_NAME}" DESTINATION "${CONFIG_INSTALL_DIR}" NAMESPACE "${NAMESPACE}")
#EXPORT (EXPORT "${EXPORT_TARGETS_NAME}" NAMESPACE "${NAMESPACE}" FILE "${EXPORT_TARGETS_NAME}-build.cmake")
#
#INSTALL (FILES "${PROJECT_CONFIG}" "${VERSION_CONFIG}" DESTINATION "${CONFIG_INSTALL_DIR}")
###############################################

SET (FACESDK_ROOT "$ENV{HOME}/FaceDetection/Luxand/SDK" CACHE STRING "FaceSDK root directory")
ADD_SUBDIRECTORY (3rdParty)
ADD_SUBDIRECTORY (compiletime_config)
ADD_SUBDIRECTORY (src/tracker)




#For debug:
#ECHO_ALL_CMAKE_VARIABLE_VALUES()

MESSAGE ("\n")
SET(CPACK_PACKAGE_VENDOR "AB")
#SET(CPACK_GENERATOR "STGZ;TGZ")
SET(CPACK_GENERATOR "STGZ")
SET(CPACK_PACKAGE_VERSION_MAJOR "${PROJECT_VERSION_MAJOR}")
SET(CPACK_PACKAGE_VERSION_MINOR "${PROJECT_VERSION_MINOR}")
SET(CPACK_PACKAGE_VERSION_PATCH "${PROJECT_VERSION_PATCH}")

INCLUDE (CPack)
